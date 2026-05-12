"""Polygon.io client for the poller and the API's new-ticker background task.

This is a *thin* client — only the two endpoints listed in the spec:

* The aggregate snapshot endpoint, used to fetch the current price for
  every tracked ticker in **one** request.
* The SMA endpoint, called once per ticker (rate-limited to 5 req/min
  on the free tier — the limiter lives here).

Network calls go through ``httpx.AsyncClient`` so the same code can be
awaited from FastAPI's ``BackgroundTasks`` or from the synchronous
APScheduler job (via ``asyncio.run``).
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Iterable

import httpx

from common import config, db as common_db
from db.models import StockCache

log = logging.getLogger("vca.polygon")

_BASE_URL = "https://api.polygon.io"

# 5 requests / minute → 12 s between SMA calls.
_SMA_DELAY_SEC = 60.0 / config.POLYGON_SMA_REQUESTS_PER_MIN


class PolygonError(RuntimeError):
    """Raised when Polygon returns a non-2xx response or malformed body."""


async def fetch_snapshot_prices(
    tickers: Iterable[str], client: httpx.AsyncClient
) -> dict[str, Decimal]:
    """Fetch the current price for every ticker in one request.

    Maps to Polygon's ``/v2/snapshot/locale/us/markets/stocks/tickers``
    endpoint. Returns ``{ticker: price}``; tickers Polygon does not
    return are simply absent from the dict (the caller decides how to
    treat that).
    """
    params = {
        "tickers": ",".join(tickers),
        "apiKey": config.POLYGON_API_KEY,
    }
    resp = await client.get(
        f"{_BASE_URL}/v2/snapshot/locale/us/markets/stocks/tickers",
        params=params,
        timeout=30.0,
    )
    if resp.status_code != 200:
        raise PolygonError(f"snapshot HTTP {resp.status_code}: {resp.text}")
    body = resp.json()
    out: dict[str, Decimal] = {}
    for entry in body.get("tickers", []):
        ticker = entry.get("ticker")
        # Prefer the previous day close for after-hours runs — matches the
        # spec's 5 PM ET schedule, where regular-session prices are final.
        price = (
            entry.get("day", {}).get("c")
            or entry.get("prevDay", {}).get("c")
            or entry.get("lastTrade", {}).get("p")
        )
        if ticker and price is not None:
            out[ticker] = Decimal(str(price))
    return out


async def fetch_sma(
    ticker: str, window: int, client: httpx.AsyncClient
) -> Decimal:
    """Fetch the latest simple moving average for ``ticker``.

    Maps to ``/v1/indicators/sma/{ticker}``.
    """
    params = {
        "timespan": "day",
        "window": window,
        "series_type": "close",
        "order": "desc",
        "limit": 1,
        "apiKey": config.POLYGON_API_KEY,
    }
    resp = await client.get(
        f"{_BASE_URL}/v1/indicators/sma/{ticker}",
        params=params,
        timeout=30.0,
    )
    if resp.status_code != 200:
        raise PolygonError(f"SMA {ticker}/{window} HTTP {resp.status_code}")
    body = resp.json()
    values = body.get("results", {}).get("values") or []
    if not values:
        raise PolygonError(f"SMA {ticker}/{window} returned no values")
    return Decimal(str(values[0]["value"]))


async def fetch_smas_rate_limited(
    tickers: list[str], window: int, client: httpx.AsyncClient
) -> dict[str, Decimal]:
    """Fetch SMAs for many tickers, sleeping to respect 5 req/min."""
    out: dict[str, Decimal] = {}
    for i, ticker in enumerate(tickers):
        if i > 0:
            await asyncio.sleep(_SMA_DELAY_SEC)
        out[ticker] = await fetch_sma(ticker, window, client)
    return out


async def fetch_and_cache_ticker(ticker: str) -> None:
    """Fetch a single ticker (used by the API's new-ticker flow) and
    upsert it into ``stock_cache`` with ``job_status = 'success'``.
    """
    async with httpx.AsyncClient() as client:
        prices = await fetch_snapshot_prices([ticker], client)
        if ticker not in prices:
            raise PolygonError(f"snapshot did not return {ticker}")
        sma_50 = await fetch_sma(ticker, 50, client)
        await asyncio.sleep(_SMA_DELAY_SEC)
        sma_200 = await fetch_sma(ticker, 200, client)

    now = datetime.now(timezone.utc)
    with common_db.get_session() as session:
        existing = session.get(StockCache, ticker)
        if existing is None:
            session.add(
                StockCache(
                    ticker=ticker,
                    current_price=prices[ticker],
                    sma_50=sma_50,
                    sma_200=sma_200,
                    last_modified=now,
                    next_modified=now + timedelta(hours=24),
                    job_status="success",
                )
            )
        else:
            existing.current_price = prices[ticker]
            existing.sma_50 = sma_50
            existing.sma_200 = sma_200
            existing.last_modified = now
            existing.next_modified = now + timedelta(hours=24)
            existing.job_status = "success"
        session.commit()
