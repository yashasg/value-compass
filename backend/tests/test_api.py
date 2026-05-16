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
    # Liveness probes must never be cached — a transient OK that gets
    # cached as a 200 by URLCache or Cloudflare would mask a subsequent
    # outage (issue #416).
    assert resp.headers["Cache-Control"] == "no-store"
    assert "Last-Modified" not in resp.headers
    assert "X-Min-App-Version" in resp.headers


def test_health_503_emits_retry_after_and_no_store() -> None:
    """A 503 from /health emits Retry-After: 60 + Cache-Control: no-store.

    Regression guard for issue #416. The previous blanket
    ``Cache-Control: max-age=3600`` would let URLCache.shared and
    Cloudflare re-serve the cached 503 envelope for an hour even though
    the body's ``retry_after_seconds=60`` told clients to retry in one
    minute. The 503 path now sets ``no-store`` and mirrors the body
    field onto the RFC 7231 §7.1.3 ``Retry-After`` header.
    """
    from sqlalchemy.exc import OperationalError

    def _broken_db():
        class _BrokenSession:
            def execute(self, *_args, **_kwargs):  # noqa: ANN001
                raise OperationalError("SELECT 1", {}, Exception("db down"))

        yield _BrokenSession()

    app.dependency_overrides[get_db] = _broken_db
    try:
        resp = TestClient(app).get("/health")
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 503
    assert resp.headers["Cache-Control"] == "no-store"
    assert resp.headers["Retry-After"] == "60"
    assert "Last-Modified" not in resp.headers


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


def test_no_operation_advertises_fastapi_validation_error(client: TestClient) -> None:
    """Issue #302: every 422 must be ErrorEnvelope, never HTTPValidationError.

    The global ``validation_error_handler`` returns the public
    :class:`ErrorEnvelope`, so any operation advertising FastAPI's default
    ``HTTPValidationError`` body would let generated clients model a payload
    they will never receive. Specifically guards ``GET /schema/version`` and
    ``GET /portfolio/status``, which historically inherited the FastAPI
    default and silently drifted from every other protected route.
    """
    schema = client.get("/openapi.json").json()

    legacy_schemas = ("HTTPValidationError", "ValidationError")
    components = schema.get("components", {}).get("schemas", {})
    for legacy in legacy_schemas:
        assert legacy not in components, (
            f"Legacy validation schema {legacy!r} must be pruned from "
            "components.schemas; declare 422 responses with ErrorEnvelope."
        )

    envelope_ref = "#/components/schemas/ErrorEnvelope"
    for path, operations in schema["paths"].items():
        for method, operation in operations.items():
            if not isinstance(operation, dict):
                continue
            response_422 = operation.get("responses", {}).get("422")
            if response_422 is None:
                continue
            response_schema = (
                response_422.get("content", {})
                .get("application/json", {})
                .get("schema", {})
            )
            assert response_schema.get("$ref") == envelope_ref, (
                f"{method.upper()} {path}: 422 must reference ErrorEnvelope, "
                f"got {response_schema!r}"
            )

    # Concrete regression pins for the two routes that drifted (issue #302).
    for path in ("/schema/version", "/portfolio/status"):
        ref = schema["paths"][path]["get"]["responses"]["422"]["content"][
            "application/json"
        ]["schema"]["$ref"]
        assert ref == envelope_ref


def test_holding_weight_range_constraint_is_symmetric(client: TestClient) -> None:
    """Issue #461: every surface touching ``Holding.weight`` advertises 0 < w ≤ 1.

    The runtime invariant is enforced on POST /portfolio/holdings (where
    ``weight: float`` carries ``Field(gt=0, le=1)``) and on PATCH
    /portfolio/holdings/{ticker} (where ``weight: DecimalString`` carries
    the same ``Field`` metadata). ``DecimalString``'s ``WithJsonSchema``
    override silently stripped the PATCH bound from the wire spec.
    ``custom_openapi()`` re-merges the bounds; assert the three surfaces
    agree so a future ``WithJsonSchema`` regression fails contract tests.
    """
    schema = client.get("/openapi.json").json()
    components = schema["components"]["schemas"]

    add_weight = components["AddHoldingRequest"]["properties"]["weight"]
    patch_weight = components["PatchHoldingRequest"]["properties"]["weight"]

    # POST writes ``float``; PATCH writes ``DecimalString`` (``string`` /
    # ``format: decimal``). Both must advertise the same numeric range.
    assert add_weight["exclusiveMinimum"] == 0
    assert add_weight["maximum"] == 1
    assert patch_weight["exclusiveMinimum"] == 0
    assert patch_weight["maximum"] == 1
    assert patch_weight["type"] == "string"
    assert patch_weight["format"] == "decimal"


def test_portfolio_monthly_budget_lower_bound_is_advertised(
    client: TestClient,
) -> None:
    """Issue #461: PATCH /portfolio.monthly_budget advertises ``> 0``.

    ``PatchPortfolioRequest.monthly_budget`` is the nullable variant of
    the ``DecimalString`` alias. The bound must land on the non-null
    branch of ``anyOf`` so clients applying schema validators reject
    ``"0"`` / negative values pre-flight rather than on the round-trip.
    """
    schema = client.get("/openapi.json").json()
    monthly_budget = schema["components"]["schemas"][
        "PatchPortfolioRequest"
    ]["properties"]["monthly_budget"]

    decimal_branches = [
        option
        for option in monthly_budget["anyOf"]
        if option.get("type") == "string"
        and option.get("format") == "decimal"
    ]
    assert len(decimal_branches) == 1
    assert decimal_branches[0]["exclusiveMinimum"] == 0


def test_decimal_string_bounds_runtime_enforced(client: TestClient) -> None:
    """Issue #461: runtime keeps rejecting out-of-range DecimalString values.

    The spec re-advertises the bounds but the Pydantic validators were
    never touched. PATCH /portfolio/holdings/{ticker} with ``weight=0``
    or ``weight=1.5`` must still 422 with ``schemaUnsupported`` so the
    contract correction does not become decorative.
    """
    for invalid_weight in ("0", "1.5", "-0.1"):
        response = client.patch(
            "/portfolio/holdings/AAPL",
            params={"device_uuid": str(uuid.uuid4())},
            headers=ATTEST,
            json={"weight": invalid_weight},
        )
        assert response.status_code == 422
        assert response.json()["code"] == "schemaUnsupported"

    for invalid_budget in ("0", "-1.00"):
        response = client.patch(
            "/portfolio",
            params={"device_uuid": str(uuid.uuid4())},
            headers=ATTEST,
            json={"monthly_budget": invalid_budget},
        )
        assert response.status_code == 422
        assert response.json()["code"] == "schemaUnsupported"


