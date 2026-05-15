"""SQLAlchemy models for value-compass.

Schema is defined in the issue and shared between ``backend/api`` and
``backend/poller``. Schema changes are additive only — columns are added,
never removed or renamed.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""


class Portfolio(Base):
    """User-owned investment portfolio keyed by a device UUID."""

    __tablename__ = "portfolios"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    # Device identifier — there are no user accounts; the device UUID stored
    # in the iOS Keychain is the owner identifier.
    device_uuid: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    monthly_budget: Mapped[Decimal] = mapped_column(Numeric, nullable=False)
    ma_window: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    # Activity timestamp used by the retention-purge job. Stamped on every
    # authenticated request that resolves a Portfolio by device_uuid (see
    # ``backend/api/main.py`` and the schedule documented in
    # ``docs/legal/data-retention.md``). Nullable so legacy rows can be
    # backfilled or treated by ``created_at`` until the first request hits.
    last_seen_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    holdings: Mapped[list[Holding]] = relationship(
        back_populates="portfolio", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint("ma_window IN (50, 200)", name="ck_portfolios_ma_window"),
    )


class Holding(Base):
    """Ticker allocation within a portfolio."""

    __tablename__ = "holdings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
    )
    ticker: Mapped[str] = mapped_column(Text, nullable=False)
    # Fractional weight, e.g. 0.30 == 30%.
    weight: Mapped[Decimal] = mapped_column(Numeric, nullable=False)

    portfolio: Mapped[Portfolio] = relationship(back_populates="holdings")


class StockCache(Base):
    """Cached market data for a ticker."""

    __tablename__ = "stock_cache"

    ticker: Mapped[str] = mapped_column(Text, primary_key=True)
    current_price: Mapped[Decimal] = mapped_column(Numeric, nullable=False)
    sma_50: Mapped[Decimal] = mapped_column(Numeric, nullable=False)
    sma_200: Mapped[Decimal] = mapped_column(Numeric, nullable=False)
    midline: Mapped[Decimal | None] = mapped_column(Numeric, nullable=True)
    atr: Mapped[Decimal | None] = mapped_column(Numeric, nullable=True)
    upper_band: Mapped[Decimal | None] = mapped_column(Numeric, nullable=True)
    lower_band: Mapped[Decimal | None] = mapped_column(Numeric, nullable=True)
    band_position: Mapped[Decimal | None] = mapped_column(Numeric, nullable=True)
    # UTC timestamps of the last successful refresh and the next scheduled
    # refresh. ``next_modified`` is only written when ``job_status = 'success'``.
    last_modified: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    next_modified: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    job_status: Mapped[str] = mapped_column(Text, nullable=False)

    __table_args__ = (
        CheckConstraint(
            "job_status IN ('success', 'failed')",
            name="ck_stock_cache_job_status",
        ),
    )
