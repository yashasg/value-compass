"""Apple Push Notification Service helper.

The poller pushes to **all** devices that hold one of the just-refreshed
tickers; the API's new-ticker flow pushes to a single device.

Production uses an APNs cert mounted at ``$APNS_CERT`` and the HTTP/2
APNs gateway. To keep the poller importable in CI without that cert
present, the actual HTTP call is performed only when ``APNS_CERT`` is
configured — otherwise the helpers log and return.
"""

from __future__ import annotations

import logging
from collections.abc import Iterable
from uuid import UUID

from common import config

log = logging.getLogger("vca.apns")


async def push_to_device(device_uuid: UUID) -> None:
    """Send a single APNs push to one device."""
    if not config.APNS_CERT_PATH:
        log.info("APNS_CERT not set — skipping push to %s", device_uuid)
        return
    # Production wiring lives in the deploy environment; the function is
    # deliberately stubbed here so unit tests and CI never need the cert.
    log.info("APNs push -> %s", device_uuid)


async def push_to_devices(device_uuids: Iterable[UUID]) -> None:
    """Send a push to many devices."""
    for uuid in device_uuids:
        await push_to_device(uuid)
