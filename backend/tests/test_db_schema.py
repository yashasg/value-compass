"""DB schema invariant tests for the optional sync backend."""

from __future__ import annotations

import asyncio
import os
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from pathlib import Path

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from sqlalchemy import create_engine, event, inspect, select, text  # noqa: E402
from sqlalchemy.exc import IntegrityError  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402

from common import db as common_db  # noqa: E402
from db.models import Holding, Portfolio, StockCache  # noqa: E402
from poller import polygon  # noqa: E402
from poller.polygon import BandMetrics  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture()
def migrated_session_factory(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    db_path = tmp_path / "schema.db"
    database_url = f"sqlite:///{db_path}"
    monkeypatch.setenv("DATABASE_URL", database_url)
    cfg = Config(str(REPO_ROOT / "alembic.ini"))
    cfg.set_main_option("sqlalchemy.url", database_url)

    command.upgrade(cfg, "head")

    engine = create_engine(database_url, future=True)

    @event.listens_for(engine, "connect")
    def _enable_foreign_keys(dbapi_connection, _connection_record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    SessionLocal = sessionmaker(
        bind=engine, autoflush=False, autocommit=False, future=True
    )
    try:
        yield SessionLocal
    finally:
        engine.dispose()


def _portfolio(ma_window: int = 50) -> Portfolio:
    return Portfolio(
        id=uuid.uuid4(),
        device_uuid=uuid.uuid4(),
        name="Main",
        monthly_budget=Decimal("1000"),
        ma_window=ma_window,
        created_at=datetime.now(UTC),
    )


def _stock_cache(ticker: str = "AAPL", job_status: str = "success") -> StockCache:
    return StockCache(
        ticker=ticker,
        current_price=Decimal("100"),
        sma_50=Decimal("99"),
        sma_200=Decimal("98"),
        midline=Decimal("99"),
        atr=Decimal("2"),
        upper_band=Decimal("103"),
        lower_band=Decimal("95"),
        band_position=Decimal("0.625"),
        last_modified=datetime.now(UTC),
        next_modified=datetime.now(UTC) + timedelta(hours=24),
        job_status=job_status,
    )


def test_fresh_database_migration_reaches_head(migrated_session_factory) -> None:
    with migrated_session_factory() as session:
        version = session.execute(
            text("SELECT version_num FROM alembic_version")
        ).scalar_one()

    assert version == "0003_add_portfolio_last_seen_at"


def test_model_metadata_matches_migration_created_tables_and_columns(
    migrated_session_factory,
) -> None:
    inspector = inspect(migrated_session_factory.kw["bind"])
    expected_tables = {
        "portfolios": Portfolio.__table__,
        "holdings": Holding.__table__,
        "stock_cache": StockCache.__table__,
    }

    assert set(expected_tables).issubset(inspector.get_table_names())

    for table_name, model_table in expected_tables.items():
        reflected = {
            column["name"]: column for column in inspector.get_columns(table_name)
        }
        model_columns = model_table.columns

        assert set(reflected) == {column.name for column in model_columns}
        for column in model_columns:
            reflected_column = reflected[column.name]
            assert reflected_column["nullable"] == column.nullable
            assert reflected_column["primary_key"] == column.primary_key

    assert {
        constraint["name"]
        for constraint in inspector.get_check_constraints("portfolios")
    } == {"ck_portfolios_ma_window"}
    assert {
        constraint["name"]
        for constraint in inspector.get_check_constraints("stock_cache")
    } == {"ck_stock_cache_job_status"}
    # Index added by 0003_add_portfolio_last_seen_at so the daily purge
    # sweep's range scan stays cheap as the population grows.
    assert "ix_portfolios_last_seen_at" in {
        index["name"] for index in inspector.get_indexes("portfolios")
    }


def test_portfolios_ma_window_check_constraint(migrated_session_factory) -> None:
    with migrated_session_factory() as session:
        session.add_all([_portfolio(50), _portfolio(200)])
        session.commit()

        session.add(_portfolio(100))
        with pytest.raises(IntegrityError):
            session.commit()


def test_stock_cache_job_status_check_constraint(migrated_session_factory) -> None:
    with migrated_session_factory() as session:
        session.add_all(
            [_stock_cache("AAPL", "success"), _stock_cache("MSFT", "failed")]
        )
        session.commit()

        session.add(_stock_cache("TSLA", "pending"))
        with pytest.raises(IntegrityError):
            session.commit()


def test_deleting_portfolio_cascades_to_holdings(migrated_session_factory) -> None:
    with migrated_session_factory() as session:
        portfolio = _portfolio()
        holding = Holding(id=uuid.uuid4(), ticker="AAPL", weight=Decimal("1"))
        portfolio.holdings.append(holding)
        session.add(portfolio)
        session.commit()

        session.delete(portfolio)
        session.commit()

        assert session.get(Holding, holding.id) is None


def test_stock_cache_is_one_row_per_ticker_and_updates_existing_row(
    migrated_session_factory, monkeypatch: pytest.MonkeyPatch
) -> None:
    SessionLocal = migrated_session_factory
    monkeypatch.setattr(common_db, "_engine", SessionLocal.kw["bind"])
    monkeypatch.setattr(common_db, "_SessionLocal", SessionLocal)

    async def _fake_fetch_band_metrics(ticker, _client):
        assert ticker == "AAPL"
        return BandMetrics(
            current_price=Decimal("125"),
            midline=Decimal("120"),
            atr=Decimal("3"),
            upper_band=Decimal("126"),
            lower_band=Decimal("114"),
            band_position=Decimal("0.9166666667"),
        )

    monkeypatch.setattr(polygon, "fetch_band_metrics", _fake_fetch_band_metrics)

    with SessionLocal() as session:
        session.add(_stock_cache("AAPL", "failed"))
        session.commit()

    asyncio.run(polygon.fetch_and_cache_ticker("AAPL"))

    with SessionLocal() as session:
        rows = session.scalars(
            select(StockCache).where(StockCache.ticker == "AAPL")
        ).all()

    assert len(rows) == 1
    assert rows[0].current_price == Decimal("125")
    assert rows[0].sma_50 == Decimal("120")
    assert rows[0].sma_200 == Decimal("120")
    assert rows[0].job_status == "success"
