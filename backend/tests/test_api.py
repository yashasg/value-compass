"""Tests for the FastAPI vca-api app.

Uses an in-memory SQLite database via SQLAlchemy and a
``dependency_overrides`` swap so the tests never touch Postgres.
"""

from __future__ import annotations

import os
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

# Force a usable DATABASE_URL before importing the app, so the lazy
# ``common.db.get_engine`` does not blow up at import time.
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine, select  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from api.export_openapi import CONTRACT_PATHS, render_openapi_contract  # noqa: E402
from api.main import app, get_db  # noqa: E402
from common import config  # noqa: E402
from db.models import Base, Holding, Portfolio, StockCache  # noqa: E402


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        future=True,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(
        bind=engine, autoflush=False, autocommit=False, future=True
    )
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def client(db_session: Session):
    def _override():
        yield db_session

    app.dependency_overrides[get_db] = _override
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


ATTEST = {"X-App-Attest": "test-token"}


def test_health_ok(client: TestClient) -> None:
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}
    # Spec-mandated headers on every response:
    assert resp.headers["Cache-Control"] == "max-age=3600"
    assert "Last-Modified" in resp.headers
    assert "X-Min-App-Version" in resp.headers


def test_schema_version_requires_attest(client: TestClient) -> None:
    unauthorized = client.get("/schema/version")
    assert unauthorized.status_code == 401
    assert unauthorized.json() == {
        "code": "appAttestMissing",
        "message": "Missing X-App-Attest header.",
        "retry_after_seconds": None,
    }

    resp = client.get("/schema/version", headers=ATTEST)
    assert resp.status_code == 200
    body = resp.json()
    assert body["version"] >= 1
    # ``min_app_version`` is intentionally NOT in the response body — the
    # authoritative channel is the ``X-Min-App-Version`` response header
    # declared on every operation. See issue #402.
    assert "min_app_version" not in body
    assert resp.headers["X-Min-App-Version"] == config.MIN_APP_VERSION


def test_openapi_describes_error_envelope(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    components = schema["components"]["schemas"]
    error_schema = components["ErrorEnvelope"]

    assert error_schema["properties"]["code"]["$ref"].endswith("/ErrorCode")
    assert "syncUnavailable" in components["ErrorCode"]["enum"]
    assert (
        schema["paths"]["/portfolio/data"]["get"]["responses"]["404"]["content"][
            "application/json"
        ]["schema"]["$ref"]
        == "#/components/schemas/ErrorEnvelope"
    )
    assert (
        schema["paths"]["/portfolio/data"]["get"]["responses"]["422"]["content"][
            "application/json"
        ]["schema"]["$ref"]
        == "#/components/schemas/ErrorEnvelope"
    )
    schema_version = components["SchemaVersionResponse"]
    # ``min_app_version`` was removed from the response body in favor of the
    # ``X-Min-App-Version`` response header which is declared on every
    # operation (issue #402). Lock the removal so reintroducing the dead
    # body channel fails contract tests.
    assert "min_app_version" not in schema_version["properties"]
    assert "min_app_version" not in schema_version.get("required", [])
    schema_version_200 = schema["paths"]["/schema/version"]["get"]["responses"]["200"]
    assert "X-Min-App-Version" in schema_version_200["headers"]


def test_checked_in_openapi_artifacts_match_fastapi() -> None:
    contract = render_openapi_contract()

    for path in CONTRACT_PATHS:
        assert path.read_text(encoding="utf-8") == contract


PROTECTED_OPERATIONS: tuple[tuple[str, str], ...] = (
    ("/schema/version", "get"),
    ("/portfolio/status", "get"),
    ("/portfolio/data", "get"),
    ("/portfolio/export", "get"),
    ("/portfolio/holdings", "post"),
)


def _x_app_attest_parameter(operation: dict) -> dict:
    for parameter in operation.get("parameters", []):
        if parameter.get("in") == "header" and parameter.get("name") == "X-App-Attest":
            return parameter
    operation_id = operation.get("operationId")
    raise AssertionError(
        f"X-App-Attest header parameter missing on operation: {operation_id}"
    )


def test_protected_routes_mark_x_app_attest_required(client: TestClient) -> None:
    """Every protected operation must advertise X-App-Attest as required.

    Regression guard for issue #225: generated clients otherwise emit
    requests that deterministically fail with ``401 appAttestMissing``.
    """
    schema = client.get("/openapi.json").json()
    paths = schema["paths"]

    for path, method in PROTECTED_OPERATIONS:
        parameter = _x_app_attest_parameter(paths[path][method])
        assert parameter["required"] is True, (
            f"X-App-Attest must be required on {method.upper()} {path}"
        )
        # The parameter schema should be a non-nullable string so generated
        # clients emit a header value rather than serialising ``null``.
        assert parameter["schema"].get("type") == "string"
        assert "anyOf" not in parameter["schema"]

    # /health must remain attestation-free; document the exemption.
    health_get = paths["/health"]["get"]
    assert all(
        parameter.get("name") != "X-App-Attest"
        for parameter in health_get.get("parameters", [])
    )


def test_protected_routes_reject_missing_x_app_attest(client: TestClient) -> None:
    """Backend behaviour must continue to reject missing X-App-Attest.

    The OpenAPI spec marks the header required so clients can never omit it,
    but the runtime guarantee is what makes the contract enforceable.
    """
    expected_envelope = {
        "code": "appAttestMissing",
        "message": "Missing X-App-Attest header.",
        "retry_after_seconds": None,
    }

    requests = (
        ("get", "/schema/version", None),
        ("get", "/portfolio/status", None),
        ("get", "/portfolio/data", {"device_uuid": str(uuid.uuid4())}),
        ("get", "/portfolio/export", {"device_uuid": str(uuid.uuid4())}),
        (
            "post",
            "/portfolio/holdings",
            None,
        ),
    )

    for method, path, params in requests:
        if method == "get":
            response = client.get(path, params=params)
        else:
            response = client.post(
                path,
                params=params,
                json={"device_uuid": str(uuid.uuid4()), "ticker": "AAPL"},
            )
        assert response.status_code == 401, (
            f"{method.upper()} {path} should reject missing X-App-Attest"
        )
        assert response.json() == expected_envelope


def test_validation_errors_use_error_envelope(client: TestClient) -> None:
    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": "not-a-uuid"},
        headers=ATTEST,
    )

    assert resp.status_code == 422
    assert resp.json() == {
        "code": "schemaUnsupported",
        "message": "Request validation failed.",
        "retry_after_seconds": None,
    }


