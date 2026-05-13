"""Initial schema: portfolios, holdings, stock_cache.

Revision ID: 0001_initial
Revises:
Create Date: 2026-05-12 21:09:43.826000

"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "portfolios",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("device_uuid", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("monthly_budget", sa.Numeric(), nullable=False),
        sa.Column("ma_window", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint("ma_window IN (50, 200)", name="ck_portfolios_ma_window"),
    )

    op.create_table(
        "holdings",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("portfolio_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("ticker", sa.Text(), nullable=False),
        sa.Column("weight", sa.Numeric(), nullable=False),
        sa.ForeignKeyConstraint(
            ["portfolio_id"], ["portfolios.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "stock_cache",
        sa.Column("ticker", sa.Text(), nullable=False),
        sa.Column("current_price", sa.Numeric(), nullable=False),
        sa.Column("sma_50", sa.Numeric(), nullable=False),
        sa.Column("sma_200", sa.Numeric(), nullable=False),
        sa.Column("last_modified", sa.DateTime(timezone=True), nullable=False),
        sa.Column("next_modified", sa.DateTime(timezone=True), nullable=True),
        sa.Column("job_status", sa.Text(), nullable=False),
        sa.PrimaryKeyConstraint("ticker"),
        sa.CheckConstraint(
            "job_status IN ('success', 'failed')",
            name="ck_stock_cache_job_status",
        ),
    )


def downgrade() -> None:
    # Schema changes are additive only — this downgrade exists for local
    # development convenience but is never used in deploy.
    op.drop_table("stock_cache")
    op.drop_table("holdings")
    op.drop_table("portfolios")
