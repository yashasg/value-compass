"""The nightly job itself.

Sequence (per the spec):

1. Skip if today is not a US trading day.
2. Fetch OHLC bars per ticker, throttled to 5 req/min.
3. Compute VCA midline, ATR, bands, and band position.
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
from collections.abc import Iterable
from datetime import UTC, date, datetime, timedelta

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
    """Return a simple ``next_modified`` projection 24 h ahead.

    The exact
    next trigger is recomputed by APScheduler; ``next_modified`` is only
    a hint surfaced to the iOS client for cache-window display.
    """
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


async def _fetch_all(tickers: list[str]) -> dict[str, polygon.BandMetrics]:
    async with httpx.AsyncClient() as client:
        return await polygon.fetch_band_metrics_rate_limited(tickers, client)


def run_nightly_job(today: date | None = None) -> str:
    """Entry point invoked by APScheduler.

    Returns one of ``"skipped"``, ``"success"``, or ``"failed"`` —
    handy for tests and for an external watchdog log scrape.
    """
    today = today or datetime.now(UTC).date()
    if not is_trading_day(today):
        log.info("today (%s) is not a trading day — skipping job", today)
        return "skipped"

    with common_db.get_session() as session:
        tickers = _tracked_tickers(session)
        if not tickers:
            log.info("no tracked tickers — nothing to do")
            return "success"

        try:
            metrics_by_ticker = asyncio.run(_fetch_all(tickers))
            now = datetime.now(UTC)
            next_at = _next_run_after(now)

            for ticker in tickers:
                metrics = metrics_by_ticker.get(ticker)
                if metrics is None:
                    raise polygon.PolygonError(
                        f"missing data for {ticker} after fetch"
                    )
                row = session.get(StockCache, ticker)
                if row is None:
                    session.add(
                        StockCache(
                            ticker=ticker,
                            current_price=metrics.current_price,
                            sma_50=metrics.midline,
                            sma_200=metrics.midline,
                            midline=metrics.midline,
                            atr=metrics.atr,
                            upper_band=metrics.upper_band,
                            lower_band=metrics.lower_band,
                            band_position=metrics.band_position,
                            last_modified=now,
                            next_modified=next_at,
                            job_status="success",
                        )
                    )
                else:
                    row.current_price = metrics.current_price
                    row.sma_50 = metrics.midline
                    row.sma_200 = metrics.midline
                    row.midline = metrics.midline
                    row.atr = metrics.atr
                    row.upper_band = metrics.upper_band
                    row.lower_band = metrics.lower_band
                    row.band_position = metrics.band_position
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
