"""Retention-purge sweep for device-linked portfolios.

The data-retention schedule documented in ``docs/legal/data-retention.md``
caps how long ``portfolios.device_uuid`` (and the cascaded ``holdings``
rows that hang off it) may live on the backend. This module implements
the **enforcement** side of that schedule: a daily sweep that deletes
portfolio rows whose ``last_seen_at`` (or, for legacy rows that never
received an authenticated request after the migration shipped,
``created_at``) is older than the configured inactivity window.

Distinct from user-triggered erasure (GDPR Art. 17, tracked in #329):

* This sweep enforces **storage limitation** (Art. 5(1)(e)) — it runs
  whether or not a data subject ever asks.
* The Art. 17 path will use a different entry point (a request that
  includes the ``X-Device-UUID``); the two paths share no transactional
  state and never race because both ultimately resolve to
  ``DELETE FROM portfolios WHERE id = ...`` under SQLAlchemy's cascade.

The sweep is run by APScheduler from :mod:`poller.__main__`; the
function below is intentionally importable in isolation so tests can
exercise it against an in-memory SQLite database without booting the
scheduler.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, or_, select

from common import config
from common import db as common_db
from db.models import Portfolio

log = logging.getLogger("vca.poller.purge")


def _cutoff(now: datetime, retention_days: int) -> datetime:
    """Return the inclusive boundary; rows strictly older than this are purged."""
    return now - timedelta(days=retention_days)


def purge_inactive_portfolios(
    now: datetime | None = None,
    retention_days: int | None = None,
) -> int:
    """Delete portfolios whose last activity predates the retention window.

    Returns the number of portfolio rows deleted. Cascaded ``holdings``
    rows are removed by the ``ON DELETE CASCADE`` foreign key declared in
    :mod:`db.models`, so this function does not touch them directly.

    Args:
      now: The reference timestamp (UTC) for the sweep. Defaults to
        ``datetime.now(UTC)``; parameterised so tests can pin a stable
        clock without monkeypatching ``datetime``.
      retention_days: The inactivity window in days. Defaults to
        :data:`common.config.PORTFOLIO_RETENTION_DAYS`.

    Returns:
      The number of portfolio rows deleted.
    """
    if now is None:
        now = datetime.now(UTC)
    if retention_days is None:
        retention_days = config.PORTFOLIO_RETENTION_DAYS

    cutoff = _cutoff(now, retention_days)
    deleted = 0

    with common_db.get_session() as session:
        # Two-step delete (SELECT id, then DELETE per id) so the ORM
        # cascade configured on ``Portfolio.holdings`` runs and the
        # holdings rows are removed alongside the portfolio. A bulk
        # ``session.execute(delete(Portfolio).where(...))`` would only
        # honour the database-level foreign-key cascade — which we also
        # have — but bypasses any future SQLAlchemy-level hooks, so we
        # use the orm path to keep both contracts coherent.
        stale = session.scalars(
            select(Portfolio).where(
                or_(
                    Portfolio.last_seen_at < cutoff,
                    # Legacy rows: never received an authenticated request
                    # after the migration shipped. Fall back to created_at
                    # so the schedule is enforced even for dormant rows
                    # that pre-date the activity-stamp wiring.
                    (Portfolio.last_seen_at.is_(None))
                    & (Portfolio.created_at < cutoff),
                )
            )
        ).all()
        for portfolio in stale:
            session.delete(portfolio)
            deleted += 1
        session.commit()

    log.info(
        "retention sweep complete: deleted=%d retention_days=%d cutoff=%s",
        deleted,
        retention_days,
        cutoff.isoformat(),
    )
    return deleted


def count_inactive_portfolios(
    now: datetime | None = None,
    retention_days: int | None = None,
) -> int:
    """Return how many portfolios would be purged by the next sweep.

    Useful for the operational dashboard and for staging dry-runs; the
    arithmetic mirrors :func:`purge_inactive_portfolios` exactly so the
    two never disagree.

    Args:
      now: Reference timestamp; defaults to UTC now.
      retention_days: Inactivity window; defaults to the configured value.

    Returns:
      The number of portfolio rows that would match the purge predicate.
    """
    if now is None:
        now = datetime.now(UTC)
    if retention_days is None:
        retention_days = config.PORTFOLIO_RETENTION_DAYS

    cutoff = _cutoff(now, retention_days)

    with common_db.get_session() as session:
        return (
            session.scalar(
                select(func.count(Portfolio.id)).where(
                    or_(
                        Portfolio.last_seen_at < cutoff,
                        (Portfolio.last_seen_at.is_(None))
                        & (Portfolio.created_at < cutoff),
                    )
                )
            )
            or 0
        )
