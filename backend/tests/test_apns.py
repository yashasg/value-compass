"""Tests for the APNs log-redaction contract (issue #339).

The raw ``device_uuid`` must never appear in a journald-captured log
line; only the last-4 hex suffix may. See ``docs/legal/data-retention.md``
for the schedule this redaction pairs with, and
``backend/poller/apns.py::_redact`` for the implementation.
"""

from __future__ import annotations

import asyncio
import logging
import os
import uuid

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from common import config  # noqa: E402
from poller import apns  # noqa: E402


def test_redact_returns_last_four_hex_with_ellipsis() -> None:
    device_uuid = uuid.UUID("12345678-1234-5678-1234-1234567890ab")
    redacted = apns._redact(device_uuid)
    assert redacted == "…90ab"


def test_push_to_device_logs_only_redacted_suffix(
    caplog: pytest.LogCaptureFixture, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(config, "APNS_CERT_PATH", "")
    device_uuid = uuid.UUID("12345678-1234-5678-1234-1234567890ab")
    with caplog.at_level(logging.INFO, logger="vca.apns"):
        asyncio.run(apns.push_to_device(device_uuid))

    full_uuid_str = str(device_uuid)
    log_text = "\n".join(record.getMessage() for record in caplog.records)
    # Critical contract: the raw, full UUID must not appear in any log
    # line emitted by this module. Only the trailing-4 suffix may.
    assert full_uuid_str not in log_text
    assert "…90ab" in log_text


def test_push_to_device_redacts_even_when_apns_cert_configured(
    caplog: pytest.LogCaptureFixture, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(config, "APNS_CERT_PATH", "/etc/secrets/apns.pem")
    device_uuid = uuid.UUID("12345678-1234-5678-1234-1234567890ab")
    with caplog.at_level(logging.INFO, logger="vca.apns"):
        asyncio.run(apns.push_to_device(device_uuid))

    full_uuid_str = str(device_uuid)
    log_text = "\n".join(record.getMessage() for record in caplog.records)
    assert full_uuid_str not in log_text
    assert "…90ab" in log_text
