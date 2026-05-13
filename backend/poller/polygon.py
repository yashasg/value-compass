"""Polygon.io client for the poller and the API's new-ticker background task.

This is a *thin* client for Polygon's daily aggregate endpoint. The poller
derives the VCA midline, ATR, bands, and current band position locally from
the most recent 22 daily OHLC bars.

Network calls go through ``httpx.AsyncClient`` so the same code can be
awaited from FastAPI's ``BackgroundTasks`` or from the synchronous
APScheduler job (via ``asyncio.run``).
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import httpx

from common import config
from common import db as common_db
from db.models import StockCache

log = logging.getLogger("vca.polygon")

_BASE_URL = "https://api.polygon.io"

# 5 requests / minute → 12 s between aggregate calls.
_SMA_DELAY_SEC = 60.0 / config.POLYGON_SMA_REQUESTS_PER_MIN
_BAND_WINDOW = 21
_AGG_LOOKBACK_DAYS = 30
_BAND_SHIFT = Decimal("2.23")


class PolygonError(RuntimeError):
    """Raised when Polygon returns a non-2xx response or malformed body."""


@dataclass(frozen=True)
class BandMetrics:
    """OHLC-derived metrics cached for one ticker."""

    current_price: Decimal
    midline: Decimal
    atr: Decimal
    upper_band: Decimal
    lower_band: Decimal
    band_position: Decimal


@dataclass(frozen=True)
class DailyBar:
    """One daily OHLC aggregate bar from Polygon."""

    timestamp: int
    open: Decimal
    high: Decimal
    low: Decimal
    close: Decimal


async def fetch_band_metrics(
    ticker: str, client: httpx.AsyncClient, today: date | None = None
) -> BandMetrics:
    """Fetch daily OHLC bars and compute VCA band metrics for ``ticker``."""
    today = today or datetime.now(UTC).date()
    from_date = today - timedelta(days=_AGG_LOOKBACK_DAYS)
    resp = await client.get(
        f"{_BASE_URL}/v2/aggs/ticker/{ticker}/range/1/day/{from_date}/{today}",
        params={"adjusted": "true", "sort": "asc", "apiKey": config.POLYGON_API_KEY},
        timeout=30.0,
    )
    if resp.status_code != 200:
        raise PolygonError(f"aggs {ticker} HTTP {resp.status_code}: {resp.text}")

    return compute_band_metrics(_parse_daily_bars(resp.json(), ticker), ticker)


async def fetch_band_metrics_rate_limited(
    tickers: list[str], client: httpx.AsyncClient, today: date | None = None
) -> dict[str, BandMetrics]:
    """Fetch band metrics for many tickers, sleeping to respect rate limits."""
    out: dict[str, BandMetrics] = {}
    for i, ticker in enumerate(tickers):
        if i > 0:
            await asyncio.sleep(_SMA_DELAY_SEC)
        out[ticker] = await fetch_band_metrics(ticker, client, today=today)
    return out


def compute_band_metrics(bars: list[DailyBar], ticker: str) -> BandMetrics:
    """Compute midline, ATR, and band position from ascending OHLC bars."""
    recent_bars = sorted(bars, key=lambda bar: bar.timestamp)[-_BAND_WINDOW - 1 :]
    if len(recent_bars) < _BAND_WINDOW + 1:
        raise PolygonError(
            f"aggs {ticker} returned {len(recent_bars)} bars; need 22"
        )

    closes = [bar.close for bar in recent_bars]
    midline = sum(closes[1:], Decimal(0)) / Decimal(_BAND_WINDOW)
    true_ranges = []
    for index in range(1, len(recent_bars)):
        bar = recent_bars[index]
        previous_close = recent_bars[index - 1].close
        true_ranges.append(
            max(
                bar.high - bar.low,
                abs(bar.high - previous_close),
                abs(bar.low - previous_close),
            )
        )

    atr = sum(true_ranges, Decimal(0)) / Decimal(_BAND_WINDOW)
    upper_band = midline + (_BAND_SHIFT * atr)
    lower_band = midline - (_BAND_SHIFT * atr)
    width = upper_band - lower_band
    if width <= 0:
        raise PolygonError(f"aggs {ticker} produced invalid band width")

    current_price = closes[-1]
    band_position = (current_price - lower_band) / width
    return BandMetrics(
        current_price=current_price,
        midline=midline,
        atr=atr,
        upper_band=upper_band,
        lower_band=lower_band,
        band_position=band_position,
    )


def _parse_daily_bars(body: dict, ticker: str) -> list[DailyBar]:
    results = body.get("results") or []
    bars: list[DailyBar] = []
    for raw in results:
        try:
            bars.append(
                DailyBar(
                    timestamp=int(raw["t"]),
                    open=Decimal(str(raw["o"])),
                    high=Decimal(str(raw["h"])),
                    low=Decimal(str(raw["l"])),
                    close=Decimal(str(raw["c"])),
                )
            )
        except (KeyError, TypeError, ValueError) as exc:
            raise PolygonError(f"aggs {ticker} returned malformed bar") from exc
    return bars


async def fetch_and_cache_ticker(ticker: str) -> None:
    """Fetch and cache a single ticker for the API's new-ticker flow.

    upsert it into ``stock_cache`` with ``job_status = 'success'``.
    """
    async with httpx.AsyncClient() as client:
        metrics = await fetch_band_metrics(ticker, client)

    now = datetime.now(UTC)
    with common_db.get_session() as session:
        existing = session.get(StockCache, ticker)
        if existing is None:
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
                    next_modified=now + timedelta(hours=24),
                    job_status="success",
                )
            )
        else:
            existing.current_price = metrics.current_price
            existing.sma_50 = metrics.midline
            existing.sma_200 = metrics.midline
            existing.midline = metrics.midline
            existing.atr = metrics.atr
            existing.upper_band = metrics.upper_band
            existing.lower_band = metrics.lower_band
            existing.band_position = metrics.band_position
            existing.last_modified = now
            existing.next_modified = now + timedelta(hours=24)
            existing.job_status = "success"
        session.commit()
