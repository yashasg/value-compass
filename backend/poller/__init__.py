"""vca-poller — APScheduler nightly job package.

Run as ``python -m poller`` (matches the systemd unit). The job logic
lives in :mod:`poller.job`, the scheduler bootstrap in :mod:`poller.__main__`.
"""
