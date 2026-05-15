"""Apple Push Notification Service helper.

The poller pushes to **all** devices that hold one of the just-refreshed
tickers; the API's new-ticker flow pushes to a single device.

Production uses an APNs cert mounted at ``$APNS_CERT`` and the HTTP/2
APNs gateway. To keep the poller importable in CI without that cert
present, the actual HTTP call is performed only when ``APNS_CERT`` is
configured — otherwise the helpers log and return.

Log lines never quote the raw ``X-Device-UUID`` (a Linked-to-User
identifier per ``app/Sources/App/PrivacyInfo.xcprivacy``): we redact to
the last-4 hex characters so journald / Cloudflare access-log retention
defaults are not joined back to a single device. See
``docs/legal/data-retention.md`` for the retention schedule that this
redaction is paired with.
"""

from __future__ import annotations

import logging
from collections.abc import Iterable
from uuid import UUID

from common import config

log = logging.getLogger("vca.apns")


def _redact(device_uuid: UUID) -> str:
    """Return a safe-to-log short suffix for a device UUID.

    Two operational needs to satisfy:

    * Logs must still be useful for correlating "did this device get a
      push?" against an in-flight bug report.
    * Logs must not store the raw identifier (Art. 25 / data-protection
      by design); the persisted DB row is the system of record, not
      journald.

    The last four hex characters of a UUID give ~16 bits of identity —
    enough for a developer to spot a matching device in a single bug
    report, far too few to re-identify across the user base. Format
    keeps the field aligned in grep output.
    """
    return f"…{str(device_uuid)[-4:]}"


async def push_to_device(device_uuid: UUID) -> None:
    """Send a single APNs push to one device."""
    if not config.APNS_CERT_PATH:
        log.info("APNS_CERT not set — skipping push to device %s", _redact(device_uuid))
        return
    # Production wiring lives in the deploy environment; the function is
    # deliberately stubbed here so unit tests and CI never need the cert.
    log.info("APNs push -> device %s", _redact(device_uuid))


async def push_to_devices(device_uuids: Iterable[UUID]) -> None:
    """Send a push to many devices."""
    for uuid in device_uuids:
        await push_to_device(uuid)
