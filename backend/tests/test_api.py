"""Tests for the FastAPI vca-api app.

Uses an in-memory SQLite database via SQLAlchemy and a
``dependency_overrides`` swap so the tests never touch Postgres.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest

# Force a usable DATABASE_URL before importing the app, so the lazy
# ``common.db.get_engine`` does not blow up at import time.
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402

from api.main import app, get_db  # noqa: E402
from db.models import Base, Holding, Portfolio, StockCache  # noqa: E402


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        future=True,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def client(db_session: Session):
    def _override():
        yield db_session

    app.dependency_overrides[get_db] = _override
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


ATTEST = {"X-App-Attest": "test-token"}


def test_health_ok(client: TestClient) -> None:
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}
    # Spec-mandated headers on every response:
    assert resp.headers["Cache-Control"] == "max-age=3600"
    assert "Last-Modified" in resp.headers
    assert "X-Min-App-Version" in resp.headers


def test_schema_version_requires_attest(client: TestClient) -> None:
    assert client.get("/schema/version").status_code == 401
    resp = client.get("/schema/version", headers=ATTEST)
    assert resp.status_code == 200
    assert resp.json()["version"] >= 1


def test_portfolio_status_empty(client: TestClient) -> None:
    resp = client.get("/portfolio/status", headers=ATTEST)
    assert resp.status_code == 200
    assert resp.json() == {"last_modified": None, "next_modified": None}


def test_portfolio_status_returns_latest(client: TestClient, db_session: Session) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    db_session.add(
        StockCache(
            ticker="AAPL",
            current_price=Decimal("100"),
            sma_50=Decimal("99"),
            sma_200=Decimal("98"),
            last_modified=now,
            next_modified=now + timedelta(hours=24),
            job_status="success",
        )
    )
    db_session.commit()
    resp = client.get("/portfolio/status", headers=ATTEST)
    assert resp.status_code == 200
    body = resp.json()
    assert body["last_modified"] is not None
    assert body["next_modified"] is not None


def test_portfolio_data_404_for_unknown_device(client: TestClient) -> None:
    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(uuid.uuid4())},
        headers=ATTEST,
    )
    assert resp.status_code == 404


def test_portfolio_data_returns_holdings(client: TestClient, db_session: Session) -> None:
    device_uuid = uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="Main",
        monthly_budget=Decimal("1000"),
        ma_window=50,
        created_at=datetime.now(timezone.utc),
    )
    portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="AAPL", weight=Decimal("0.5"))
    )
    db_session.add(portfolio)
    db_session.add(
        StockCache(
            ticker="AAPL",
            current_price=Decimal("150"),
            sma_50=Decimal("149"),
            sma_200=Decimal("148"),
            last_modified=datetime.now(timezone.utc),
            next_modified=None,
            job_status="success",
        )
    )
    db_session.commit()

    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "Main"
    assert body["ma_window"] == 50
    assert len(body["holdings"]) == 1
    h = body["holdings"][0]
    assert h["ticker"] == "AAPL"
    assert h["current_price"] == 150.0


def test_add_holding_returns_202_and_does_not_call_polygon_when_cached(
    client: TestClient, db_session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    device_uuid = uuid.uuid4()
    db_session.add(
        Portfolio(
            id=uuid.uuid4(),
            device_uuid=device_uuid,
            name="P",
            monthly_budget=Decimal("100"),
            ma_window=200,
            created_at=datetime.now(timezone.utc),
        )
    )
    db_session.add(
        StockCache(
            ticker="MSFT",
            current_price=Decimal("400"),
            sma_50=Decimal("399"),
            sma_200=Decimal("398"),
            last_modified=datetime.now(timezone.utc),
            next_modified=None,
            job_status="success",
        )
    )
    db_session.commit()

    called = {"polygon": 0}

    async def _fake_fetch(ticker):  # pragma: no cover
        called["polygon"] += 1

    monkeypatch.setattr("poller.polygon.fetch_and_cache_ticker", _fake_fetch)

    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(device_uuid), "ticker": "MSFT", "weight": 0.25},
        headers=ATTEST,
    )
    assert resp.status_code == 202
    # Cached ticker → background task must NOT have been queued.
    assert called["polygon"] == 0


def test_add_holding_404_for_unknown_device(client: TestClient) -> None:
    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(uuid.uuid4()), "ticker": "AAPL", "weight": 0.1},
        headers=ATTEST,
    )
    assert resp.status_code == 404
