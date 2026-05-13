"""Add OHLC-derived band metrics to stock_cache.

Revision ID: 0002_add_band_metrics
Revises: 0001_initial
Create Date: 2026-05-13 04:10:00.000000

"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0002_add_band_metrics"
down_revision: str | None = "0001_initial"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("stock_cache", sa.Column("midline", sa.Numeric(), nullable=True))
    op.add_column("stock_cache", sa.Column("atr", sa.Numeric(), nullable=True))
    op.add_column("stock_cache", sa.Column("upper_band", sa.Numeric(), nullable=True))
    op.add_column("stock_cache", sa.Column("lower_band", sa.Numeric(), nullable=True))
    op.add_column(
        "stock_cache", sa.Column("band_position", sa.Numeric(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("stock_cache", "band_position")
    op.drop_column("stock_cache", "lower_band")
    op.drop_column("stock_cache", "upper_band")
    op.drop_column("stock_cache", "atr")
    op.drop_column("stock_cache", "midline")