def test_portfolio_status_empty(client: TestClient) -> None:
    resp = client.get("/portfolio/status", headers=ATTEST)
    assert resp.status_code == 200
    assert resp.json() == {"last_modified": None, "next_modified": None}


def test_portfolio_status_returns_latest(
    client: TestClient, db_session: Session
) -> None:
    now = datetime.now(UTC).replace(microsecond=0)
    db_session.add(
        StockCache(
            ticker="AAPL",
            current_price=Decimal("100"),
            sma_50=Decimal("99"),
            sma_200=Decimal("98"),
            last_modified=now,
            next_modified=now + timedelta(hours=24),
            job_status="success",
        )
    )
    db_session.commit()
    resp = client.get("/portfolio/status", headers=ATTEST)
    assert resp.status_code == 200
    body = resp.json()
    assert body["last_modified"] is not None
    assert body["next_modified"] is not None


def test_portfolio_data_404_for_unknown_device(client: TestClient) -> None:
    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(uuid.uuid4())},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json() == {
        "code": "portfolioNotFound",
        "message": "Portfolio not found for device.",
        "retry_after_seconds": None,
    }


def test_portfolio_data_returns_holdings(
    client: TestClient, db_session: Session
) -> None:
    device_uuid = uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="Main",
        monthly_budget=Decimal("1000"),
        ma_window=50,
        created_at=datetime.now(UTC),
    )
    portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="AAPL", weight=Decimal("0.5"))
    )
    db_session.add(portfolio)
    db_session.add(
        StockCache(
            ticker="AAPL",
            current_price=Decimal("150"),
            sma_50=Decimal("149"),
            sma_200=Decimal("148"),
            midline=Decimal("149.5"),
            atr=Decimal("2.5"),
            upper_band=Decimal("155.075"),
            lower_band=Decimal("143.925"),
            band_position=Decimal("0.5448430493273542600896860987"),
            last_modified=datetime.now(UTC),
            next_modified=None,
            job_status="success",
        )
    )
    db_session.commit()

    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "Main"
    assert isinstance(body["monthly_budget"], str)
    assert Decimal(body["monthly_budget"]) == Decimal("1000")
    assert body["ma_window"] == 50
    assert len(body["holdings"]) == 1
    h = body["holdings"][0]
    assert h["ticker"] == "AAPL"
    assert h["current_price"] == 150.0
    assert h["midline"] == 149.5
    assert h["atr"] == 2.5
    assert h["upper_band"] == 155.075
    assert h["lower_band"] == 143.925
    assert h["band_position"] == 0.5448430493


