"""Entry point for ``python -m poller``.

Boots an :class:`apscheduler.schedulers.blocking.BlockingScheduler` that
fires :func:`poller.job.run_nightly_job` at 17:00 America/New_York on US
trading days only (weekends and market holidays are skipped via
:mod:`pandas_market_calendars`).
"""

from __future__ import annotations

import logging
import signal
import sys

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger

from common import config
from poller.job import run_nightly_job

log = logging.getLogger("vca.poller")


def build_scheduler() -> BlockingScheduler:
    """Wire up the BlockingScheduler with the nightly cron trigger."""
    scheduler = BlockingScheduler(timezone=config.POLLER_TIMEZONE)
    scheduler.add_job(
        run_nightly_job,
        trigger=CronTrigger(
            day_of_week="mon-fri",
            hour=config.POLLER_HOUR_ET,
            minute=config.POLLER_MINUTE_ET,
            timezone=config.POLLER_TIMEZONE,
        ),
        id="vca-poller-nightly",
        name="value-compass nightly poller",
        max_instances=1,
        coalesce=True,
        misfire_grace_time=60 * 30,  # 30 min — survive brief VM restarts
    )
    return scheduler


def main() -> int:
    """Start the blocking scheduler process."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )
    scheduler = build_scheduler()

    # Clean shutdown on SIGTERM (systemd ``stop``) so any in-flight job
    # finishes its DB transaction before the process exits.
    def _shutdown(signum, _frame):  # noqa: ANN001
        log.info("received signal %s — shutting down scheduler", signum)
        scheduler.shutdown(wait=True)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    log.info(
        "starting vca-poller — fires at %02d:%02d %s on trading days",
        config.POLLER_HOUR_ET,
        config.POLLER_MINUTE_ET,
        config.POLLER_TIMEZONE,
    )
    scheduler.start()
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
