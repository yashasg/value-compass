"""Cross-service contract tests for API, poller, and iOS contract artifacts."""

from __future__ import annotations

import os
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from api.export_openapi import (  # noqa: E402
    CONTRACT_PATHS,
    REPO_ROOT,
    render_openapi_contract,
)
from api.main import app, get_db  # noqa: E402
from common import db as common_db  # noqa: E402
from db.models import Base, Holding, Portfolio, StockCache  # noqa: E402
from poller import job as job_module  # noqa: E402
from poller.polygon import BandMetrics  # noqa: E402

ATTEST = {"X-App-Attest": "test-token"}


@pytest.fixture()
def service_stack(monkeypatch: pytest.MonkeyPatch):
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
    monkeypatch.setattr(common_db, "_engine", engine)
    monkeypatch.setattr(common_db, "_SessionLocal", SessionLocal)

    def _override():
        with SessionLocal() as session:
            yield session

    app.dependency_overrides[get_db] = _override
    try:
        with TestClient(app) as client:
            yield SessionLocal, client
    finally:
        app.dependency_overrides.clear()
        engine.dispose()


def _seed_portfolio(SessionLocal, ticker: str = "AAPL") -> uuid.UUID:
    device_uuid = uuid.uuid4()
    with SessionLocal() as session:
        portfolio = Portfolio(
            id=uuid.uuid4(),
            device_uuid=device_uuid,
            name="Main",
            monthly_budget=Decimal("1000"),
            ma_window=50,
            created_at=datetime.now(UTC),
        )
        portfolio.holdings.append(
            Holding(id=uuid.uuid4(), ticker=ticker, weight=Decimal("1"))
        )
        session.add(portfolio)
        session.commit()
    return device_uuid


def test_openapi_contract_artifacts_feed_swift_generator() -> None:
    contract = render_openapi_contract()
    assert {path.relative_to(REPO_ROOT).as_posix() for path in CONTRACT_PATHS} == {
        "openapi.json",
        "frontend/Sources/Networking/openapi.json",
    }
    for path in CONTRACT_PATHS:
        assert path.read_text(encoding="utf-8") == contract

    generator_config = (
        CONTRACT_PATHS[1].with_name("openapi-generator-config.yaml").read_text()
    )
    assert "SwiftOpenAPIGenerator" in generator_config
    assert "  - types" in generator_config
    assert "  - client" in generator_config


def test_poller_written_stock_cache_is_served_by_api(
    service_stack, monkeypatch: pytest.MonkeyPatch
) -> None:
    SessionLocal, client = service_stack
    device_uuid = _seed_portfolio(SessionLocal)
    monkeypatch.setattr(job_module, "is_trading_day", lambda _today: True)

    async def _fake_fetch_all(tickers):
        assert tickers == ["AAPL"]
        return {
            "AAPL": BandMetrics(
                current_price=Decimal("125"),
                midline=Decimal("120"),
                atr=Decimal("3"),
                upper_band=Decimal("126"),
                lower_band=Decimal("114"),
                band_position=Decimal("0.9166666667"),
            )
        }

    pushed_devices: list[uuid.UUID] = []

    async def _fake_push(devices):
        pushed_devices.extend(devices)

    monkeypatch.setattr(job_module, "_fetch_all", _fake_fetch_all)
    monkeypatch.setattr(job_module.apns, "push_to_devices", _fake_push)

    assert job_module.run_nightly_job(today=datetime(2026, 1, 5).date()) == "success"

    status = client.get("/portfolio/status", headers=ATTEST)
    assert status.status_code == 200
    assert status.json()["last_modified"] is not None
    assert status.json()["next_modified"] is not None

    data = client.get(
        "/portfolio/data",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert data.status_code == 200
    holding = data.json()["holdings"][0]
    assert holding == {
        "ticker": "AAPL",
        "weight": 1.0,
        "current_price": 125.0,
        "sma_50": 120.0,
        "sma_200": 120.0,
        "midline": 120.0,
        "atr": 3.0,
        "upper_band": 126.0,
        "lower_band": 114.0,
        "band_position": 0.9166666667,
    }
    assert pushed_devices == [device_uuid]


def test_failed_poller_keeps_last_successful_snapshot_visible_to_api(
    service_stack, monkeypatch: pytest.MonkeyPatch
) -> None:
    SessionLocal, client = service_stack
    device_uuid = _seed_portfolio(SessionLocal)
    last_success = datetime(2026, 1, 1, 12, 0, tzinfo=UTC)
    next_success = last_success + timedelta(hours=24)
    with SessionLocal() as session:
        session.add(
            StockCache(
                ticker="AAPL",
                current_price=Decimal("50"),
                sma_50=Decimal("49"),
                sma_200=Decimal("48"),
                midline=Decimal("49"),
                atr=Decimal("2"),
                upper_band=Decimal("53"),
                lower_band=Decimal("45"),
                band_position=Decimal("0.625"),
                last_modified=last_success,
                next_modified=next_success,
                job_status="success",
            )
        )
        session.commit()

    monkeypatch.setattr(job_module, "is_trading_day", lambda _today: True)

    async def _boom(_tickers):
        raise job_module.polygon.PolygonError("simulated outage")

    monkeypatch.setattr(job_module, "_fetch_all", _boom)

    assert job_module.run_nightly_job(today=datetime(2026, 1, 5).date()) == "failed"

    with SessionLocal() as session:
        row = session.get(StockCache, "AAPL")
        assert row is not None
        assert row.job_status == "failed"
        assert row.last_modified.replace(tzinfo=UTC) == last_success
        assert row.next_modified.replace(tzinfo=UTC) == next_success

    data = client.get(
        "/portfolio/data",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert data.status_code == 200
    holding = data.json()["holdings"][0]
    assert holding["current_price"] == 50.0
    assert holding["midline"] == 49.0
    assert holding["band_position"] == 0.625