PROTECTED_OPERATIONS: tuple[tuple[str, str], ...] = (
    ("/schema/version", "get"),
    ("/portfolio/status", "get"),
    ("/portfolio/data", "get"),
    ("/portfolio/export", "get"),
    ("/portfolio", "patch"),
    ("/portfolio", "delete"),
    ("/portfolio/holdings", "post"),
    ("/portfolio/holdings/{ticker}", "patch"),
    ("/portfolio/holdings/{ticker}", "delete"),
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
        ("patch", "/portfolio", {"device_uuid": str(uuid.uuid4())}),
        ("delete", "/portfolio", {"device_uuid": str(uuid.uuid4())}),
        (
            "post",
            "/portfolio/holdings",
            None,
        ),
        (
            "patch",
            "/portfolio/holdings/AAPL",
            {"device_uuid": str(uuid.uuid4())},
        ),
        (
            "delete",
            "/portfolio/holdings/AAPL",
            {"device_uuid": str(uuid.uuid4())},
        ),
    )

    for method, path, params in requests:
        if method == "get":
            response = client.get(path, params=params)
        elif method == "post":
            response = client.post(
                path,
                params=params,
                json={"device_uuid": str(uuid.uuid4()), "ticker": "AAPL"},
            )
        elif method == "patch":
            response = client.patch(path, params=params, json={"name": "X"})
        else:
            response = client.delete(path, params=params)
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


def test_portfolio_status_db_unreachable_returns_sync_unavailable() -> None:
    """A failing DB session surfaces the documented 503 envelope.

    Regression guard for issue #439: ``/portfolio/status`` previously
    leaked an undocumented FastAPI 500 body when ``db.execute`` raised
    a ``SQLAlchemyError``, asymmetric vs ``/portfolio/data``,
    ``/health``, and ``/portfolio/holdings``. The 503 path now matches
    the documented ``syncUnavailable`` envelope with
    ``retry_after_seconds=60``.
    """
    from sqlalchemy.exc import OperationalError

    def _broken_db():
        class _BrokenSession:
            def execute(self, *_args, **_kwargs):  # noqa: ANN001
                raise OperationalError("SELECT 1", {}, Exception("db down"))

        yield _BrokenSession()

    app.dependency_overrides[get_db] = _broken_db
    try:
        resp = TestClient(app).get("/portfolio/status", headers=ATTEST)
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 503
    assert resp.json() == {
        "code": "syncUnavailable",
        "message": "Database is unreachable.",
        "retry_after_seconds": 60,
    }


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


