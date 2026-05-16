"""Logging helpers shared by ``backend/api`` and ``backend/poller``.

Centralizes redaction primitives so the 30-day journald retention floor
in ``docs/legal/data-retention.md`` is paired with a single
implementation rather than re-asserted per-caller. The original
redaction primitive shipped in ``backend/poller/apns.py``; this module
is the long-term home so the DSR audit-log surface in
``backend/api/main.py`` (issue #445 — read-side export; #457 — write-side
rectification/erasure) and the APNs push surface read from the same
helper.
"""

from __future__ import annotations

from uuid import UUID


def redact_device_uuid(device_uuid: UUID) -> str:
    """Return a safe-to-log short suffix for a device UUID.

    Two operational needs to satisfy:

    * Logs must still be useful for correlating "did this device hit
      this endpoint?" against an in-flight bug report.
    * Logs must not store the raw identifier (GDPR Art. 25 / data
      protection by design); the persisted DB row is the system of
      record, not journald.

    The last four hex characters of a UUID give ~16 bits of identity —
    enough for a developer to spot a matching device in a single bug
    report, far too few to re-identify across the user base. Format
    keeps the field aligned in grep output (``…abcd``).

    Paired with the 30-day journald retention floor enforced by
    ``backend/infra/systemd/journald-vca-retention.conf`` and documented
    in the "Application logs" row of ``docs/legal/data-retention.md``.
    """
    return f"…{str(device_uuid)[-4:]}"
