"""US market trading-day calendar guard.

The APScheduler cron trigger fires Mon–Fri at 17:00 ET, but the NYSE is
also closed on observed market holidays. We use
``pandas_market_calendars`` to short-circuit the job on those days — the
spec says weekends *and* market holidays must be skipped.
"""

from __future__ import annotations

from datetime import date

import pandas_market_calendars as mcal

_CALENDAR = mcal.get_calendar("NYSE")


def is_trading_day(today: date) -> bool:
    """Return True if ``today`` is a US equity trading day."""
    schedule = _CALENDAR.schedule(start_date=today, end_date=today)
    return not schedule.empty