def test_add_holding_202_success_is_empty_body_in_spec_and_runtime(
    client: TestClient, db_session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Issue #303: POST /portfolio/holdings 202 must be empty on both sides.

    The route returns ``Response(status_code=202)`` with no JSON payload, so
    the published OpenAPI contract must not advertise ``application/json``
    content for the 202 success — otherwise generated clients model a body
    the server never sends. ``response_class=Response`` on the decorator
    drives the spec side; this test pins both halves so a future re-add
    of a JSON success body (decorator or runtime) fails contract tests.
    """
    schema = client.get("/openapi.json").json()
    success = schema["paths"]["/portfolio/holdings"]["post"]["responses"]["202"]
    assert "content" not in success, (
        "POST /portfolio/holdings 202 advertises a body but the runtime "
        "returns an empty Response — keep the contract empty (or add a "
        "body to the route, but not just to the spec)."
    )

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
            ticker="AAPL",
            current_price=Decimal("190"),
            sma_50=Decimal("189"),
            sma_200=Decimal("188"),
            last_modified=datetime.now(UTC),
            next_modified=None,
            job_status="success",
        )
    )
    db_session.commit()

    async def _fake_fetch(ticker):  # pragma: no cover - cached path
        return None

    monkeypatch.setattr("poller.polygon.fetch_and_cache_ticker", _fake_fetch)

    resp = client.post(
        "/portfolio/holdings",
        json={
            "device_uuid": str(device_uuid),
            "ticker": "AAPL",
            "weight": 0.5,
        },
        headers=ATTEST,
    )
    assert resp.status_code == 202
    assert resp.content == b"", (
        "POST /portfolio/holdings 202 runtime body drifted from the empty "
        "contract — either update the spec to advertise the new body, or "
        "drop the body from the route."
    )


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


def test_portfolio_export_response_marks_format_version_required(
    client: TestClient,
) -> None:
    """``format_version`` must be declared required in the OpenAPI schema.

    Regression guard for issue #463: ``format_version`` carries a
    Pydantic default which Pydantic v2 silently drops from the
    auto-generated ``required`` list, even though the server always
    emits the field. The fix at
    :class:`PortfolioExportResponse.model_config` promotes it back into
    ``required`` via ``json_schema_extra`` (same #381 pattern previously
    applied to :class:`HealthResponse`).

    Without this guard, generated iOS clients would decode
    ``format_version`` as ``Int?`` and silently collapse "absent" with
    "default 1" — defeating the field's purpose as the forward-
    compatibility lever for the GDPR Art. 20 export envelope.
    """
    schema = client.get("/openapi.json").json()
    export_schema = schema["components"]["schemas"]["PortfolioExportResponse"]

    required = export_schema.get("required", [])
    assert "format_version" in required, (
        "PortfolioExportResponse.format_version must appear in the "
        "schema's `required` array so generated clients decode it as "
        "non-optional (issue #463)."
    )
    # The pre-existing required fields must remain required — guards
    # against accidental regressions where `json_schema_extra` overrides
    # rather than extends the auto-generated list.
    for field in ("generated_at", "device_uuid", "portfolio"):
        assert field in required, (
            f"PortfolioExportResponse.{field} must remain required."
        )

    # The field schema itself must still describe a constrained integer
    # so a future format-N bump cannot silently land as a non-integer.
    format_version_schema = export_schema["properties"]["format_version"]
    assert format_version_schema["type"] == "integer"
    assert format_version_schema["default"] == 1
    assert format_version_schema["minimum"] == 1


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


def test_portfolio_export_emits_audit_log_on_success(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """A successful export must leave a structured ``vca.api`` audit trail.

    GDPR Art. 5(2) (accountability) + CCPA Regulations 11 CCR §7102(a)
    (24-month records-of-requests) require the controller to be able to
    demonstrate, on inspection, that a data-portability request was
    honored. The export handler emits a single structured INFO line on
    the success path so journald carries the proof (issue #445).

    Field shape is locked in here so the same surface can be reused by
    the sibling write-side endpoints under #457 without a second
    contract negotiation.
    """
    device_uuid = uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="Audited",
        monthly_budget=Decimal("100"),
        ma_window=50,
        created_at=datetime.now(UTC),
    )
    portfolio.holdings.extend(
        [
            Holding(id=uuid.uuid4(), ticker="VTI", weight=Decimal("0.5")),
            Holding(id=uuid.uuid4(), ticker="BND", weight=Decimal("0.5")),
        ]
    )
    db_session.add(portfolio)
    db_session.commit()

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.get(
            "/portfolio/export",
            params={"device_uuid": str(device_uuid)},
            headers=ATTEST,
        )
    assert resp.status_code == 200

    audit_records = [
        record
        for record in caplog.records
        if record.name == "vca.api"
        and "event=dsr.export.portfolio" in record.getMessage()
    ]
    assert len(audit_records) == 1, (
        "Exactly one dsr.export.portfolio audit line must be emitted on "
        "the 200 success path (GDPR Art. 5(2) accountability)."
    )
    message = audit_records[0].getMessage()
    assert f"device_uuid_suffix=…{str(device_uuid)[-4:]}" in message
    assert f"portfolio_id={portfolio.id}" in message
    assert "holdings_count=2" in message


def test_portfolio_export_audit_log_redacts_device_uuid(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """The audit line must never quote the raw ``X-Device-UUID``.

    The 30-day journald retention floor in
    ``docs/legal/data-retention.md`` (Application logs row) is sized
    against a redacted-suffix surface only; logging the raw UUID would
    re-open the surface closed by the apns.py ``_redact`` precedent and
    the issue #339 redaction floor. Regression guard for issue #445.
    """
    device_uuid = uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name="Redacted",
        monthly_budget=Decimal("100"),
        ma_window=50,
        created_at=datetime.now(UTC),
    )
    db_session.add(portfolio)
    db_session.commit()

    raw_uuid = str(device_uuid)
    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.get(
            "/portfolio/export",
            params={"device_uuid": raw_uuid},
            headers=ATTEST,
        )
    assert resp.status_code == 200

    for record in caplog.records:
        if record.name != "vca.api":
            continue
        assert raw_uuid not in record.getMessage(), (
            "Raw device_uuid must not appear in any vca.api log line "
            "(see docs/legal/data-retention.md Application logs row)."
        )


def test_portfolio_export_does_not_emit_audit_log_on_404(
    client: TestClient,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """A 404 export must not stamp the accountability log.

    The audit surface is the ``records-of-requests-honored`` trail; a
    request that 404s was *not* honored (no rows changed hands), so an
    audit line would mislead the CCPA §7102(a) inspector. Regression
    guard for issue #445.
    """
    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.get(
            "/portfolio/export",
            params={"device_uuid": str(uuid.uuid4())},
            headers=ATTEST,
        )
    assert resp.status_code == 404

    audit_records = [
        record
        for record in caplog.records
        if record.name == "vca.api"
        and "event=dsr.export.portfolio" in record.getMessage()
    ]
    assert audit_records == [], (
        "No dsr.export.portfolio audit line should be emitted on a 404 "
        "— the request was not honored."
    )


# ---------------------------------------------------------------------------
# GDPR Art. 16 / CCPA §1798.106 right-to-rectification — issue #374
# ---------------------------------------------------------------------------
def _seed_portfolio(
    db_session: Session,
    *,
    device_uuid: uuid.UUID | None = None,
    name: str = "Main",
    monthly_budget: Decimal = Decimal("100"),
    ma_window: int = 50,
    holdings: tuple[tuple[str, Decimal], ...] = (),
    last_seen_at: datetime | None = None,
) -> tuple[uuid.UUID, Portfolio]:
    """Insert a Portfolio (+ optional holdings) and return ids for assertions."""
    device_uuid = device_uuid or uuid.uuid4()
    portfolio = Portfolio(
        id=uuid.uuid4(),
        device_uuid=device_uuid,
        name=name,
        monthly_budget=monthly_budget,
        ma_window=ma_window,
        created_at=datetime.now(UTC),
        last_seen_at=last_seen_at,
    )
    for ticker, weight in holdings:
        portfolio.holdings.append(
            Holding(id=uuid.uuid4(), ticker=ticker, weight=weight)
        )
    db_session.add(portfolio)
    db_session.commit()
    return device_uuid, portfolio


def test_patch_portfolio_404_for_unknown_device(client: TestClient) -> None:
    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(uuid.uuid4())},
        json={"name": "Renamed"},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json() == {
        "code": "portfolioNotFound",
        "message": "Portfolio not found for device.",
        "retry_after_seconds": None,
    }


def test_patch_portfolio_rejects_empty_body(
    client: TestClient, db_session: Session
) -> None:
    """An empty PATCH body would no-op but still stamp activity — reject it."""
    device_uuid, _ = _seed_portfolio(db_session)

    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        json={},
        headers=ATTEST,
    )
    assert resp.status_code == 422
    body = resp.json()
    assert body["code"] == "schemaUnsupported"


def test_patch_portfolio_rejects_unsupported_ma_window(
    client: TestClient, db_session: Session
) -> None:
    """Disallowed ma_window emits the unsupportedMovingAverageWindow envelope.

    The CheckConstraint on ``Portfolio.ma_window`` already rejects values
    outside ``(50, 200)`` at the database; this assertion locks in the
    earlier, more-specific error envelope so the iOS client can surface
    a precise message rather than the generic ``schemaUnsupported``.
    """
    device_uuid, _ = _seed_portfolio(db_session)

    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        json={"ma_window": 99},
        headers=ATTEST,
    )
    assert resp.status_code == 422
    assert resp.json()["code"] == "unsupportedMovingAverageWindow"


def test_patch_portfolio_updates_name_only(
    client: TestClient, db_session: Session
) -> None:
    device_uuid, portfolio = _seed_portfolio(
        db_session, name="Old", monthly_budget=Decimal("100"), ma_window=50
    )

    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        json={"name": "New"},
        headers=ATTEST,
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["portfolio_id"] == str(portfolio.id)
    assert body["name"] == "New"
    assert Decimal(body["monthly_budget"]) == Decimal("100")
    assert body["ma_window"] == 50
    # Sibling fields must not have changed.
    refreshed = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == device_uuid)
    ).one()
    assert refreshed.name == "New"
    assert refreshed.monthly_budget == Decimal("100")
    assert refreshed.ma_window == 50


def test_patch_portfolio_updates_all_scalar_fields(
    client: TestClient, db_session: Session
) -> None:
    device_uuid, portfolio = _seed_portfolio(
        db_session, name="Old", monthly_budget=Decimal("100"), ma_window=50
    )

    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        json={"name": "New", "monthly_budget": "250.50", "ma_window": 200},
        headers=ATTEST,
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "New"
    assert Decimal(body["monthly_budget"]) == Decimal("250.50")
    assert body["ma_window"] == 200
    assert body["portfolio_id"] == str(portfolio.id)


def test_patch_portfolio_preserves_decimal_precision(
    client: TestClient, db_session: Session
) -> None:
    """Rectified monthly_budget round-trips without IEEE-754 loss.

    Pairs with test_portfolio_data_preserves_decimal_precision_in_monthly_budget
    (#392) — Art. 16 corrections must persist exact values, not lossy
    Doubles, or the next ``GET /portfolio/data`` would silently
    re-introduce the drift the user just tried to correct.
    """
    device_uuid, _ = _seed_portfolio(db_session)

    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        json={"monthly_budget": "99.99"},
        headers=ATTEST,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body["monthly_budget"], str)
    assert Decimal(body["monthly_budget"]) == Decimal("99.99")

    refreshed = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == device_uuid)
    ).one()
    assert refreshed.monthly_budget == Decimal("99.99")


def test_patch_portfolio_stamps_last_seen_at_on_success(
    client: TestClient, db_session: Session
) -> None:
    """Successful rectification stamps activity for the retention sweep."""
    stale = datetime(2020, 1, 1, tzinfo=UTC)
    device_uuid, _ = _seed_portfolio(db_session, last_seen_at=stale)

    before = datetime.now(UTC)
    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        json={"name": "Touched"},
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


def test_patch_portfolio_does_not_modify_other_devices(
    client: TestClient, db_session: Session
) -> None:
    """Cross-device scoping: PATCH is invisible to other portfolios."""
    caller_uuid, _ = _seed_portfolio(db_session, name="Mine", ma_window=50)
    other_uuid, other_portfolio = _seed_portfolio(
        db_session, name="Theirs", ma_window=200
    )

    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(caller_uuid)},
        json={"name": "MineRenamed", "ma_window": 200},
        headers=ATTEST,
    )
    assert resp.status_code == 200

    other = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == other_uuid)
    ).one()
    assert other.name == "Theirs"
    assert other.ma_window == 200
    assert other.id == other_portfolio.id


def test_patch_holding_404_for_unknown_device(client: TestClient) -> None:
    resp = client.patch(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": str(uuid.uuid4())},
        json={"weight": "0.5"},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json()["code"] == "portfolioNotFound"


def test_patch_holding_404_for_unknown_ticker(
    client: TestClient, db_session: Session
) -> None:
    """404 when the holding row does not exist on the resolved portfolio.

    Returns the dedicated ``holdingNotFound`` envelope so iOS clients can
    dispatch on ``code`` alone — distinct from ``portfolioNotFound``,
    which the same surface emits when the parent portfolio is missing.
    """
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )

    resp = client.patch(
        "/portfolio/holdings/MSFT",
        params={"device_uuid": str(device_uuid)},
        json={"weight": "0.5"},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    body = resp.json()
    assert body["code"] == "holdingNotFound"
    assert body["message"] == "Holding not found for portfolio."


def test_patch_holding_rejects_out_of_range_weight(
    client: TestClient, db_session: Session
) -> None:
    """Weight must be in (0, 1]; the validator surfaces the standard envelope."""
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )

    for invalid in ("0", "1.5", "-0.1"):
        resp = client.patch(
            "/portfolio/holdings/AAPL",
            params={"device_uuid": str(device_uuid)},
            json={"weight": invalid},
            headers=ATTEST,
        )
        assert resp.status_code == 422, invalid
        assert resp.json()["code"] == "schemaUnsupported"


def test_patch_holding_returns_updated_weight(
    client: TestClient, db_session: Session
) -> None:
    device_uuid, portfolio = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")), ("MSFT", Decimal("0.5")))
    )

    resp = client.patch(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": str(device_uuid)},
        json={"weight": "0.6"},
        headers=ATTEST,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["ticker"] == "AAPL"
    assert Decimal(body["weight"]) == Decimal("0.6")

    # Sibling holding's weight must remain untouched.
    untouched = db_session.scalars(
        select(Holding).where(
            Holding.portfolio_id == portfolio.id, Holding.ticker == "MSFT"
        )
    ).one()
    assert untouched.weight == Decimal("0.5")


def test_patch_holding_preserves_decimal_precision(
    client: TestClient, db_session: Session
) -> None:
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )

    resp = client.patch(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": str(device_uuid)},
        json={"weight": "0.123456789"},
        headers=ATTEST,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body["weight"], str)
    assert Decimal(body["weight"]) == Decimal("0.123456789")


def test_patch_holding_stamps_last_seen_at(
    client: TestClient, db_session: Session
) -> None:
    stale = datetime(2020, 1, 1, tzinfo=UTC)
    device_uuid, _ = _seed_portfolio(
        db_session,
        holdings=(("AAPL", Decimal("0.5")),),
        last_seen_at=stale,
    )

    before = datetime.now(UTC)
    resp = client.patch(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": str(device_uuid)},
        json={"weight": "0.7"},
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


def test_patch_holding_does_not_touch_other_devices(
    client: TestClient, db_session: Session
) -> None:
    """A PATCH scoped to one device cannot mutate a same-ticker row elsewhere."""
    caller_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )
    other_uuid, other_portfolio = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.25")),)
    )

    resp = client.patch(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": str(caller_uuid)},
        json={"weight": "0.9"},
        headers=ATTEST,
    )
    assert resp.status_code == 200

    other_holding = db_session.scalars(
        select(Holding).where(
            Holding.portfolio_id == other_portfolio.id,
            Holding.ticker == "AAPL",
        )
    ).one()
    assert other_holding.weight == Decimal("0.25")


def test_delete_holding_404_for_unknown_device(client: TestClient) -> None:
    resp = client.delete(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": str(uuid.uuid4())},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json()["code"] == "portfolioNotFound"


def test_delete_holding_404_for_unknown_ticker(
    client: TestClient, db_session: Session
) -> None:
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )

    resp = client.delete(
        "/portfolio/holdings/MSFT",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    body = resp.json()
    assert body["code"] == "holdingNotFound"
    assert body["message"] == "Holding not found for portfolio."


def test_delete_holding_removes_only_the_target_row(
    client: TestClient, db_session: Session
) -> None:
    """DELETE removes exactly one holding and leaves siblings + portfolio intact.

    Reinforces the issue-#374 separation between row-level rectification
    (this DELETE) and the full-account erasure path tracked in issue
    #329. A regression that cascade-deletes the parent portfolio would
    be a privacy-significant data-loss bug.
    """
    device_uuid, portfolio = _seed_portfolio(
        db_session,
        holdings=(
            ("AAPL", Decimal("0.3")),
            ("MSFT", Decimal("0.4")),
            ("VOO", Decimal("0.3")),
        ),
    )

    resp = client.delete(
        "/portfolio/holdings/MSFT",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 204
    assert resp.content == b""

    surviving = {
        h.ticker
        for h in db_session.scalars(
            select(Holding).where(Holding.portfolio_id == portfolio.id)
        )
    }
    assert surviving == {"AAPL", "VOO"}

    # The portfolio row itself MUST still exist — DELETE on a holding
    # is row-scoped, not account-scoped (#374 vs #329).
    refreshed = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == device_uuid)
    ).one()
    assert refreshed.id == portfolio.id


def test_delete_holding_stamps_last_seen_at(
    client: TestClient, db_session: Session
) -> None:
    stale = datetime(2020, 1, 1, tzinfo=UTC)
    device_uuid, _ = _seed_portfolio(
        db_session,
        holdings=(("AAPL", Decimal("0.5")), ("MSFT", Decimal("0.5"))),
        last_seen_at=stale,
    )

    before = datetime.now(UTC)
    resp = client.delete(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    after = datetime.now(UTC)
    assert resp.status_code == 204

    stamped = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == device_uuid)
    ).one()
    assert stamped.last_seen_at is not None
    stamped_naive = stamped.last_seen_at.replace(tzinfo=None)
    assert before.replace(tzinfo=None) <= stamped_naive <= after.replace(tzinfo=None)


def test_delete_holding_does_not_touch_other_devices(
    client: TestClient, db_session: Session
) -> None:
    caller_uuid, caller_portfolio = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )
    other_uuid, other_portfolio = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.25")),)
    )

    resp = client.delete(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": str(caller_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 204

    # Caller's holding removed; other device's same-ticker row untouched.
    assert (
        db_session.scalars(
            select(Holding).where(Holding.portfolio_id == caller_portfolio.id)
        ).first()
        is None
    )
    other_row = db_session.scalars(
        select(Holding).where(Holding.portfolio_id == other_portfolio.id)
    ).one()
    assert other_row.ticker == "AAPL"
    assert other_row.weight == Decimal("0.25")


# ---------------------------------------------------------------------------
# GDPR Art. 17 / CCPA §1798.105 right-to-erasure (full account) — issue #450
# ---------------------------------------------------------------------------
def test_delete_portfolio_404_for_unknown_device(client: TestClient) -> None:
    resp = client.delete(
        "/portfolio",
        params={"device_uuid": str(uuid.uuid4())},
        headers=ATTEST,
    )
    assert resp.status_code == 404
    assert resp.json() == {
        "code": "portfolioNotFound",
        "message": "Portfolio not found for device.",
        "retry_after_seconds": None,
    }


def test_delete_portfolio_erases_portfolio_and_cascades_to_holdings(
    client: TestClient, db_session: Session
) -> None:
    """Successful erasure removes the Portfolio AND every Holding keyed to it.

    Validates the model-side ``cascade="all, delete-orphan"`` on
    ``Portfolio.holdings`` and the ``ondelete="CASCADE"`` on
    ``Holding.portfolio_id`` — the privacy contract requires that
    "delete my data" leaves zero ``X-Device-UUID``-linked rows behind.
    """
    device_uuid, portfolio = _seed_portfolio(
        db_session,
        holdings=(
            ("AAPL", Decimal("0.3")),
            ("MSFT", Decimal("0.4")),
            ("VOO", Decimal("0.3")),
        ),
    )
    portfolio_id = portfolio.id

    resp = client.delete(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 204
    assert resp.content == b""

    db_session.expire_all()
    assert (
        db_session.scalars(
            select(Portfolio).where(Portfolio.device_uuid == device_uuid)
        ).first()
        is None
    )
    assert (
        db_session.scalars(
            select(Holding).where(Holding.portfolio_id == portfolio_id)
        ).first()
        is None
    )


def test_delete_portfolio_does_not_touch_other_devices(
    client: TestClient, db_session: Session
) -> None:
    """Cross-device scoping: an account erasure cannot reach foreign rows.

    Mirrors the row-scoped DELETE guard (#374) at the account level so
    a regression that drops the ``where(device_uuid == ...)`` filter
    fails immediately.
    """
    caller_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )
    other_uuid, other_portfolio = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.25")),)
    )

    resp = client.delete(
        "/portfolio",
        params={"device_uuid": str(caller_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 204

    surviving_portfolio = db_session.scalars(
        select(Portfolio).where(Portfolio.device_uuid == other_uuid)
    ).one()
    assert surviving_portfolio.id == other_portfolio.id
    surviving_holding = db_session.scalars(
        select(Holding).where(Holding.portfolio_id == other_portfolio.id)
    ).one()
    assert surviving_holding.ticker == "AAPL"
    assert surviving_holding.weight == Decimal("0.25")


def test_delete_portfolio_does_not_stamp_activity_on_a_doomed_row(
    client: TestClient, db_session: Session
) -> None:
    """Erasure must not stamp ``last_seen_at`` on a row that is being deleted.

    Every other authenticated touch stamps activity so the
    retention-purge sweep (``docs/legal/data-retention.md``) keeps live
    rows alive. Erasure is the deliberate exception — the row is gone,
    so a stamp would either no-op (if it runs first) or resurrect a
    freshly-deleted row. Locks in the intentional asymmetry so a
    regression that pastes ``portfolio.last_seen_at = datetime.now(UTC)``
    into the erasure handler fails immediately.
    """
    stale = datetime(2020, 1, 1, tzinfo=UTC)
    device_uuid, _ = _seed_portfolio(
        db_session,
        holdings=(("AAPL", Decimal("0.5")),),
        last_seen_at=stale,
    )

    resp = client.delete(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )
    assert resp.status_code == 204

    db_session.expire_all()
    assert (
        db_session.scalars(
            select(Portfolio).where(Portfolio.device_uuid == device_uuid)
        ).first()
        is None
    )


def test_delete_portfolio_documented_in_openapi(client: TestClient) -> None:
    """The OpenAPI artifact must advertise the new operation under #450.

    Locks in the operation's existence (a regression that drops the
    handler is caught by the missing path), the 204 success contract,
    the four documented error envelopes, and the App Attest gate so
    generated iOS clients can't accidentally call the endpoint without
    the required header.
    """
    schema = client.get("/openapi.json").json()
    operation = schema["paths"]["/portfolio"]["delete"]

    assert "204" in operation["responses"]
    assert "401" in operation["responses"]
    assert "404" in operation["responses"]
    assert "422" in operation["responses"]
    assert "503" in operation["responses"]

    parameter = _x_app_attest_parameter(operation)
    assert parameter["required"] is True


# ---------------------------------------------------------------------------
# DSR write-side audit log (issue #457) — GDPR Art. 5(2) accountability +
# CCPA Regulations 11 CCR §7102(a) records-of-requests-honored for the
# four PATCH/DELETE handlers (write-side counterpart to the
# `GET /portfolio/export` audit-log surface in #445).
#
# Each handler ships with three regression guards mirroring the export
# surface so the shared ``redact_device_uuid`` floor and the
# "honored-requests only" boundary stay locked in:
#
#   1. on-success emission with the structured field set
#   2. redaction floor (raw UUID never lands in a ``vca.api`` record)
#   3. 404 / failure path emits no audit line
#
# Field shape parity with ``dsr.export.portfolio`` is intentional so a
# single grep (``event=dsr.``) yields the entire records-of-requests
# surface for a journald window.
# ---------------------------------------------------------------------------
def _audit_records_for(
    caplog: pytest.LogCaptureFixture, event: str
) -> list[str]:
    """Return ``vca.api`` log messages matching a structured DSR event."""
    return [
        record.getMessage()
        for record in caplog.records
        if record.name == "vca.api"
        and f"event={event}" in record.getMessage()
    ]


def test_patch_portfolio_emits_audit_log_on_success(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """Successful rectification emits ``event=dsr.rectification.portfolio``."""
    device_uuid, portfolio = _seed_portfolio(
        db_session, name="Old", monthly_budget=Decimal("100"), ma_window=50
    )

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.patch(
            "/portfolio",
            params={"device_uuid": str(device_uuid)},
            json={"name": "New", "ma_window": 200},
            headers=ATTEST,
        )
    assert resp.status_code == 200

    messages = _audit_records_for(caplog, "dsr.rectification.portfolio")
    assert len(messages) == 1, (
        "Exactly one dsr.rectification.portfolio audit line must be "
        "emitted on the 200 success path (GDPR Art. 5(2) accountability)."
    )
    message = messages[0]
    assert f"device_uuid_suffix=…{str(device_uuid)[-4:]}" in message
    assert f"portfolio_id={portfolio.id}" in message
    # Field list must be sorted + comma-joined so an inspector can grep.
    assert "fields=ma_window,name" in message


def test_patch_portfolio_audit_log_redacts_device_uuid(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """The raw ``device_uuid`` must never appear in any ``vca.api`` record."""
    device_uuid, _ = _seed_portfolio(db_session)
    raw_uuid = str(device_uuid)

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.patch(
            "/portfolio",
            params={"device_uuid": raw_uuid},
            json={"name": "Redacted"},
            headers=ATTEST,
        )
    assert resp.status_code == 200

    for record in caplog.records:
        if record.name != "vca.api":
            continue
        assert raw_uuid not in record.getMessage(), (
            "Raw device_uuid must not appear in any vca.api log line "
            "(see docs/legal/data-retention.md Application logs row)."
        )


def test_patch_portfolio_does_not_emit_audit_log_on_404(
    client: TestClient, caplog: pytest.LogCaptureFixture
) -> None:
    """A 404 rectification leaves no records-of-requests trail."""
    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.patch(
            "/portfolio",
            params={"device_uuid": str(uuid.uuid4())},
            json={"name": "Ghost"},
            headers=ATTEST,
        )
    assert resp.status_code == 404
    assert _audit_records_for(caplog, "dsr.rectification.portfolio") == [], (
        "No dsr.rectification.portfolio audit line should be emitted on a "
        "404 — the request was not honored."
    )


def test_patch_holding_emits_audit_log_on_success(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """Successful holding correction emits ``event=dsr.rectification.holding``."""
    device_uuid, portfolio = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.patch(
            "/portfolio/holdings/AAPL",
            params={"device_uuid": str(device_uuid)},
            json={"weight": "0.6"},
            headers=ATTEST,
        )
    assert resp.status_code == 200

    messages = _audit_records_for(caplog, "dsr.rectification.holding")
    assert len(messages) == 1
    message = messages[0]
    assert f"device_uuid_suffix=…{str(device_uuid)[-4:]}" in message
    assert f"portfolio_id={portfolio.id}" in message
    assert "ticker=AAPL" in message
    # The corrected weight is the personal data being rectified; logging
    # it would re-quote the rectified field into journald. Regression
    # guard for the "system of record is the DB, not the log" boundary
    # in docs/legal/data-retention.md.
    assert "0.6" not in message


def test_patch_holding_audit_log_redacts_device_uuid(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """The raw ``device_uuid`` must never appear in any ``vca.api`` record."""
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )
    raw_uuid = str(device_uuid)

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.patch(
            "/portfolio/holdings/AAPL",
            params={"device_uuid": raw_uuid},
            json={"weight": "0.7"},
            headers=ATTEST,
        )
    assert resp.status_code == 200

    for record in caplog.records:
        if record.name != "vca.api":
            continue
        assert raw_uuid not in record.getMessage(), (
            "Raw device_uuid must not appear in any vca.api log line "
            "(see docs/legal/data-retention.md Application logs row)."
        )


def test_patch_holding_does_not_emit_audit_log_on_404(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """A 404 (unknown ticker) rectification leaves no audit trail."""
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.patch(
            "/portfolio/holdings/MSFT",
            params={"device_uuid": str(device_uuid)},
            json={"weight": "0.5"},
            headers=ATTEST,
        )
    assert resp.status_code == 404
    assert _audit_records_for(caplog, "dsr.rectification.holding") == []


def test_delete_holding_emits_audit_log_on_success(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """Successful row-scoped delete emits ``event=dsr.row_delete.holding``.

    The event name is deliberately distinct from
    ``dsr.erasure.full_account`` (``DELETE /portfolio``) so an inspector
    can separate row-scoped ticker-typo corrections (Art. 16 path) from
    full-account erasures (Art. 17 path) in the same journald window.
    """
    device_uuid, portfolio = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.delete(
            "/portfolio/holdings/AAPL",
            params={"device_uuid": str(device_uuid)},
            headers=ATTEST,
        )
    assert resp.status_code == 204

    messages = _audit_records_for(caplog, "dsr.row_delete.holding")
    assert len(messages) == 1
    message = messages[0]
    assert f"device_uuid_suffix=…{str(device_uuid)[-4:]}" in message
    assert f"portfolio_id={portfolio.id}" in message
    assert "ticker=AAPL" in message
    # The row_delete event must NOT also stamp the account-level
    # erasure event — they describe distinct DSR scopes.
    assert _audit_records_for(caplog, "dsr.erasure.full_account") == []


def test_delete_holding_audit_log_redacts_device_uuid(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """The raw ``device_uuid`` must never appear in any ``vca.api`` record."""
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )
    raw_uuid = str(device_uuid)

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.delete(
            "/portfolio/holdings/AAPL",
            params={"device_uuid": raw_uuid},
            headers=ATTEST,
        )
    assert resp.status_code == 204

    for record in caplog.records:
        if record.name != "vca.api":
            continue
        assert raw_uuid not in record.getMessage(), (
            "Raw device_uuid must not appear in any vca.api log line "
            "(see docs/legal/data-retention.md Application logs row)."
        )


def test_delete_holding_does_not_emit_audit_log_on_404(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """A 404 (unknown ticker) delete leaves no audit trail."""
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.delete(
            "/portfolio/holdings/MSFT",
            params={"device_uuid": str(device_uuid)},
            headers=ATTEST,
        )
    assert resp.status_code == 404
    assert _audit_records_for(caplog, "dsr.row_delete.holding") == []


def test_delete_portfolio_emits_audit_log_on_success(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """Successful full-account erasure emits ``event=dsr.erasure.full_account``.

    ``holdings_count`` captures cascaded ``Holding`` rows so an
    inspector can correlate the erasure scope against a complainant's
    recollection without the controller having to re-quote the deleted
    personal data. The snapshot is taken **before** the ORM-level
    delete because the relationship cascade detaches the holdings from
    the session at commit.
    """
    device_uuid, portfolio = _seed_portfolio(
        db_session,
        holdings=(
            ("AAPL", Decimal("0.3")),
            ("MSFT", Decimal("0.4")),
            ("VOO", Decimal("0.3")),
        ),
    )
    portfolio_id = portfolio.id

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.delete(
            "/portfolio",
            params={"device_uuid": str(device_uuid)},
            headers=ATTEST,
        )
    assert resp.status_code == 204

    messages = _audit_records_for(caplog, "dsr.erasure.full_account")
    assert len(messages) == 1
    message = messages[0]
    assert f"device_uuid_suffix=…{str(device_uuid)[-4:]}" in message
    assert f"portfolio_id={portfolio_id}" in message
    assert "holdings_count=3" in message


def test_delete_portfolio_audit_log_redacts_device_uuid(
    client: TestClient,
    db_session: Session,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """The raw ``device_uuid`` must never appear in any ``vca.api`` record.

    Regression guard against the "system of record is the DB, not the
    log" boundary specifically at the highest-stakes DSR path — an
    Art. 17 full-account erasure that re-quoted the raw identifier into
    journald would re-open the surface that issue #339 closed.
    """
    device_uuid, _ = _seed_portfolio(
        db_session, holdings=(("AAPL", Decimal("0.5")),)
    )
    raw_uuid = str(device_uuid)

    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.delete(
            "/portfolio",
            params={"device_uuid": raw_uuid},
            headers=ATTEST,
        )
    assert resp.status_code == 204

    for record in caplog.records:
        if record.name != "vca.api":
            continue
        assert raw_uuid not in record.getMessage(), (
            "Raw device_uuid must not appear in any vca.api log line "
            "(see docs/legal/data-retention.md Application logs row)."
        )


def test_delete_portfolio_does_not_emit_audit_log_on_404(
    client: TestClient, caplog: pytest.LogCaptureFixture
) -> None:
    """A 404 full-account erasure leaves no records-of-requests trail.

    The records-of-requests surface tracks *honored* requests only; a
    404 was not honored (no rows changed hands), so an audit line would
    mislead a CCPA §7102(a) inspector by overstating the controller's
    activity.
    """
    with caplog.at_level("INFO", logger="vca.api"):
        resp = client.delete(
            "/portfolio",
            params={"device_uuid": str(uuid.uuid4())},
            headers=ATTEST,
        )
    assert resp.status_code == 404
    assert _audit_records_for(caplog, "dsr.erasure.full_account") == []


# ---------------------------------------------------------------------------
# Cache-Control / Last-Modified / Retry-After policy — issue #416
# ---------------------------------------------------------------------------
def test_schema_version_200_is_publicly_cacheable(client: TestClient) -> None:
    """GET /schema/version success advertises public, max-age=3600.

    The endpoint changes only on backend deploy and is the same value
    for every device, so an edge cache hit avoids a database round-trip
    on every iOS app launch. The previous middleware applied the same
    directive to *every* response status, which the issue #416 fix
    confines to this single success.
    """
    resp = client.get("/schema/version", headers=ATTEST)

    assert resp.status_code == 200
    assert resp.headers["Cache-Control"] == f"public, max-age={config.CACHE_MAX_AGE}"
    assert "Last-Modified" not in resp.headers


def test_schema_version_401_is_no_store(client: TestClient) -> None:
    """Missing App Attest → 401 with Cache-Control: no-store.

    The 401 envelope must never be edge-cached. Under the previous
    blanket policy a missing-header response could persist in URLCache
    for an hour even after the client started sending the header.
    """
    resp = client.get("/schema/version")

    assert resp.status_code == 401
    assert resp.headers["Cache-Control"] == "no-store"
    assert "Retry-After" not in resp.headers
    assert "Last-Modified" not in resp.headers


def test_portfolio_status_200_caches_short_and_sets_real_last_modified(
    client: TestClient, db_session: Session
) -> None:
    """GET /portfolio/status 200 emits a real Last-Modified.

    Resource time is sourced from ``StockCache.last_modified`` — the
    same value that lands in the response body — so a conditional GET
    based on the validator round-trips cleanly. RFC 7232 §2.2 mandates
    the validator describe resource modification time, not
    request-handling time (issue #416).
    """
    now = datetime(2026, 5, 14, 21, 5, 0, tzinfo=UTC)
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
    assert (
        resp.headers["Cache-Control"]
        == "public, max-age=60, stale-while-revalidate=60"
    )
    assert resp.headers["Last-Modified"] == "Thu, 14 May 2026 21:05:00 GMT"


def test_portfolio_status_omits_last_modified_when_cache_empty(
    client: TestClient,
) -> None:
    """No StockCache rows → Last-Modified omitted, not faked to now().

    Emitting a request-time validator on an empty cache would defeat
    the entire conditional-GET cycle the moment the cache is populated
    (the client would already hold a "newer" cached timestamp). The
    issue #416 fix omits the header rather than fabricate one.
    """
    resp = client.get("/portfolio/status", headers=ATTEST)

    assert resp.status_code == 200
    assert (
        resp.headers["Cache-Control"]
        == "public, max-age=60, stale-while-revalidate=60"
    )
    assert "Last-Modified" not in resp.headers


def test_portfolio_data_404_is_private_no_store(client: TestClient) -> None:
    """A 404 portfolio lookup must not be edge-cached for an hour.

    Under the previous blanket ``max-age=3600`` policy, an iOS client
    that hit ``/portfolio/data`` before its first portfolio existed
    would cache the 404 envelope for an hour — so the UI stayed empty
    well after the user had created the portfolio. The issue #416 fix
    pins ``private, no-store`` on every status of this personalised
    read, success or error, so the privacy directive in OpenAPI and the
    wire-level header agree.
    """
    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(uuid.uuid4())},
        headers=ATTEST,
    )

    assert resp.status_code == 404
    assert resp.headers["Cache-Control"] == "private, no-store"
    assert "Last-Modified" not in resp.headers


def test_portfolio_data_200_is_private_no_store(
    client: TestClient, db_session: Session
) -> None:
    """Personalised reads are never shared-cacheable.

    GET /portfolio/data returns device-scoped data and must never spill
    into a Cloudflare edge cache. ``private, no-store`` forbids both
    shared and ``URLCache.shared`` storage so two devices sharing a NAT
    can never receive each other's holdings.
    """
    device_uuid, _ = _seed_portfolio(
        db_session,
        holdings=(("AAPL", Decimal("0.5")),),
    )

    resp = client.get(
        "/portfolio/data",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )

    assert resp.status_code == 200
    assert resp.headers["Cache-Control"] == "private, no-store"
    assert "Last-Modified" not in resp.headers


def test_portfolio_export_200_is_private_no_store(
    client: TestClient, db_session: Session
) -> None:
    """GDPR Art. 20 export response must never sit in a shared cache."""
    device_uuid, _ = _seed_portfolio(
        db_session,
        holdings=(("AAPL", Decimal("0.5")),),
    )

    resp = client.get(
        "/portfolio/export",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )

    assert resp.status_code == 200
    assert resp.headers["Cache-Control"] == "private, no-store"


def test_post_portfolio_holdings_202_is_no_store(
    client: TestClient, db_session: Session
) -> None:
    """POST 202 carries no cacheable payload — directive locks it in."""
    device_uuid, _ = _seed_portfolio(db_session)

    resp = client.post(
        "/portfolio/holdings",
        json={
            "device_uuid": str(device_uuid),
            "ticker": "MSFT",
            "weight": 0.25,
        },
        headers=ATTEST,
    )

    assert resp.status_code == 202
    assert resp.headers["Cache-Control"] == "no-store"


def test_patch_portfolio_success_is_private_no_store(
    client: TestClient, db_session: Session
) -> None:
    """Rectification responses are per-device and must not be cached."""
    device_uuid, _ = _seed_portfolio(db_session)

    resp = client.patch(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        json={"name": "Renamed"},
        headers=ATTEST,
    )

    assert resp.status_code == 200
    assert resp.headers["Cache-Control"] == "private, no-store"


def test_delete_portfolio_204_is_no_store(
    client: TestClient, db_session: Session
) -> None:
    """A 204 erasure response has no cacheable body, but lock the directive."""
    device_uuid, _ = _seed_portfolio(db_session)

    resp = client.delete(
        "/portfolio",
        params={"device_uuid": str(device_uuid)},
        headers=ATTEST,
    )

    assert resp.status_code == 204
    assert resp.headers["Cache-Control"] == "no-store"


def test_validation_422_is_no_store(client: TestClient) -> None:
    """RequestValidationError 422 envelopes are never cached.

    The route here is ``POST /portfolio/holdings`` which the policy
    table pins to ``no-store`` for all statuses; the wire header must
    match.
    """
    resp = client.post(
        "/portfolio/holdings",
        json={"device_uuid": "not-a-uuid"},
        headers=ATTEST,
    )

    assert resp.status_code == 422
    assert resp.headers["Cache-Control"] == "no-store"


def test_validation_422_on_personalised_route_is_private_no_store(
    client: TestClient,
) -> None:
    """422 on a personalised route emits ``private, no-store``.

    Locks in the issue #416 fix that resolves the validation handler's
    ``Cache-Control`` via :data:`_CACHE_POLICY` (rather than hardcoding
    ``no-store``) so a 422 from ``PATCH /portfolio/holdings/{ticker}``
    carries the same privacy directive the OpenAPI contract advertises
    for that operation.
    """
    resp = client.patch(
        "/portfolio/holdings/AAPL",
        params={"device_uuid": "not-a-uuid"},
        json={"weight": 0.5},
        headers=ATTEST,
    )

    assert resp.status_code == 422
    assert resp.headers["Cache-Control"] == "private, no-store"


def test_503_emits_retry_after_header(client: TestClient) -> None:
    """503 ApiErrors mirror retry_after_seconds onto Retry-After."""
    from sqlalchemy.exc import OperationalError

    def _broken_db():
        class _BrokenSession:
            def execute(self, *_args, **_kwargs):  # noqa: ANN001
                raise OperationalError("SELECT 1", {}, Exception("db down"))

        yield _BrokenSession()

    app.dependency_overrides[get_db] = _broken_db
    try:
        resp = TestClient(app).get("/portfolio/status", headers=ATTEST)
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 503
    assert resp.headers["Cache-Control"] == "no-store"
    assert resp.headers["Retry-After"] == "60"


def test_503_on_personalised_route_emits_private_no_store(
    client: TestClient,
) -> None:
    """503 on a personalised route carries ``private, no-store``.

    Locks in the issue #416 fix: ``api_error_handler`` resolves the
    ``Cache-Control`` value from :data:`_CACHE_POLICY` so an outage on
    ``GET /portfolio/data`` emits ``private, no-store`` (matching the
    OpenAPI contract for the route) rather than the hardcoded
    ``no-store`` an earlier implementation produced.
    """
    from sqlalchemy.exc import OperationalError

    def _broken_db():
        class _BrokenSession:
            def execute(self, *_args, **_kwargs):  # noqa: ANN001
                raise OperationalError("SELECT 1", {}, Exception("db down"))

        yield _BrokenSession()

    app.dependency_overrides[get_db] = _broken_db
    try:
        resp = TestClient(app).get(
            "/portfolio/data",
            params={"device_uuid": str(uuid.uuid4())},
            headers=ATTEST,
        )
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 503
    assert resp.headers["Cache-Control"] == "private, no-store"
    assert resp.headers["Retry-After"] == "60"


def test_http_date_format_is_locale_independent() -> None:
    """Locale-independent ``format_http_date`` output.

    Locks in the locale-independence fix: switching from
    ``strftime("%a, %d %b ...")`` to ``email.utils.format_datetime`` so
    a non-C ``LC_TIME`` (e.g. ``fr_FR.UTF-8``) cannot emit a
    non-compliant ``Last-Modified`` like ``"lun., 14 mai 2026 ..."``.
    """
    import locale

    from api.main import format_http_date

    stamp = datetime(2026, 5, 14, 21, 5, 0, tzinfo=UTC)
    saved = locale.setlocale(locale.LC_TIME)
    try:
        for candidate in ("fr_FR.UTF-8", "de_DE.UTF-8", "ja_JP.UTF-8"):
            try:
                locale.setlocale(locale.LC_TIME, candidate)
            except locale.Error:
                continue
            assert format_http_date(stamp) == "Thu, 14 May 2026 21:05:00 GMT"
    finally:
        locale.setlocale(locale.LC_TIME, saved)

    assert format_http_date(stamp) == "Thu, 14 May 2026 21:05:00 GMT"


def test_openapi_declares_retry_after_on_503_responses(
    client: TestClient,
) -> None:
    """Every 503 response advertises the Retry-After header.

    Generated clients should know to read the standard wire header
    rather than parsing ``ErrorEnvelope.retry_after_seconds`` out of the
    body — Cloudflare and ``URLSession`` already honour the header
    natively (RFC 7231 §7.1.3).
    """
    schema = client.get("/openapi.json").json()
    for path, path_item in schema["paths"].items():
        for method, operation in path_item.items():
            responses = operation.get("responses", {})
            if "503" in responses:
                headers = responses["503"].get("headers", {})
                assert "Retry-After" in headers, (
                    f"{method.upper()} {path} 503 must declare Retry-After"
                )
                assert headers["Retry-After"]["schema"]["type"] == "integer"


def test_openapi_only_status_endpoint_declares_last_modified(
    client: TestClient,
) -> None:
    """Only GET /portfolio/status 200 advertises a real Last-Modified.

    Every other operation's response now omits the header. The
    contract documents exactly the wire shape the middleware emits, so
    generated clients don't expect a validator on every response.
    """
    schema = client.get("/openapi.json").json()
    last_modified_routes: set[tuple[str, str, str]] = set()
    for path, path_item in schema["paths"].items():
        for method, operation in path_item.items():
            responses = operation.get("responses", {})
            for status_code, response in responses.items():
                if "Last-Modified" in response.get("headers", {}):
                    last_modified_routes.add(
                        (method.upper(), path, status_code)
                    )

    assert last_modified_routes == {("GET", "/portfolio/status", "200")}


def test_openapi_no_response_advertises_blanket_max_age(
    client: TestClient,
) -> None:
    """Only ``/schema/version`` 200 advertises the long edge-cache window.

    Every other operation either omits ``Cache-Control`` or pins a
    ``no-store``/short-cache directive. Locks in the issue #416 fix so a
    future regression that re-introduces blanket ``max-age=3600`` fails
    contract tests.
    """
    schema = client.get("/openapi.json").json()
    cache_examples: dict[tuple[str, str, str], str] = {}
    for path, path_item in schema["paths"].items():
        for method, operation in path_item.items():
            responses = operation.get("responses", {})
            for status_code, response in responses.items():
                header = response.get("headers", {}).get("Cache-Control")
                if header is None:
                    continue
                example = header.get("schema", {}).get("example", "")
                cache_examples[(method.upper(), path, status_code)] = example

    # The only entry that should reference ``max-age=3600`` (the long
    # edge-cache window) is /schema/version 200.
    long_cache = {
        key for key, value in cache_examples.items() if "max-age=3600" in value
    }
    assert long_cache == {("GET", "/schema/version", "200")}

    # Every other response either omits Cache-Control or sets a
    # no-store / short-cache directive.
    for key, value in cache_examples.items():
        if key == ("GET", "/schema/version", "200"):
            continue
        if key == ("GET", "/portfolio/status", "200"):
            assert value == (
                "public, max-age=60, stale-while-revalidate=60"
            )
        else:
            assert "no-store" in value, f"{key} should be no-store, got {value!r}"