def test_portfolio_data_preserves_decimal_precision_in_monthly_budget(
    client: TestClient, db_session: Session
) -> None:
    """Sub-cent monthly_budget values must round-trip without IEEE-754 loss.

    Regression for #392: serialising via ``float()`` converted exact Postgres
    Numeric values into ``Double``, so $99.99 arrived on the wire as
    ``99.98999999999999488...``.
    """
    device_uuid = uuid.uuid4()
    db_session.add(
        Portfolio(
            id=uuid.uuid4(),
            device_uuid=device_uuid,
            name="Lossy",
            monthly_budget=Decimal("99.99"),
            ma_window=50,
            created_at=datetime.now(UTC),
        )
    )
    db_session.commit()

    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )

    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body["monthly_budget"], str)
    assert Decimal(body["monthly_budget"]) == Decimal("99.99")


def test_add_holding_returns_202_and_does_not_call_polygon_when_cached(
    client: TestClient, db_session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    device_uuid = uuid.uuid4()
    db_session.add(
        Portfolio(
            id=uuid.uuid4(),
            device_uuid=device_uuid,
            name="P",
            monthly_budget=Decimal("100"),
            ma_window=200,
            created_at=datetime.now(UTC),
        )
    )
    db_session.add(
        StockCache(
            ticker="MSFT",
            current_price=Decimal("400"),
            sma_50=Decimal("399"),
            sma_200=Decimal("398"),
            last_modified=datetime.now(UTC),
            next_modified=None,
            job_status="success",
        )
    )
    db_session.commit()

    called = {"polygon": 0}

    async def _fake_fetch(ticker):  # pragma: no cover
        called["polygon"] += 1

    monkeypatch.setattr("poller.polygon.fetch_and_cache_ticker", _fake_fetch)

    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(device_uuid), "ticker": "MSFT", "weight": 0.25},
        headers=ATTEST,
    )
    assert resp.status_code == 202
    # Cached ticker → background task must NOT have been queued.
    assert called["polygon"] == 0


def test_add_holding_rejects_duplicate_ticker(
    client: TestClient, db_session: Session
) -> None:
    device_uuid = uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="P",
        monthly_budget=Decimal("100"),
        ma_window=200,
        created_at=datetime.now(UTC),
    )
    portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="MSFT", weight=Decimal("0.25"))
    )
    db_session.add(portfolio)
    db_session.commit()

    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(device_uuid), "ticker": "MSFT", "weight": 0.25},
        headers=ATTEST,
    )

    assert resp.status_code == 409
    assert resp.json() == {
        "code": "conflictDetected",
        "message": "Holding already exists for portfolio.",
        "retry_after_seconds": None,
    }


def test_add_holding_404_for_unknown_device(client: TestClient) -> None:
    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(uuid.uuid4()), "ticker": "AAPL", "weight": 0.1},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json()["code"] == "portfolioNotFound"


def test_portfolio_data_stamps_last_seen_at_on_authenticated_touch(
    client: TestClient, db_session: Session
) -> None:
    """``GET /portfolio/data`` records activity for the retention sweep.

    The stamp is what keeps an active device's portfolio out of the
    daily purge documented in ``docs/legal/data-retention.md``.
    """
    device_uuid = uuid.uuid4()
    stale = datetime(2020, 1, 1, tzinfo=UTC)
    db_session.add(
        Portfolio(
            id=uuid.uuid4(),
            device_uuid=device_uuid,
            name="Touchable",
            monthly_budget=Decimal("123"),
            ma_window=50,
            created_at=stale,
            last_seen_at=stale,
        )
    )
    db_session.commit()

    before = datetime.now(UTC)
    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    after = datetime.now(UTC)
    assert resp.status_code == 200

    stamped = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == device_uuid)
    ).one()
    assert stamped.last_seen_at is not None
    # SQLite drops the timezone; compare in UTC-naive form so the
    # assertion passes on both SQLite and Postgres.
    stamped_naive = stamped.last_seen_at.replace(tzinfo=None)
    assert before.replace(tzinfo=None) <= stamped_naive <= after.replace(tzinfo=None)


