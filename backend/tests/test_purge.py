"""Tests for the retention-purge sweep.

The sweep is exercised end-to-end against an in-memory SQLite database;
no Polygon or APNs deps are involved because the purge module only
touches ``portfolios`` and the cascade-driven ``holdings``.
"""

from __future__ import annotations

import os
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from sqlalchemy import create_engine, event, select  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402

from common import db as common_db  # noqa: E402
from db.models import Base, Holding, Portfolio  # noqa: E402
from poller import purge as purge_module  # noqa: E402


@pytest.fixture()
def in_memory_db(monkeypatch: pytest.MonkeyPatch):
    engine = create_engine(
        "sqlite:///:memory:",
        future=True,
        connect_args={"check_same_thread": False},
    )

    @event.listens_for(engine, "connect")
    def _enable_foreign_keys(dbapi_connection, _connection_record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(
        bind=engine, autoflush=False, autocommit=False, future=True
    )

    monkeypatch.setattr(common_db, "_engine", engine)
    monkeypatch.setattr(common_db, "_SessionLocal", SessionLocal)
    try:
        yield SessionLocal
    finally:
        engine.dispose()


def _portfolio(
    *,
    last_seen_at: datetime | None,
    created_at: datetime,
    name: str = "Main",
) -> Portfolio:
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=uuid.uuid4(),
        name=name,
        monthly_budget=Decimal("1000"),
        ma_window=50,
        created_at=created_at,
        last_seen_at=last_seen_at,
    )
    portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="AAPL", weight=Decimal("1"))
    )
    return portfolio


def test_purge_deletes_portfolio_inactive_beyond_retention_window(
    in_memory_db,
) -> None:
    SessionLocal = in_memory_db
    now = datetime(2026, 5, 15, tzinfo=UTC)
    cutoff_breached = now - timedelta(days=541)

    with SessionLocal() as s:
        s.add(_portfolio(last_seen_at=cutoff_breached, created_at=cutoff_breached))
        s.commit()

    deleted = purge_module.purge_inactive_portfolios(now=now, retention_days=540)

    assert deleted == 1
    with SessionLocal() as s:
        assert s.scalars(select(Portfolio)).all() == []
        # Holdings cascade-deleted alongside the portfolio.
        assert s.scalars(select(Holding)).all() == []


def test_purge_preserves_recently_active_portfolio(in_memory_db) -> None:
    SessionLocal = in_memory_db
    now = datetime(2026, 5, 15, tzinfo=UTC)
    fresh = now - timedelta(days=10)

    with SessionLocal() as s:
        s.add(_portfolio(last_seen_at=fresh, created_at=fresh, name="Fresh"))
        s.commit()

    deleted = purge_module.purge_inactive_portfolios(now=now, retention_days=540)

    assert deleted == 0
    with SessionLocal() as s:
        rows = s.scalars(select(Portfolio)).all()
        assert len(rows) == 1
        assert rows[0].name == "Fresh"


def test_purge_uses_created_at_when_last_seen_at_is_null(in_memory_db) -> None:
    """Legacy rows missing an activity stamp fall back to created_at."""
    SessionLocal = in_memory_db
    now = datetime(2026, 5, 15, tzinfo=UTC)
    long_dormant_created = now - timedelta(days=600)

    with SessionLocal() as s:
        s.add(
            _portfolio(
                last_seen_at=None,
                created_at=long_dormant_created,
                name="Legacy",
            )
        )
        s.commit()

    deleted = purge_module.purge_inactive_portfolios(now=now, retention_days=540)

    assert deleted == 1
    with SessionLocal() as s:
        assert s.scalars(select(Portfolio)).all() == []


def test_purge_does_not_delete_null_last_seen_at_when_created_at_recent(
    in_memory_db,
) -> None:
    """A new portfolio that hasn't yet stamped is kept until created_at expires."""
    SessionLocal = in_memory_db
    now = datetime(2026, 5, 15, tzinfo=UTC)
    recent_created = now - timedelta(days=5)

    with SessionLocal() as s:
        s.add(_portfolio(last_seen_at=None, created_at=recent_created, name="New"))
        s.commit()

    deleted = purge_module.purge_inactive_portfolios(now=now, retention_days=540)

    assert deleted == 0
    with SessionLocal() as s:
        assert len(s.scalars(select(Portfolio)).all()) == 1


def test_purge_respects_custom_retention_days(in_memory_db) -> None:
    SessionLocal = in_memory_db
    now = datetime(2026, 5, 15, tzinfo=UTC)
    six_months_ago = now - timedelta(days=185)

    with SessionLocal() as s:
        s.add(
            _portfolio(last_seen_at=six_months_ago, created_at=six_months_ago)
        )
        s.commit()

    # 540-day window keeps the row.
    assert (
        purge_module.purge_inactive_portfolios(now=now, retention_days=540) == 0
    )
    # A tighter 90-day window purges it.
    assert (
        purge_module.purge_inactive_portfolios(now=now, retention_days=90) == 1
    )
    with SessionLocal() as s:
        assert s.scalars(select(Portfolio)).all() == []


def test_count_inactive_matches_purge_selection(in_memory_db) -> None:
    SessionLocal = in_memory_db
    now = datetime(2026, 5, 15, tzinfo=UTC)
    cutoff_breached = now - timedelta(days=600)
    fresh = now - timedelta(days=1)

    with SessionLocal() as s:
        s.add(_portfolio(last_seen_at=cutoff_breached, created_at=cutoff_breached))
        s.add(_portfolio(last_seen_at=fresh, created_at=fresh))
        s.add(_portfolio(last_seen_at=None, created_at=cutoff_breached))
        s.commit()

    count = purge_module.count_inactive_portfolios(now=now, retention_days=540)
    assert count == 2
    deleted = purge_module.purge_inactive_portfolios(now=now, retention_days=540)
    assert deleted == count


def test_purge_is_idempotent(in_memory_db) -> None:
    SessionLocal = in_memory_db
    now = datetime(2026, 5, 15, tzinfo=UTC)
    cutoff_breached = now - timedelta(days=600)

    with SessionLocal() as s:
        s.add(_portfolio(last_seen_at=cutoff_breached, created_at=cutoff_breached))
        s.commit()

    assert purge_module.purge_inactive_portfolios(now=now, retention_days=540) == 1
    # A second invocation immediately after must be a no-op rather than
    # raising or double-deleting.
    assert purge_module.purge_inactive_portfolios(now=now, retention_days=540) == 0
