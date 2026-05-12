"""The nightly job itself.

Sequence (per the spec):

1. Skip if today is not a US trading day.
2. Fetch current prices for all tracked tickers (1 request).
3. Fetch SMA per ticker, throttled to 5 req/min.
4. Write results to ``stock_cache``.
5. On success: ``job_status = 'success'``; update ``last_modified`` and
   ``next_modified``.
6. Send APNs push to affected devices.

Failure handling:

* On any exception, every affected ``stock_cache`` row is marked
  ``job_status = 'failed'`` and **neither** ``last_modified`` **nor**
  ``next_modified`` is updated. Clients therefore stay within their
  cached window and do not retry-storm; the ``last_modified`` staleness
  alarm (``STALE_ALERT_HOURS``) is what surfaces a stuck poller.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Iterable

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from common import db as common_db
from db.models import Holding, Portfolio, StockCache
from poller import apns, polygon
from poller.calendar_guard import is_trading_day

log = logging.getLogger("vca.poller.job")


def _tracked_tickers(session: Session) -> list[str]:
    """All distinct tickers any portfolio currently holds."""
    rows = session.execute(select(Holding.ticker).distinct()).all()
    return sorted({r[0] for r in rows})


def _next_run_after(now: datetime) -> datetime:
    """A simple ``next_modified`` projection — 24 h ahead. The exact
    next trigger is recomputed by APScheduler; ``next_modified`` is only
    a hint surfaced to the iOS client for cache-window display."""
    return now + timedelta(hours=24)


def _devices_holding(session: Session, tickers: Iterable[str]) -> list:
    """All device UUIDs whose portfolio contains any of ``tickers``."""
    tickers = list(tickers)
    if not tickers:
        return []
    rows = session.execute(
        select(Portfolio.device_uuid)
        .join(Holding, Holding.portfolio_id == Portfolio.id)
        .where(Holding.ticker.in_(tickers))
        .distinct()
    ).all()
    return [r[0] for r in rows]


async def _fetch_all(tickers: list[str]) -> tuple[
    dict[str, "polygon.Decimal"],
    dict[str, "polygon.Decimal"],
    dict[str, "polygon.Decimal"],
]:
    async with httpx.AsyncClient() as client:
        prices = await polygon.fetch_snapshot_prices(tickers, client)
        sma_50 = await polygon.fetch_smas_rate_limited(tickers, 50, client)
        sma_200 = await polygon.fetch_smas_rate_limited(tickers, 200, client)
    return prices, sma_50, sma_200


def run_nightly_job(today: date | None = None) -> str:
    """Entry point invoked by APScheduler.

    Returns one of ``"skipped"``, ``"success"``, or ``"failed"`` —
    handy for tests and for an external watchdog log scrape.
    """
    today = today or datetime.now(timezone.utc).date()
    if not is_trading_day(today):
        log.info("today (%s) is not a trading day — skipping job", today)
        return "skipped"

    with common_db.get_session() as session:
        tickers = _tracked_tickers(session)
        if not tickers:
            log.info("no tracked tickers — nothing to do")
            return "success"

        try:
            prices, sma_50, sma_200 = asyncio.run(_fetch_all(tickers))
            now = datetime.now(timezone.utc)
            next_at = _next_run_after(now)

            for ticker in tickers:
                if ticker not in prices or ticker not in sma_50 or ticker not in sma_200:
                    raise polygon.PolygonError(
                        f"missing data for {ticker} after fetch"
                    )
                row = session.get(StockCache, ticker)
                if row is None:
                    session.add(
                        StockCache(
                            ticker=ticker,
                            current_price=prices[ticker],
                            sma_50=sma_50[ticker],
                            sma_200=sma_200[ticker],
                            last_modified=now,
                            next_modified=next_at,
                            job_status="success",
                        )
                    )
                else:
                    row.current_price = prices[ticker]
                    row.sma_50 = sma_50[ticker]
                    row.sma_200 = sma_200[ticker]
                    row.last_modified = now
                    row.next_modified = next_at
                    row.job_status = "success"
            session.commit()
        except Exception:  # noqa: BLE001 — flag failure, propagate to logs only
            log.exception("nightly job failed; marking job_status=failed")
            session.rollback()
            # Mark known tickers as failed but do NOT touch last_modified /
            # next_modified — clients keep their cached window.
            for ticker in tickers:
                row = session.get(StockCache, ticker)
                if row is not None:
                    row.job_status = "failed"
            session.commit()
            return "failed"

        # Step 6: APNs push to every affected device.
        devices = _devices_holding(session, tickers)

    asyncio.run(apns.push_to_devices(devices))
    log.info("nightly job complete: %d tickers, %d devices", len(tickers), len(devices))
    return "success"
