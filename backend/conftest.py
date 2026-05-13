"""Shared pytest configuration for backend tests.

The production processes are launched from inside the ``backend/``
directory (see ``infra/systemd/*.service``), so the source modules
import each other as ``api``, ``poller``, ``db``, ``common`` — without
the ``backend.`` prefix. We mirror that here by inserting ``backend/``
on ``sys.path`` so tests can ``import api.main`` etc. regardless of the
directory pytest is invoked from.
"""

from __future__ import annotations

import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))
