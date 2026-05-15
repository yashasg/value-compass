"""Add ``portfolios.last_seen_at`` for the retention-purge job.

Revision ID: 0003_add_portfolio_last_seen_at
Revises: 0002_add_band_metrics
Create Date: 2026-05-15 09:05:00.000000

Additive only, per ``backend/db/models.py`` schema rules. The column is
nullable so existing rows do not need a default and so the purge job can
fall back to ``created_at`` for portfolios that never receive an
authenticated request after the migration ships. The retention schedule
is documented in ``docs/legal/data-retention.md``.
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0003_add_portfolio_last_seen_at"
down_revision: str | None = "0002_add_band_metrics"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add the nullable activity timestamp + index for the purge sweep."""
    op.add_column(
        "portfolios",
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
    )
    # Indexed because the daily purge job scans on this column; the
    # cardinality is one row per device so a B-tree index gives the
    # range-scan O(log n) lookup that keeps the sweep cheap as the
    # population grows.
    op.create_index(
        "ix_portfolios_last_seen_at",
        "portfolios",
        ["last_seen_at"],
    )


def downgrade() -> None:
    """Drop the index and column (local development only)."""
    op.drop_index("ix_portfolios_last_seen_at", table_name="portfolios")
    op.drop_column("portfolios", "last_seen_at")