def test_add_holding_stamps_last_seen_at_on_success(
    client: TestClient, db_session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    device_uuid = uuid.uuid4()
    stale = datetime(2020, 1, 1, tzinfo=UTC)
    db_session.add(
        Portfolio(
            id=uuid.uuid4(),
            device_uuid=device_uuid,
            name="P",
            monthly_budget=Decimal("100"),
            ma_window=200,
            created_at=stale,
            last_seen_at=stale,
        )
    )
    db_session.add(
        StockCache(
            ticker="MSFT",
            current_price=Decimal("400"),
            sma_50=Decimal("399"),
            sma_200=Decimal("398"),
            last_modified=datetime.now(UTC),
            next_modified=None,
            job_status="success",
        )
    )
    db_session.commit()

    before = datetime.now(UTC)
    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(device_uuid), "ticker": "MSFT", "weight": 0.25},
        headers=ATTEST,
    )
    after = datetime.now(UTC)
    assert resp.status_code == 202

    stamped = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == device_uuid)
    ).one()
    assert stamped.last_seen_at is not None
    stamped_naive = stamped.last_seen_at.replace(tzinfo=None)
    assert before.replace(tzinfo=None) <= stamped_naive <= after.replace(tzinfo=None)


def test_add_holding_duplicate_does_not_stamp_last_seen_at(
    client: TestClient, db_session: Session
) -> None:
    """A 409 conflict means no holding was added, so no activity stamp."""
    device_uuid = uuid.uuid4()
    stale = datetime(2020, 1, 1, tzinfo=UTC)
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="P",
        monthly_budget=Decimal("100"),
        ma_window=200,
        created_at=stale,
        last_seen_at=stale,
    )
    portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="MSFT", weight=Decimal("0.25"))
    )
    db_session.add(portfolio)
    db_session.commit()

    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": str(device_uuid), "ticker": "MSFT", "weight": 0.25},
        headers=ATTEST,
    )
    assert resp.status_code == 409

    untouched = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == device_uuid)
    ).one()
    # SQLite strips the timezone on round-trip; compare in naive UTC form.
    assert untouched.last_seen_at.replace(tzinfo=None) == stale.replace(
        tzinfo=None
    )


