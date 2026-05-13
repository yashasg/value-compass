"""SQLAlchemy engine + session factory shared between the API and poller.

The connection string is read from ``DATABASE_URL`` exactly once at import
time. If the variable is unset (e.g. in unit tests) the engine is created
lazily so that test code can patch :func:`get_engine` / :func:`get_session`
without ever opening a real connection.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from typing import Optional

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from common import config

_engine: Optional[Engine] = None
_SessionLocal: Optional[sessionmaker[Session]] = None


def get_engine() -> Engine:
    """Return a process-wide SQLAlchemy engine, creating it on first use."""
    global _engine, _SessionLocal
    if _engine is None:
        if not config.DATABASE_URL:
            raise RuntimeError(
                "DATABASE_URL is not set; refusing to create a SQLAlchemy "
                "engine without an explicit connection string."
            )
        _engine = create_engine(config.DATABASE_URL, future=True, pool_pre_ping=True)
        _SessionLocal = sessionmaker(
            bind=_engine, autoflush=False, autocommit=False, future=True
        )
    return _engine


@contextmanager
def get_session() -> Iterator[Session]:
    """Context manager yielding a SQLAlchemy session."""
    get_engine()  # ensure _SessionLocal is initialised
    assert _SessionLocal is not None
    session = _SessionLocal()
    try:
        yield session
    finally:
        session.close()
