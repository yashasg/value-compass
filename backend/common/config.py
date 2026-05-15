"""Runtime configuration for value-compass backend services.

All values are read from environment variables — no secrets in source.
Production environment variables are set on the host by the systemd
``Environment=`` / ``EnvironmentFile=`` directives of the corresponding
service unit (see ``backend/infra/systemd/``).
"""

from __future__ import annotations

import os

# ---------------------------------------------------------------------------
# API schema version, served at ``GET /schema/version`` and used by the iOS
# client to decide whether it must force-upgrade. Bump on every breaking
# change to a response shape.
# ---------------------------------------------------------------------------
SCHEMA_VERSION: int = 1

# Minimum supported iOS app version, surfaced as ``X-Min-App-Version`` on
# every response.
MIN_APP_VERSION: str = os.getenv("VCA_MIN_APP_VERSION", "1.0.0")

# ``Cache-Control: max-age=`` value (seconds). Cloudflare honours this on
# the edge — see backend/api/README.md.
CACHE_MAX_AGE: int = 3600

# ---------------------------------------------------------------------------
# External services
# ---------------------------------------------------------------------------
DATABASE_URL: str = os.getenv("DATABASE_URL", "")
POLYGON_API_KEY: str = os.getenv("POLYGON_API_KEY", "")
APNS_CERT_PATH: str = os.getenv("APNS_CERT", "")

# ---------------------------------------------------------------------------
# Poller
# ---------------------------------------------------------------------------
# The poller fires at 17:00 America/New_York on US trading days only.
POLLER_HOUR_ET: int = 17
POLLER_MINUTE_ET: int = 0
POLLER_TIMEZONE: str = "America/New_York"

# Polygon's free SMA endpoint is rate-limited to 5 requests / minute. The
# poller uses this as the inter-request delay (12 s) so we never burst.
POLYGON_SMA_REQUESTS_PER_MIN: int = 5

# Alert if ``stock_cache.last_modified`` is older than this — one trading
# day plus a 2 h grace window.
STALE_ALERT_HOURS: int = 26

# ---------------------------------------------------------------------------
# Data retention — see ``docs/legal/data-retention.md``
# ---------------------------------------------------------------------------
# Inactivity window after which a portfolio row (and cascaded holdings) is
# purged by the retention sweep. Default 540 days ≈ 18 months, mirroring
# CNIL guidance for low-sensitivity pseudonymous identifiers. Override via
# the ``PORTFOLIO_RETENTION_DAYS`` env var to tune the schedule without a
# code change (counsel sign-off on the final value).
PORTFOLIO_RETENTION_DAYS: int = int(os.getenv("PORTFOLIO_RETENTION_DAYS", "540"))

# Daily hour (UTC) at which the retention sweep runs. Separate from the
# nightly market-data job so the two jobs never compete for the database
# during peak fetch windows. Override via ``PURGE_HOUR_UTC`` for staging
# environments that want to fire the sweep on-demand.
PURGE_HOUR_UTC: int = int(os.getenv("PURGE_HOUR_UTC", "3"))
PURGE_MINUTE_UTC: int = int(os.getenv("PURGE_MINUTE_UTC", "0"))