def test_portfolio_export_404_for_unknown_device(client: TestClient) -> None:
    resp = client.get(
        "/portfolio/export",
        params={"device_uuid": str(uuid.uuid4())},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json() == {
        "code": "portfolioNotFound",
        "message": "Portfolio not found for device.",
        "retry_after_seconds": None,
    }


def test_portfolio_export_returns_full_record(
    client: TestClient, db_session: Session
) -> None:
    """The export must contain every X-Device-UUID-linked column.

    Regression guard for issue #333: missing fields would silently
    short-change a GDPR Art. 20 / CCPA §1798.100 request.
    """
    device_uuid = uuid.uuid4()
    created_at = datetime(2024, 6, 1, 12, 0, 0, tzinfo=UTC)
    last_seen_at = datetime(2024, 12, 1, 12, 0, 0, tzinfo=UTC)
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="Long-term",
        monthly_budget=Decimal("250.50"),
        ma_window=200,
        created_at=created_at,
        last_seen_at=last_seen_at,
    )
    portfolio.holdings.extend(
        [
            Holding(id=uuid.uuid4(), ticker="VTI", weight=Decimal("0.6")),
            Holding(id=uuid.uuid4(), ticker="BND", weight=Decimal("0.4")),
        ]
    )
    db_session.add(portfolio)
    # Add a StockCache row that must NOT appear in the export — it is
    # ticker-keyed market data, not personal data.
    db_session.add(
        StockCache(
            ticker="VTI",
            current_price=Decimal("300"),
            sma_50=Decimal("299"),
            sma_200=Decimal("298"),
            last_modified=datetime.now(UTC),
            next_modified=None,
            job_status="success",
        )
    )
    db_session.commit()

    resp = client.get(
        "/portfolio/export",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 200
    body = resp.json()

    assert body["format_version"] == 1
    assert body["device_uuid"] == str(device_uuid)
    assert "generated_at" in body

    exported = body["portfolio"]
    assert exported["portfolio_id"] == str(portfolio.id)
    assert exported["name"] == "Long-term"
    assert isinstance(exported["monthly_budget"], str)
    assert Decimal(exported["monthly_budget"]) == Decimal("250.50")
    assert exported["ma_window"] == 200
    # Holdings come back in the same order they were appended.
    exported_holdings = {
        h["ticker"]: Decimal(h["weight"]) for h in exported["holdings"]
    }
    assert exported_holdings == {
        "VTI": Decimal("0.6"),
        "BND": Decimal("0.4"),
    }
    # Market-data fields must not leak into the personal-data export.
    for holding in exported["holdings"]:
        assert set(holding.keys()) == {"ticker", "weight"}


def test_portfolio_export_preserves_decimal_precision(
    client: TestClient, db_session: Session
) -> None:
    """Monetary and weight values must round-trip as exact decimal strings.

    Regression guard parallels
    test_portfolio_data_preserves_decimal_precision_in_monthly_budget
    (#392): an export that silently downgrades to IEEE-754 would fail
    the Art. 20 "structured, commonly used, machine-readable format"
    requirement because the recipient could not reconstruct the
    original values.
    """
    device_uuid = uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="Precise",
        monthly_budget=Decimal("99.99"),
        ma_window=50,
        created_at=datetime.now(UTC),
    )
    portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="AAPL", weight=Decimal("0.123456789"))
    )
    db_session.add(portfolio)
    db_session.commit()

    resp = client.get(
        "/portfolio/export",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 200
    body = resp.json()
    exported = body["portfolio"]

    assert isinstance(exported["monthly_budget"], str)
    assert Decimal(exported["monthly_budget"]) == Decimal("99.99")
    holding_weight = exported["holdings"][0]["weight"]
    assert isinstance(holding_weight, str)
    assert Decimal(holding_weight) == Decimal("0.123456789")


def test_portfolio_export_stamps_last_seen_at_on_authenticated_touch(
    client: TestClient, db_session: Session
) -> None:
    """``GET /portfolio/export`` records activity for the retention sweep.

    Pairs with test_portfolio_data_stamps_last_seen_at_on_authenticated_touch:
    a data-subject exercising the export right keeps their portfolio out
    of the daily purge documented in ``docs/legal/data-retention.md``.
    """
    device_uuid = uuid.uuid4()
    stale = datetime(2020, 1, 1, tzinfo=UTC)
    db_session.add(
        Portfolio(
            id=uuid.uuid4(),
            device_uuid=device_uuid,
            name="Stale",
            monthly_budget=Decimal("100"),
            ma_window=50,
            created_at=stale,
            last_seen_at=stale,
        )
    )
    db_session.commit()

    before = datetime.now(UTC)
    resp = client.get(
        "/portfolio/export",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    after = datetime.now(UTC)
    assert resp.status_code == 200

    stamped = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == device_uuid)
    ).one()
    assert stamped.last_seen_at is not None
    stamped_naive = stamped.last_seen_at.replace(tzinfo=None)
    assert before.replace(tzinfo=None) <= stamped_naive <= after.replace(tzinfo=None)


def test_portfolio_export_omits_other_devices(
    client: TestClient, db_session: Session
) -> None:
    """Export must scope strictly to the calling device's portfolio.

    Cross-device leakage in a DSR endpoint would be a per-row personal-data
    breach under GDPR Art. 33/34; this guards the scoping invariant.
    """
    caller_uuid = uuid.uuid4()
    other_uuid = uuid.uuid4()
    caller_portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=caller_uuid,
        name="Mine",
        monthly_budget=Decimal("100"),
        ma_window=50,
        created_at=datetime.now(UTC),
    )
    caller_portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="VOO", weight=Decimal("1.0"))
    )
    other_portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=other_uuid,
        name="Theirs",
        monthly_budget=Decimal("999"),
        ma_window=200,
        created_at=datetime.now(UTC),
    )
    other_portfolio.holdings.append(
        Holding(id=uuid.uuid4(), ticker="SECRET", weight=Decimal("0.99"))
    )
    db_session.add_all([caller_portfolio, other_portfolio])
    db_session.commit()

    resp = client.get(
        "/portfolio/export",
        params={"device_uuid": str(caller_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 200
    body = resp.json()

    assert body["device_uuid"] == str(caller_uuid)
    assert body["portfolio"]["name"] == "Mine"
    tickers = {h["ticker"] for h in body["portfolio"]["holdings"]}
    assert tickers == {"VOO"}
    assert "SECRET" not in tickers

