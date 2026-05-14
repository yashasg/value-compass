"""Tests for the FastAPI vca-api app.

Uses an in-memory SQLite database via SQLAlchemy and a
``dependency_overrides`` swap so the tests never touch Postgres.
"""

from __future__ import annotations

import os
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

# Force a usable DATABASE_URL before importing the app, so the lazy
# ``common.db.get_engine`` does not blow up at import time.
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from api.export_openapi import CONTRACT_PATHS, render_openapi_contract  # noqa: E402
from api.main import app, get_db  # noqa: E402
from common import config  # noqa: E402
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
    SessionLocal = sessionmaker(
        bind=engine, autoflush=False, autocommit=False, future=True
    )
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
    unauthorized = client.get("/schema/version")
    assert unauthorized.status_code == 401
    assert unauthorized.json() == {
        "code": "appAttestMissing",
        "message": "Missing X-App-Attest header.",
        "retry_after_seconds": None,
    }

    resp = client.get("/schema/version", headers=ATTEST)
    assert resp.status_code == 200
    assert resp.json()["version"] >= 1
    assert resp.json()["min_app_version"] == config.MIN_APP_VERSION


def test_openapi_describes_error_envelope(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    components = schema["components"]["schemas"]
    error_schema = components["ErrorEnvelope"]

    assert error_schema["properties"]["code"]["$ref"].endswith("/ErrorCode")
    assert "syncUnavailable" in components["ErrorCode"]["enum"]
    assert (
        schema["paths"]["/portfolio/data"]["get"]["responses"]["404"]["content"][
            "application/json"
        ]["schema"]["$ref"]
        == "#/components/schemas/ErrorEnvelope"
    )
    assert (
        schema["paths"]["/portfolio/data"]["get"]["responses"]["422"]["content"][
            "application/json"
        ]["schema"]["$ref"]
        == "#/components/schemas/ErrorEnvelope"
    )
    schema_version = components["SchemaVersionResponse"]
    assert "min_app_version" in schema_version["properties"]
    assert "min_app_version" not in schema_version["required"]
    schema_version_200 = schema["paths"]["/schema/version"]["get"]["responses"]["200"]
    assert "X-Min-App-Version" in schema_version_200["headers"]


def test_checked_in_openapi_artifacts_match_fastapi() -> None:
    contract = render_openapi_contract()

    for path in CONTRACT_PATHS:
        assert path.read_text(encoding="utf-8") == contract


def test_validation_errors_use_error_envelope(client: TestClient) -> None:
    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": "not-a-uuid"},
        headers=ATTEST,
    )

    assert resp.status_code == 422
    assert resp.json() == {
        "code": "schemaUnsupported",
        "message": "Request validation failed.",
        "retry_after_seconds": None,
    }


def test_portfolio_status_empty(client: TestClient) -> None:
    resp = client.get("/portfolio/status", headers=ATTEST)
    assert resp.status_code == 200
    assert resp.json() == {"last_modified": None, "next_modified": None}


def test_portfolio_status_returns_latest(
    client: TestClient, db_session: Session
) -> None:
    now = datetime.now(UTC).replace(microsecond=0)
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


def test_market_data_returns_fresh_cache_hit(
    client: TestClient, db_session: Session
) -> None:
    last_modified = datetime.now(UTC).replace(microsecond=0)
    next_modified = last_modified + timedelta(hours=24)
    db_session.add(
        StockCache(
            ticker="AAPL",
            current_price=Decimal("150.25"),
            sma_50=Decimal("149.50"),
            sma_200=Decimal("140.75"),
            last_modified=last_modified,
            next_modified=next_modified,
            job_status="success",
        )
    )
    db_session.commit()

    resp = client.get("/market-data/aapl", headers=ATTEST)

    assert resp.status_code == 200
    assert resp.headers["Last-Modified"] == last_modified.strftime(
        "%a, %d %b %Y %H:%M:%S GMT"
    )
    assert resp.json() == {
        "ticker": "AAPL",
        "current_price": 150.25,
        "sma_50": 149.5,
        "sma_200": 140.75,
        "moving_averages": {"50": 149.5, "200": 140.75},
        "last_modified": last_modified.isoformat().replace("+00:00", "Z"),
        "next_modified": next_modified.isoformat().replace("+00:00", "Z"),
        "cache_status": "fresh",
        "is_stale": False,
        "stale_after_hours": config.STALE_ALERT_HOURS,
    }


