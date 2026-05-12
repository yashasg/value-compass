"""Tests for the vca-poller scheduler + nightly job.

The job is exercised end-to-end against an in-memory SQLite database;
Polygon and APNs are stubbed via ``monkeypatch``.
"""

from __future__ import annotations

import os
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402

from common import db as common_db  # noqa: E402
from db.models import Base, Holding, Portfolio, StockCache  # noqa: E402
from poller import job as job_module  # noqa: E402
from poller.__main__ import build_scheduler  # noqa: E402


@pytest.fixture()
def in_memory_db(monkeypatch: pytest.MonkeyPatch):
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

    # Patch common.db so both the job and any callee see the same session.
    monkeypatch.setattr(common_db, "_engine", engine)
    monkeypatch.setattr(common_db, "_SessionLocal", SessionLocal)
    return SessionLocal


def _seed(SessionLocal) -> uuid.UUID:
    """Seed one portfolio holding AAPL; return the device UUID."""
    device_uuid = uuid.uuid4()
    with SessionLocal() as s:
        portfolio = Portfolio(
            id=uuid.uuid4(),
            device_uuid=device_uuid,
            name="Main",
            monthly_budget=Decimal("1000"),
            ma_window=50,
            created_at=datetime.now(timezone.utc),
        )
        portfolio.holdings.append(
            Holding(id=uuid.uuid4(), ticker="AAPL", weight=Decimal("1"))
        )
        s.add(portfolio)
        s.commit()
    return device_uuid


def test_skipped_on_non_trading_day(in_memory_db, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(job_module, "is_trading_day", lambda _today: False)
    assert job_module.run_nightly_job(today=date(2026, 1, 1)) == "skipped"


def test_success_path_writes_cache_and_pushes(
    in_memory_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    SessionLocal = in_memory_db
    device_uuid = _seed(SessionLocal)

    monkeypatch.setattr(job_module, "is_trading_day", lambda _today: True)

    async def _fake_fetch_all(tickers):
        return (
            {t: Decimal("100") for t in tickers},
            {t: Decimal("99") for t in tickers},
            {t: Decimal("98") for t in tickers},
        )

    monkeypatch.setattr(job_module, "_fetch_all", _fake_fetch_all)

    pushed: list[uuid.UUID] = []

    async def _fake_push(devices):
        pushed.extend(devices)

    monkeypatch.setattr(job_module.apns, "push_to_devices", _fake_push)

    assert job_module.run_nightly_job(today=date(2026, 1, 5)) == "success"

    with SessionLocal() as s:
        row = s.get(StockCache, "AAPL")
        assert row is not None
        assert row.current_price == Decimal("100")
        assert row.sma_50 == Decimal("99")
        assert row.sma_200 == Decimal("98")
        assert row.job_status == "success"
        assert row.last_modified is not None
        assert row.next_modified is not None
    assert device_uuid in pushed


def test_failure_path_does_not_update_modified(
    in_memory_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    SessionLocal = in_memory_db
    _seed(SessionLocal)

    # Pre-populate stock_cache with a known last_modified so we can
    # assert it is NOT updated on failure.
    sentinel = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)
    with SessionLocal() as s:
        s.add(
            StockCache(
                ticker="AAPL",
                current_price=Decimal("50"),
                sma_50=Decimal("49"),
                sma_200=Decimal("48"),
                last_modified=sentinel,
                next_modified=sentinel,
                job_status="success",
            )
        )
        s.commit()

    monkeypatch.setattr(job_module, "is_trading_day", lambda _today: True)

    async def _boom(tickers):
        raise job_module.polygon.PolygonError("simulated outage")

    monkeypatch.setattr(job_module, "_fetch_all", _boom)

    assert job_module.run_nightly_job(today=date(2026, 1, 5)) == "failed"

    with SessionLocal() as s:
        row = s.get(StockCache, "AAPL")
        assert row.job_status == "failed"
        # Critical spec invariant: last_modified / next_modified frozen.
        # SQLite strips tz; compare as naive UTC.
        assert row.last_modified.replace(tzinfo=timezone.utc) == sentinel
        assert row.next_modified.replace(tzinfo=timezone.utc) == sentinel


def test_scheduler_has_5pm_et_trigger() -> None:
    scheduler = build_scheduler()
    jobs = scheduler.get_jobs()
    assert len(jobs) == 1
    trigger = jobs[0].trigger
    fields = {f.name: str(f) for f in trigger.fields}
    assert fields["hour"] == "17"
    assert fields["minute"] == "0"
    assert fields["day_of_week"] == "mon-fri"
    assert str(trigger.timezone) == "America/New_York"