def test_market_data_returns_structured_missing_error(
    client: TestClient,
) -> None:
    resp = client.get("/market-data/MSFT", headers=ATTEST)

    assert resp.status_code == 404
    assert resp.json() == {
        "code": "stockDataMissing",
        "message": "Market data is not cached for ticker.",
        "retry_after_seconds": None,
    }


def test_market_data_marks_stale_and_failed_rows(
    client: TestClient, db_session: Session
) -> None:
    stale_time = datetime.now(UTC) - timedelta(hours=config.STALE_ALERT_HOURS + 1)
    failed_time = datetime.now(UTC)
    db_session.add_all(
        [
            StockCache(
                ticker="STALE",
                current_price=Decimal("10"),
                sma_50=Decimal("9"),
                sma_200=Decimal("8"),
                last_modified=stale_time,
                next_modified=None,
                job_status="success",
            ),
            StockCache(
                ticker="FAILED",
                current_price=Decimal("20"),
                sma_50=Decimal("19"),
                sma_200=Decimal("18"),
                last_modified=failed_time,
                next_modified=None,
                job_status="failed",
            ),
        ]
    )
    db_session.commit()

    stale = client.get("/market-data/STALE", headers=ATTEST)
    failed = client.get("/market-data/FAILED", headers=ATTEST)

    assert stale.status_code == 200
    assert stale.json()["cache_status"] == "stale"
    assert stale.json()["is_stale"] is True
    assert failed.status_code == 200
    assert failed.json()["cache_status"] == "failed"
    assert failed.json()["is_stale"] is True


def test_portfolio_data_404_for_unknown_device(client: TestClient) -> None:
    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(uuid.uuid4())},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json() == {
        "code": "portfolioNotFound",
        "message": "Portfolio not found for device.",
        "retry_after_seconds": None,
    }


def test_portfolio_data_returns_holdings(
    client: TestClient, db_session: Session
) -> None:
    device_uuid = uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="Main",
        monthly_budget=Decimal("1000"),
        ma_window=50,
        created_at=datetime.now(UTC),
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
            midline=Decimal("149.5"),
            atr=Decimal("2.5"),
            upper_band=Decimal("155.075"),
            lower_band=Decimal("143.925"),
            band_position=Decimal("0.5448430493273542600896860987"),
            last_modified=datetime.now(UTC),
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
    assert h["midline"] == 149.5
    assert h["atr"] == 2.5
    assert h["upper_band"] == 155.075
    assert h["lower_band"] == 143.925
    assert h["band_position"] == 0.5448430493


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
            created_at=datetime.now(UTC),
        )
    )
    db_session.add(
        StockCache(
            ticker="MSFT",
            current_price=Decimal("400"),
            sma_50=Decimal("399"),
            sma_200=Decimal("398"),
            last_modified=datetime.now(UTC),
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


def test_add_holding_rejects_duplicate_ticker(
    client: TestClient, db_session: Session
) -> None:
    device_uuid = uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="P",
        monthly_budget=Decimal("100"),
        ma_window=200,
        created_at=datetime.now(UTC),
    )
    portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="MSFT", weight=Decimal("0.25"))
    )
    db_session.add(portfolio)
    db_session.commit()

    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(device_uuid), "ticker": "MSFT", "weight": 0.25},
        headers=ATTEST,
    )

    assert resp.status_code == 409
    assert resp.json() == {
        "code": "conflictDetected",
        "message": "Holding already exists for portfolio.",
        "retry_after_seconds": None,
    }


def test_add_holding_404_for_unknown_device(client: TestClient) -> None:
    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(uuid.uuid4()), "ticker": "AAPL", "weight": 0.1},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json()["code"] == "portfolioNotFound"
