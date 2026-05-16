"""FastAPI application for vca-api.

Implements the endpoints documented in ``backend/api/README.md`` and the
original services spec:

* ``GET    /health`` — liveness + DB reachability.
* ``GET    /portfolio/status`` — ``last_modified`` / ``next_modified``, cacheable.
* ``GET    /portfolio/data`` — full portfolio allocation for the device.
* ``GET    /portfolio/export`` — GDPR Art. 20 / CCPA §1798.100 personal-data
  export.
* ``PATCH  /portfolio`` — GDPR Art. 16 / CCPA §1798.106 rectify scalar
  portfolio fields (issue #374).
* ``GET    /schema/version`` — current API schema version.
* ``POST   /portfolio/holdings`` — add a ticker; queues a background fetch.
* ``PATCH  /portfolio/holdings/{ticker}`` — GDPR Art. 16 / CCPA §1798.106
  rectify holding weight (issue #374).
* ``DELETE /portfolio/holdings/{ticker}`` — remove a single holding
  (ticker-typo correction path; row-scoped, distinct from full-account
  erasure tracked under issue #329).
* ``DELETE /portfolio`` — GDPR Art. 17 / CCPA §1798.105 full-account
  erasure (issue #450). Cascade-deletes the calling device's
  ``Portfolio`` and every ``Holding`` keyed to it.

The app reads from Postgres only and **never** calls Polygon directly,
with one explicit exception: ``POST /portfolio/holdings`` queues an
asyncio background task to populate ``stock_cache`` for a brand-new
ticker — see the New Ticker Flow in the README.
"""

from __future__ import annotations

import json
import logging
from datetime import UTC, datetime
from decimal import Decimal
from enum import StrEnum
from typing import Annotated, Any
from uuid import UUID

from fastapi import (
    BackgroundTasks,
    Depends,
    FastAPI,
    Header,
    HTTPException,
    Request,
    Response,
    status,
)
from fastapi.exceptions import RequestValidationError
from fastapi.openapi.utils import get_openapi
from fastapi.responses import JSONResponse
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    PlainSerializer,
    WithJsonSchema,
    model_validator,
)
from sqlalchemy import select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from common import config
from common import db as common_db
from common.logging_utils import redact_device_uuid
from db.models import Holding, Portfolio, StockCache

log = logging.getLogger("vca.api")


class ErrorCode(StrEnum):
    """Stable machine-readable error codes for clients.

    ``portfolioNotFound`` and ``holdingNotFound`` carry distinct semantics
    on the holding-scoped routes (PATCH/DELETE ``/portfolio/holdings/{ticker}``):
    the portfolio code means the calling device never synced a portfolio
    (the iOS client should redirect to onboarding), while the holding code
    means the parent portfolio resolved successfully but the keyed holding
    row is gone (the client should refresh its local holdings list and let
    the user retry). The ``message`` field stays free-form per the
    ``ErrorEnvelope`` contract — clients must dispatch on ``code``.
    """

    APP_ATTEST_MISSING = "appAttestMissing"
    CONFLICT_DETECTED = "conflictDetected"
    HOLDING_NOT_FOUND = "holdingNotFound"
    LOSSY_MAPPING_REJECTED = "lossyMappingRejected"
    PORTFOLIO_NOT_FOUND = "portfolioNotFound"
    SCHEMA_UNSUPPORTED = "schemaUnsupported"
    STOCK_DATA_MISSING = "stockDataMissing"
    STOCK_DATA_PENDING = "stockDataPending"
    STOCK_DATA_STALE = "stockDataStale"
    SYNC_UNAVAILABLE = "syncUnavailable"
    UNSUPPORTED_MA_WINDOW = "unsupportedMovingAverageWindow"


class ErrorEnvelope(BaseModel):
    """Structured HTTP error body decoded by iOS clients."""

    code: ErrorCode
    message: str
    retry_after_seconds: int | None = Field(default=None, ge=0)


class ApiError(HTTPException):
    """HTTP exception carrying the public error envelope."""

    def __init__(
        self,
        *,
        status_code: int,
        code: ErrorCode,
        message: str,
        retry_after_seconds: int | None = None,
    ) -> None:
        """Initialize an API error from public contract fields."""
        super().__init__(status_code=status_code, detail=message)
        self.envelope = ErrorEnvelope(
            code=code,
            message=message,
            retry_after_seconds=retry_after_seconds,
        )


ERROR_RESPONSES = {
    status.HTTP_401_UNAUTHORIZED: {
        "model": ErrorEnvelope,
        "description": "Missing or invalid App Attest credentials.",
    },
    status.HTTP_404_NOT_FOUND: {
        "model": ErrorEnvelope,
        "description": "Requested portfolio resource was not found.",
    },
    status.HTTP_409_CONFLICT: {
        "model": ErrorEnvelope,
        "description": "Client data could not be represented without conflict.",
    },
    status.HTTP_422_UNPROCESSABLE_ENTITY: {
        "model": ErrorEnvelope,
        "description": "Request uses an unsupported contract or market-data option.",
    },
    status.HTTP_503_SERVICE_UNAVAILABLE: {
        "model": ErrorEnvelope,
        "description": "Service, sync, or market data is temporarily unavailable.",
    },
}

app = FastAPI(
    title="vca-api",
    version="1.0.0",
    description=(
        "value-compass FastAPI service. Reads from Postgres only; never "
        "calls Polygon directly except via the /portfolio/holdings "
        "background task for brand-new tickers."
    ),
)

STANDARD_RESPONSE_HEADERS = {
    "Cache-Control": {
        "description": "Cloudflare-cacheable max-age in seconds.",
        "schema": {"type": "string"},
    },
    "Last-Modified": {
        "description": "UTC RFC 7231 timestamp for the response.",
        "schema": {"type": "string"},
    },
    "X-Min-App-Version": {
        "description": "Minimum supported iOS app version.",
        "schema": {"type": "string"},
    },
}


def custom_openapi() -> dict[str, Any]:
    """Generate OpenAPI with middleware-provided standard response headers.

    Also marks the ``X-App-Attest`` header parameter as ``required: true`` on
    every operation that declares it. The runtime dependency
    ``require_app_attest`` accepts the header as ``Optional[str]`` so that a
    missing value returns the documented 401 ``appAttestMissing`` envelope
    instead of FastAPI's generic 422 validation error. The contract that
    generated clients consume must still advertise the header as required —
    backend rejects every protected route when it is absent — so we fix up
    the spec here. ``/health`` does not declare the parameter and is left
    untouched.

    Additionally prunes the FastAPI auto-generated ``HTTPValidationError`` /
    ``ValidationError`` component schemas. Every operation that can emit a
    ``422`` explicitly declares :class:`ErrorEnvelope` via
    ``ERROR_RESPONSES`` (the global ``validation_error_handler`` returns the
    public envelope), so the legacy schemas are never referenced from any
    operation. Leaving the stale shapes in ``components.schemas`` would let
    generated clients model the wrong validation payload (issue #302).

    Finally re-merges numeric range constraints onto ``DecimalString``
    request fields: Pydantic's ``WithJsonSchema`` override blanks any
    ``Field(gt=..., le=...)`` metadata, so ``PatchHoldingRequest.weight``
    and ``PatchPortfolioRequest.monthly_budget`` shipped without the
    invariants enforced at runtime. Re-emitting them keeps the three
    surfaces touching ``Holding.weight`` (POST, PATCH /holdings/{ticker},
    PATCH /portfolio) symmetric and stops the spec from silently drifting
    against the runtime guard (issue #461).
    """
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    for path_item in openapi_schema.get("paths", {}).values():
        for operation in path_item.values():
            if not isinstance(operation, dict):
                continue
            responses = operation.get("responses", {})
            for response in responses.values():
                if not isinstance(response, dict):
                    continue
                response.setdefault("headers", {}).update(STANDARD_RESPONSE_HEADERS)
            for parameter in operation.get("parameters", []):
                if (
                    isinstance(parameter, dict)
                    and parameter.get("in") == "header"
                    and parameter.get("name") == "X-App-Attest"
                ):
                    parameter["required"] = True
                    schema = parameter.get("schema")
                    if isinstance(schema, dict):
                        any_of = schema.get("anyOf")
                        if isinstance(any_of, list):
                            non_null = [
                                option
                                for option in any_of
                                if not (
                                    isinstance(option, dict)
                                    and option.get("type") == "null"
                                )
                            ]
                            if len(non_null) == 1 and isinstance(non_null[0], dict):
                                schema.pop("anyOf", None)
                                schema.update(non_null[0])

    _prune_legacy_validation_schemas(openapi_schema)
    _apply_decimal_string_bounds(openapi_schema)

    app.openapi_schema = openapi_schema
    return app.openapi_schema


_LEGACY_VALIDATION_SCHEMAS = ("HTTPValidationError", "ValidationError")


def _prune_legacy_validation_schemas(openapi_schema: dict[str, Any]) -> None:
    """Remove FastAPI's auto ``HTTPValidationError``/``ValidationError`` schemas.

    Every ``422`` response is documented as :class:`ErrorEnvelope` (see
    ``ERROR_RESPONSES``), so the legacy schemas are dead refs that would
    otherwise leak into generated clients. Refuses to prune if any operation
    still references the legacy shapes — a regression that warrants a hard
    failure rather than silent surgery.
    """
    components = openapi_schema.get("components", {})
    schemas = components.get("schemas", {})
    if not any(name in schemas for name in _LEGACY_VALIDATION_SCHEMAS):
        return

    document_text = json.dumps(openapi_schema.get("paths", {}))
    for name in _LEGACY_VALIDATION_SCHEMAS:
        ref = f"#/components/schemas/{name}"
        if ref in document_text:
            raise RuntimeError(
                f"Operation still references legacy validation schema {name!r}; "
                "declare 422 responses with ErrorEnvelope via ERROR_RESPONSES."
            )
        schemas.pop(name, None)


# Numeric range constraints that the ``DecimalString`` ``WithJsonSchema``
# override strips off ``Field(gt=..., le=...)`` metadata. Mirror the
# Pydantic-enforced runtime invariants so generated clients receive the
# same constraint advertisement on every surface that touches the same
# database column (issue #461). Keep number-encoded bounds so the contract
# matches ``AddHoldingRequest.weight`` (POST /portfolio/holdings) verbatim.
_DECIMAL_STRING_BOUNDS: dict[str, dict[str, dict[str, float]]] = {
    "PatchHoldingRequest": {
        "weight": {"exclusiveMinimum": 0, "maximum": 1},
    },
    "PatchPortfolioRequest": {
        "monthly_budget": {"exclusiveMinimum": 0},
    },
}


def _apply_decimal_string_bounds(openapi_schema: dict[str, Any]) -> None:
    """Re-emit ``gt``/``le`` bounds stripped by ``DecimalString``.

    Walks the registry and merges each constraint into the matching field
    schema. Handles nullable fields by locating the non-``null`` branch of
    the field's ``anyOf`` so the bound applies to the value type, not the
    null sentinel. Raises if a registered schema or field is missing so a
    rename does not silently re-introduce the contract drift this fix
    closes (issue #461).
    """
    schemas = openapi_schema.get("components", {}).get("schemas", {})
    for schema_name, fields in _DECIMAL_STRING_BOUNDS.items():
        component_schema = schemas.get(schema_name)
        if component_schema is None:
            raise RuntimeError(
                f"DecimalString bounds registry references unknown schema "
                f"{schema_name!r}; update _DECIMAL_STRING_BOUNDS to match."
            )
        properties = component_schema.get("properties", {})
        for field_name, bounds in fields.items():
            field_schema = properties.get(field_name)
            if field_schema is None:
                raise RuntimeError(
                    f"DecimalString bounds registry references unknown field "
                    f"{schema_name}.{field_name!r}; "
                    "update _DECIMAL_STRING_BOUNDS to match."
                )
            target = _decimal_string_target(field_schema)
            if target is None:
                raise RuntimeError(
                    f"{schema_name}.{field_name!r} is not a DecimalString "
                    "field; remove it from _DECIMAL_STRING_BOUNDS or stop "
                    "overriding its JSON schema."
                )
            target.update(bounds)


def _decimal_string_target(field_schema: dict[str, Any]) -> dict[str, Any] | None:
    """Return the ``string``/``format=decimal`` branch of a field schema.

    For non-nullable fields the field schema itself is the target. For
    nullable fields (``anyOf: [{type: string, format: decimal}, {type:
    null}]``) the non-null branch is the target. Returns ``None`` when the
    field is not the expected DecimalString shape.
    """
    if (
        field_schema.get("type") == "string"
        and field_schema.get("format") == "decimal"
    ):
        return field_schema

    any_of = field_schema.get("anyOf")
    if isinstance(any_of, list):
        for option in any_of:
            if (
                isinstance(option, dict)
                and option.get("type") == "string"
                and option.get("format") == "decimal"
            ):
                return option
    return None


app.openapi = custom_openapi


@app.exception_handler(ApiError)
async def api_error_handler(_: Request, exc: ApiError) -> JSONResponse:
    """Render API errors as the documented top-level envelope."""
    return JSONResponse(
        status_code=exc.status_code,
        content=exc.envelope.model_dump(mode="json"),
    )


@app.exception_handler(RequestValidationError)
async def validation_error_handler(
    _: Request, exc: RequestValidationError
) -> JSONResponse:
    """Render request validation failures as the public error envelope."""
    envelope = ErrorEnvelope(
        code=ErrorCode.SCHEMA_UNSUPPORTED,
        message="Request validation failed.",
    )
    log.info("request validation failed: %s", exc.errors())
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=envelope.model_dump(mode="json"),
    )


# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
def get_db() -> Session:  # pragma: no cover
    """FastAPI dependency yielding a SQLAlchemy session."""
    with common_db.get_session() as session:
        yield session


def _stamp_activity(db: Session, portfolio: Portfolio) -> None:
    """Record an authenticated touch on ``portfolio.last_seen_at``.

    Called whenever a protected endpoint resolves a ``Portfolio`` by its
    ``device_uuid``. The timestamp is the basis for the retention-purge
    sweep (see ``backend/poller/purge.py`` and the schedule in
    ``docs/legal/data-retention.md``), so writing it here keeps the
    retention window in lock-step with real device activity rather than
    schema-creation time.

    Commit failures are logged but never raised — a stamp miss only
    causes the row to be purged sooner on the next sweep, which is
    strictly safer than failing the user-facing request.
    """
    portfolio.last_seen_at = datetime.now(UTC)
    try:
        db.commit()
    except SQLAlchemyError as exc:
        db.rollback()
        log.warning("portfolio activity stamp failed: %s", exc)


async def require_app_attest(
    x_app_attest: str | None = Header(default=None, alias="X-App-Attest"),
) -> str:
    """Validate the App Attest header on every request.

    The actual cryptographic verification is performed by Cloudflare /
    Apple App Attest infrastructure in production; here we only enforce
    that the header is present and non-empty so that an unauthenticated
    request never reaches the database. Endpoints that should not
    require attestation (only ``/health``) opt out explicitly.
    """
    if not x_app_attest:
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code=ErrorCode.APP_ATTEST_MISSING,
            message="Missing X-App-Attest header.",
        )
    return x_app_attest


# ---------------------------------------------------------------------------
# Response-headers middleware
# ---------------------------------------------------------------------------
@app.middleware("http")
async def add_standard_headers(request: Request, call_next):
    """Set the spec-mandated response headers on every response.

    * ``Cache-Control: max-age=<CACHE_MAX_AGE>``
    * ``Last-Modified: <UTC RFC 7231 timestamp>``
    * ``X-Min-App-Version: <minimum supported iOS app version>``
    """
    response: Response = await call_next(request)
    response.headers.setdefault(
        "Cache-Control", f"max-age={config.CACHE_MAX_AGE}"
    )
    response.headers.setdefault(
        "Last-Modified",
        datetime.now(UTC).strftime("%a, %d %b %Y %H:%M:%S GMT"),
    )
    response.headers.setdefault("X-Min-App-Version", config.MIN_APP_VERSION)
    return response


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
# Monetary fields carry exact decimal values end-to-end. Pydantic's default
# JSON schema for ``Decimal`` is ``{"anyOf": [{"type": "number"}, {"type":
# "string"}]}``, which the SwiftOpenAPIGenerator decodes as a union; bare
# ``number`` decodes as ``Double`` and discards precision. We pin the wire
# representation to ``string`` so generated clients can round-trip the value
# through ``Decimal(string:)`` without IEEE-754 loss. See issues #317, #392.
DecimalString = Annotated[
    Decimal,
    PlainSerializer(str, return_type=str, when_used="json"),
    WithJsonSchema({"type": "string", "format": "decimal"}),
]


class HealthResponse(BaseModel):
    """Health-check response body."""

    # `status` is always populated by the server and is therefore declared
    # `required` in the generated OpenAPI schema (see issue #381). The
    # `Field(default="ok")` default is preserved as documentation of the
    # canonical value but is not relied on at runtime — `health()` always
    # sets it explicitly. `json_schema_extra` is merged into the model
    # schema and promotes `status` into the schema's top-level `required`
    # array so generated clients (including the iOS SwiftOpenAPIGenerator
    # client) decode it as non-optional.
    model_config = ConfigDict(json_schema_extra={"required": ["status"]})

    status: str = Field(default="ok")


class SchemaVersionResponse(BaseModel):
    """API schema-version response body.

    The minimum supported iOS app version is carried exclusively on the
    ``X-Min-App-Version`` response header — declared on every operation by
    :func:`add_standard_headers` and consumed by
    ``MinAppVersionClient.observe`` on the iOS side. The body intentionally
    does **not** duplicate that value: a dual-source contract (body field +
    response header from the same ``config.MIN_APP_VERSION``) has no defined
    precedence rule, and shipping both invites future consumers to fork on
    which channel they trust. See issue #402.
    """

    version: int


class PortfolioStatusResponse(BaseModel):
    """Portfolio freshness response body."""

    last_modified: datetime | None
    next_modified: datetime | None


class HoldingOut(BaseModel):
    """Holding data returned to the iOS client."""

    ticker: str
    weight: float
    current_price: float | None
    sma_50: float | None
    sma_200: float | None
    midline: float | None
    atr: float | None
    upper_band: float | None
    lower_band: float | None
    band_position: float | None


class PortfolioDataResponse(BaseModel):
    """Full portfolio allocation response body."""

    portfolio_id: UUID
    name: str
    monthly_budget: DecimalString
    ma_window: int
    holdings: list[HoldingOut]


class AddHoldingRequest(BaseModel):
    """Request body for adding a holding to a device portfolio."""

    device_uuid: UUID
    ticker: str = Field(min_length=1, max_length=10)
    weight: float = Field(gt=0, le=1)


# Moving-average windows accepted by the CheckConstraint on
# ``Portfolio.ma_window`` (``backend/db/models.py``). Centralised here so
# the API rejects unsupported values up-front with the documented
# ``unsupportedMovingAverageWindow`` envelope rather than letting the
# database raise a generic IntegrityError. Mirrors the iOS-side enum in
# ``app/Sources/Backend/Models/MovingAverageWindow.swift``.
SUPPORTED_MA_WINDOWS: frozenset[int] = frozenset({50, 200})


class PatchPortfolioRequest(BaseModel):
    """Request body for ``PATCH /portfolio``.

    Implements the scalar half of the GDPR Art. 16 / CCPA §1798.106
    right-to-rectification path (issue #374). Every field is optional
    so the client can correct a single value without re-stating the
    others, but the body **must** carry at least one non-null field —
    an empty PATCH is rejected as ``schemaUnsupported`` so the wire
    contract never accepts a no-op write that silently stamps activity.

    ``ma_window`` accepts only the values enumerated in
    :data:`SUPPORTED_MA_WINDOWS`; anything else is rejected with the
    documented ``unsupportedMovingAverageWindow`` envelope so the iOS
    client can surface a specific error rather than the generic
    ``schemaUnsupported`` validation failure.
    """

    name: str | None = Field(default=None, min_length=1)
    monthly_budget: DecimalString | None = Field(default=None, gt=Decimal("0"))
    ma_window: int | None = Field(default=None)

    @model_validator(mode="after")
    def _require_at_least_one_field(self) -> PatchPortfolioRequest:
        """Reject empty PATCH bodies — they would no-op but stamp activity."""
        if (
            self.name is None
            and self.monthly_budget is None
            and self.ma_window is None
        ):
            raise ValueError(
                "PatchPortfolioRequest requires at least one of "
                "name, monthly_budget, ma_window."
            )
        return self


class PatchPortfolioResponse(BaseModel):
    """Response body for ``PATCH /portfolio``.

    Returns the scalar portfolio fields after the correction commits so
    the iOS client can confirm its local SwiftData state matches the
    server. Excludes ``holdings`` and market-data joins (which are
    served by ``GET /portfolio/data``) to keep the rectification
    response cheap.
    """

    portfolio_id: UUID
    name: str
    monthly_budget: DecimalString
    ma_window: int


class PatchHoldingRequest(BaseModel):
    """Request body for ``PATCH /portfolio/holdings/{ticker}``.

    Only ``weight`` is mutable through PATCH. A ticker typo (`AAPL`
    intended as `MSFT`) is corrected by ``DELETE /portfolio/holdings/
    {ticker}`` + ``POST /portfolio/holdings``; PATCH does not rename
    the row's primary key. ``DecimalString`` preserves exact precision
    end-to-end (see #392).
    """

    weight: DecimalString = Field(gt=Decimal("0"), le=Decimal("1"))


class PatchHoldingResponse(BaseModel):
    """Response body for ``PATCH /portfolio/holdings/{ticker}``.

    Mirrors the persisted ``Holding`` row rather than the enriched
    :class:`HoldingOut` returned from ``/portfolio/data`` — market-data
    fields are intentionally excluded so PATCH returns only the
    rectified value the client wrote.
    """

    ticker: str
    weight: DecimalString


class PortfolioExportHolding(BaseModel):
    """Single holding in the personal-data export.

    Mirrors the persisted row (``backend/db/models.py::Holding``) rather
    than the enriched :class:`HoldingOut` returned from
    ``/portfolio/data``: the export is a verbatim dump of every
    ``X-Device-UUID``-linked row, not a recomputed view, so cached
    market-data fields are intentionally excluded.
    """

    ticker: str
    weight: DecimalString


class PortfolioExport(BaseModel):
    """Personal data the backend stores about one device's portfolio.

    Every field is sourced directly from ``backend/db/models.py`` so the
    export is auditable against the schema: if a row has it, the export
    has it.
    """

    portfolio_id: UUID
    name: str
    monthly_budget: DecimalString
    ma_window: int
    created_at: datetime
    last_seen_at: datetime | None
    holdings: list[PortfolioExportHolding]


class PortfolioExportResponse(BaseModel):
    """GDPR Art. 20 / CCPA §1798.100 personal-data export envelope.

    Returned by ``GET /portfolio/export``. The body is the complete set
    of ``X-Device-UUID``-linked rows the backend stores for the caller,
    in a structured machine-readable form so the data subject can move
    it to another controller (Art. 20) or audit what is held about them
    (Art. 15 / §1798.110).

    ``format_version`` lets us evolve the export shape additively without
    breaking offline tooling that parses prior exports. Bump on every
    backwards-incompatible field change.
    """

    # ``format_version`` is always populated by the server (Pydantic v2
    # emits fields with defaults in ``model_dump(mode="json")``) and is
    # therefore declared ``required`` in the generated OpenAPI schema —
    # same pattern as :class:`HealthResponse` (see issue #381). The
    # ``Field(default=1)`` default is preserved as documentation of the
    # canonical value; ``portfolio_export`` never omits it at runtime.
    # ``json_schema_extra`` is merged into the model schema and *replaces*
    # the auto-generated ``required`` array (dict-update semantics), so
    # every required field must be listed explicitly here — re-stating
    # ``generated_at``/``device_uuid``/``portfolio`` keeps them required
    # while promoting ``format_version`` so generated clients (including
    # the iOS SwiftOpenAPIGenerator client) decode it as non-optional and
    # can branch deterministically when the format is bumped (issue #463).
    model_config = ConfigDict(
        json_schema_extra={
            "required": [
                "format_version",
                "generated_at",
                "device_uuid",
                "portfolio",
            ]
        }
    )

    format_version: int = Field(default=1, ge=1)
    generated_at: datetime
    device_uuid: UUID
    portfolio: PortfolioExport


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.get(
    "/health",
    response_model=HealthResponse,
    responses={
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ]
    },
)
def health(db: Session = Depends(get_db)) -> HealthResponse:
    """Return 200 if the API process is up and Postgres is reachable."""
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        log.warning("health check failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc
    return HealthResponse(status="ok")


@app.get(
    "/schema/version",
    response_model=SchemaVersionResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
    },
)
def schema_version(_: str = Depends(require_app_attest)) -> SchemaVersionResponse:
    """Return the API schema version required by the client."""
    return SchemaVersionResponse(version=config.SCHEMA_VERSION)


@app.get(
    "/portfolio/status",
    response_model=PortfolioStatusResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ],
    },
)
def portfolio_status(
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> PortfolioStatusResponse:
    """Return the freshest ``last_modified`` / ``next_modified``.

    The cache response is lightweight and Cloudflare-cacheable. A
    SQLAlchemy failure is surfaced as the documented ``syncUnavailable``
    503 envelope (matching ``/portfolio/data`` and ``/health``) so the
    iOS client sees a decodable retry signal instead of FastAPI's default
    500 body when the DB is unreachable (issue #439).
    """
    try:
        row = db.execute(
            select(StockCache.last_modified, StockCache.next_modified)
            .order_by(StockCache.last_modified.desc())
            .limit(1)
        ).first()
    except SQLAlchemyError as exc:
        log.warning("portfolio status lookup failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    if row is None:
        return PortfolioStatusResponse(last_modified=None, next_modified=None)
    return PortfolioStatusResponse(last_modified=row[0], next_modified=row[1])


@app.get(
    "/portfolio/data",
    response_model=PortfolioDataResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_404_NOT_FOUND: ERROR_RESPONSES[status.HTTP_404_NOT_FOUND],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ],
    },
)
def portfolio_data(
    device_uuid: UUID,
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> PortfolioDataResponse:
    """Return the full portfolio allocation for the calling device.

    Only called by the iOS client on a cache miss.
    """
    try:
        portfolio = db.execute(
            select(Portfolio).where(Portfolio.device_uuid == device_uuid)
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        log.warning("portfolio data lookup failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    if portfolio is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.PORTFOLIO_NOT_FOUND,
            message="Portfolio not found for device.",
        )

    holdings_out: list[HoldingOut] = []
    for holding in portfolio.holdings:
        cache = db.get(StockCache, holding.ticker)
        holdings_out.append(
            HoldingOut(
                ticker=holding.ticker,
                weight=float(holding.weight),
                current_price=float(cache.current_price) if cache else None,
                sma_50=float(cache.sma_50) if cache else None,
                sma_200=float(cache.sma_200) if cache else None,
                midline=(
                    float(cache.midline)
                    if cache and cache.midline is not None
                    else None
                ),
                atr=float(cache.atr) if cache and cache.atr is not None else None,
                upper_band=(
                    float(cache.upper_band)
                    if cache and cache.upper_band is not None
                    else None
                ),
                lower_band=(
                    float(cache.lower_band)
                    if cache and cache.lower_band is not None
                    else None
                ),
                band_position=(
                    float(cache.band_position)
                    if cache and cache.band_position is not None
                    else None
                ),
            )
        )
    response = PortfolioDataResponse(
        portfolio_id=portfolio.id,
        name=portfolio.name,
        monthly_budget=portfolio.monthly_budget,
        ma_window=portfolio.ma_window,
        holdings=holdings_out,
    )
    _stamp_activity(db, portfolio)
    return response


@app.get(
    "/portfolio/export",
    response_model=PortfolioExportResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_404_NOT_FOUND: ERROR_RESPONSES[status.HTTP_404_NOT_FOUND],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ],
    },
)
def portfolio_export(
    device_uuid: UUID,
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> PortfolioExportResponse:
    """Return every ``X-Device-UUID``-linked row stored on the backend.

    Implements GDPR Art. 20 (right to data portability), CCPA §1798.100
    (consumer right to know), and the export commitment made in
    ``docs/legal/privacy-policy.md`` §6. The body is a verbatim dump of
    the persisted schema — `Portfolio` columns plus the cascaded
    `Holding` rows — so the data subject receives the same fields the
    backend stores, not a recomputed view.

    Authentication mirrors every other protected route: a valid
    ``X-App-Attest`` header plus a ``device_uuid`` that resolves to an
    existing portfolio. Identity verification at the data-subject-rights
    level (Privacy Policy §6 "How to exercise these rights") is
    delegated to the iOS client, which only emits this request after
    reading the device UUID from the Keychain entry created at first
    launch.

    Reading the export stamps ``last_seen_at`` so an export call alone
    keeps the row out of the retention-purge sweep documented in
    ``docs/legal/data-retention.md`` — consistent with every other
    authenticated read of the portfolio surface.

    On success the handler also emits a structured ``vca.api`` INFO log
    entry (``event=dsr.export.portfolio …``) so a supervisory inspection
    has a server-side record that the GDPR Art. 20 / CCPA §1798.130(a)(3)
    request was honored (GDPR Art. 5(2) accountability + CCPA
    Regulations 11 CCR §7102(a) records-of-requests; issue #445). The
    line is redacted to the last-4 hex characters of the device UUID per
    the ``docs/legal/data-retention.md`` "Application logs" row, so the
    accountability surface inherits the 30-day journald retention floor
    rather than reopening the raw-identifier surface closed by #339.
    """
    try:
        portfolio = db.execute(
            select(Portfolio).where(Portfolio.device_uuid == device_uuid)
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        log.warning("portfolio export lookup failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    if portfolio is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.PORTFOLIO_NOT_FOUND,
            message="Portfolio not found for device.",
        )

    response = PortfolioExportResponse(
        generated_at=datetime.now(UTC),
        device_uuid=device_uuid,
        portfolio=PortfolioExport(
            portfolio_id=portfolio.id,
            name=portfolio.name,
            monthly_budget=portfolio.monthly_budget,
            ma_window=portfolio.ma_window,
            created_at=portfolio.created_at,
            last_seen_at=portfolio.last_seen_at,
            holdings=[
                PortfolioExportHolding(
                    ticker=holding.ticker,
                    weight=holding.weight,
                )
                for holding in portfolio.holdings
            ],
        ),
    )
    # GDPR Art. 5(2) accountability + CCPA Regulations 11 CCR §7102(a)
    # records-of-requests obligation (issue #445): emit a structured
    # audit-log line on every successful export so a supervisory
    # inspection can demonstrate the controller honored the data-
    # portability request. ``redact_device_uuid`` shares the apns.py
    # redaction floor (last-4 hex only) — the raw UUID must never reach
    # journald per ``docs/legal/data-retention.md`` "Application logs".
    log.info(
        "event=dsr.export.portfolio device_uuid_suffix=%s "
        "portfolio_id=%s holdings_count=%d",
        redact_device_uuid(device_uuid),
        portfolio.id,
        len(portfolio.holdings),
    )
    _stamp_activity(db, portfolio)
    return response


@app.post(
    "/portfolio/holdings",
    status_code=status.HTTP_202_ACCEPTED,
    # The 202 success path returns a bare ``Response(status_code=202)`` (see
    # the fire-and-forget completion below). ``response_class=Response`` tells
    # FastAPI's OpenAPI generator to omit the default ``application/json``
    # success body so the contract matches the empty wire shape — same
    # treatment we already apply to ``DELETE /portfolio/holdings/{ticker}``
    # and ``DELETE /portfolio``. See issue #303.
    response_class=Response,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_404_NOT_FOUND: ERROR_RESPONSES[status.HTTP_404_NOT_FOUND],
        status.HTTP_409_CONFLICT: ERROR_RESPONSES[status.HTTP_409_CONFLICT],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ],
    },
)
def add_holding(
    payload: AddHoldingRequest,
    background: BackgroundTasks,
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> Response:
    """Add a holding to the calling device's portfolio.

    If the ticker is not yet in ``stock_cache`` the request schedules an
    asyncio background task that fetches the ticker from Polygon and
    pushes via APNs once the cache is populated. The response is
    ``202 Accepted`` either way — the client shows a spinner until the
    APNs push arrives.
    """
    try:
        portfolio = db.execute(
            select(Portfolio).where(Portfolio.device_uuid == payload.device_uuid)
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        log.warning("portfolio lookup failed while adding holding: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    if portfolio is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.PORTFOLIO_NOT_FOUND,
            message="Portfolio not found for device.",
        )

    try:
        existing_holding = db.execute(
            select(Holding).where(
                Holding.portfolio_id == portfolio.id,
                Holding.ticker == payload.ticker,
            )
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        log.warning("holding conflict lookup failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    if existing_holding is not None:
        raise ApiError(
            status_code=status.HTTP_409_CONFLICT,
            code=ErrorCode.CONFLICT_DETECTED,
            message="Holding already exists for portfolio.",
        )

    db.add(
        Holding(
            portfolio_id=portfolio.id,
            ticker=payload.ticker,
            weight=payload.weight,
        )
    )
    portfolio.last_seen_at = datetime.now(UTC)
    try:
        db.commit()
    except SQLAlchemyError as exc:
        db.rollback()
        log.warning("holding insert failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    try:
        cached = db.get(StockCache, payload.ticker) is not None
    except SQLAlchemyError as exc:
        log.warning("stock cache lookup failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    if not cached:
        background.add_task(
            _fetch_new_ticker, payload.ticker, payload.device_uuid
        )

    return Response(status_code=status.HTTP_202_ACCEPTED)


# ---------------------------------------------------------------------------
# Right-to-rectification (GDPR Art. 16 / CCPA §1798.106) — see issue #374
# ---------------------------------------------------------------------------
def _load_portfolio_or_503(db: Session, device_uuid: UUID) -> Portfolio | None:
    """Resolve a portfolio by device UUID, raising 503 on DB failure.

    Returns ``None`` when the row does not exist so the caller can emit
    the canonical ``portfolioNotFound`` envelope. Keeps the rectification
    handlers' error mapping consistent with the rest of the module.
    """
    try:
        return db.execute(
            select(Portfolio).where(Portfolio.device_uuid == device_uuid)
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        log.warning("portfolio rectification lookup failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc


def _commit_or_503(db: Session, context: str) -> None:
    """Commit the active transaction, mapping driver errors to 503."""
    try:
        db.commit()
    except SQLAlchemyError as exc:
        db.rollback()
        log.warning("%s failed: %s", context, exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc


@app.patch(
    "/portfolio",
    response_model=PatchPortfolioResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_404_NOT_FOUND: ERROR_RESPONSES[status.HTTP_404_NOT_FOUND],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ],
    },
)
def patch_portfolio(
    device_uuid: UUID,
    payload: PatchPortfolioRequest,
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> PatchPortfolioResponse:
    """Correct one or more scalar fields on the calling device's portfolio.

    Implements the scalar half of GDPR Art. 16 (right to rectification),
    CCPA §1798.106 (right to correct), and the rectification commitment
    referenced in ``docs/legal/privacy-policy.md`` §6. The companion
    holding-level path is ``PATCH /portfolio/holdings/{ticker}`` and the
    typo-correction path is ``DELETE /portfolio/holdings/{ticker}``.

    Only fields the client supplies are written; absent fields are
    preserved verbatim. ``ma_window`` is validated against the
    documented allow-list before the database CheckConstraint sees it
    so the client receives a precise ``unsupportedMovingAverageWindow``
    envelope rather than a generic 422.

    On success ``last_seen_at`` is stamped so a rectification call
    alone keeps the row out of the retention-purge sweep documented in
    ``docs/legal/data-retention.md`` — consistent with every other
    authenticated touch.

    On success the handler also emits a structured ``vca.api`` INFO log
    entry (``event=dsr.rectification.portfolio …``) so a supervisory
    inspection has a server-side record that the GDPR Art. 16 / CCPA
    §1798.106 request was honored (GDPR Art. 5(2) accountability + CCPA
    Regulations 11 CCR §7102(a) records-of-requests; issue #457 — the
    write-side counterpart to issue #445's read-side export trail). The
    line is redacted to the last-4 hex characters of the device UUID per
    the ``docs/legal/data-retention.md`` "Application logs" row.
    """
    portfolio = _load_portfolio_or_503(db, device_uuid)
    if portfolio is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.PORTFOLIO_NOT_FOUND,
            message="Portfolio not found for device.",
        )

    if (
        payload.ma_window is not None
        and payload.ma_window not in SUPPORTED_MA_WINDOWS
    ):
        raise ApiError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code=ErrorCode.UNSUPPORTED_MA_WINDOW,
            message=(
                "ma_window must be one of "
                f"{sorted(SUPPORTED_MA_WINDOWS)}."
            ),
        )

    fields_changed: list[str] = []
    if payload.name is not None:
        portfolio.name = payload.name
        fields_changed.append("name")
    if payload.monthly_budget is not None:
        portfolio.monthly_budget = payload.monthly_budget
        fields_changed.append("monthly_budget")
    if payload.ma_window is not None:
        portfolio.ma_window = payload.ma_window
        fields_changed.append("ma_window")
    portfolio.last_seen_at = datetime.now(UTC)
    portfolio_id = portfolio.id
    _commit_or_503(db, "portfolio rectification commit")
    # GDPR Art. 5(2) accountability + CCPA Regulations 11 CCR §7102(a)
    # records-of-requests obligation (issue #457): emit the audit line
    # AFTER the commit so a failed transaction never leaves a misleading
    # "honored" record. The field set lists exactly the columns that
    # changed so an inspector can correlate a rectification against the
    # subject's complaint without re-quoting the values themselves
    # (GDPR Art. 25 data-protection-by-design — the changed *values*
    # remain in the database, not the log).
    log.info(
        "event=dsr.rectification.portfolio device_uuid_suffix=%s "
        "portfolio_id=%s fields=%s",
        redact_device_uuid(device_uuid),
        portfolio_id,
        ",".join(sorted(fields_changed)),
    )

    return PatchPortfolioResponse(
        portfolio_id=portfolio.id,
        name=portfolio.name,
        monthly_budget=portfolio.monthly_budget,
        ma_window=portfolio.ma_window,
    )


@app.patch(
    "/portfolio/holdings/{ticker}",
    response_model=PatchHoldingResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_404_NOT_FOUND: ERROR_RESPONSES[status.HTTP_404_NOT_FOUND],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ],
    },
)
def patch_holding(
    ticker: str,
    device_uuid: UUID,
    payload: PatchHoldingRequest,
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> PatchHoldingResponse:
    """Correct the weight on a single holding row.

    Renaming a holding (typo on ``ticker``) goes through
    ``DELETE /portfolio/holdings/{ticker}`` followed by
    ``POST /portfolio/holdings``: ``ticker`` is part of the row's
    natural key (unique within a portfolio) and changing it via PATCH
    would conflict with the same uniqueness invariant guarded by
    ``POST``'s 409 path.

    Returns the persisted ``ticker`` + ``weight`` after commit so the
    iOS client can confirm its local state. Market-data fields are
    intentionally excluded — ``GET /portfolio/data`` is the canonical
    enriched view.

    On success the handler also emits a structured ``vca.api`` INFO log
    entry (``event=dsr.rectification.holding …``) so a supervisory
    inspection has a server-side record that the GDPR Art. 16 / CCPA
    §1798.106 request was honored (GDPR Art. 5(2) accountability + CCPA
    Regulations 11 CCR §7102(a) records-of-requests; issue #457). The
    line is redacted to the last-4 hex characters of the device UUID
    per the ``docs/legal/data-retention.md`` "Application logs" row;
    the corrected weight itself is **not** logged (it lives in the
    database row, the system of record).
    """
    portfolio = _load_portfolio_or_503(db, device_uuid)
    if portfolio is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.PORTFOLIO_NOT_FOUND,
            message="Portfolio not found for device.",
        )

    try:
        holding = db.execute(
            select(Holding).where(
                Holding.portfolio_id == portfolio.id,
                Holding.ticker == ticker,
            )
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        log.warning("holding rectification lookup failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    if holding is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.HOLDING_NOT_FOUND,
            message="Holding not found for portfolio.",
        )

    holding.weight = payload.weight
    portfolio.last_seen_at = datetime.now(UTC)
    portfolio_id = portfolio.id
    rectified_ticker = holding.ticker
    _commit_or_503(db, "holding rectification commit")
    # GDPR Art. 5(2) accountability + CCPA Regulations 11 CCR §7102(a)
    # records-of-requests obligation (issue #457): emit AFTER commit so
    # a failed write never leaves a misleading "honored" record.
    log.info(
        "event=dsr.rectification.holding device_uuid_suffix=%s "
        "portfolio_id=%s ticker=%s",
        redact_device_uuid(device_uuid),
        portfolio_id,
        rectified_ticker,
    )

    return PatchHoldingResponse(ticker=holding.ticker, weight=holding.weight)


@app.delete(
    "/portfolio/holdings/{ticker}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_404_NOT_FOUND: ERROR_RESPONSES[status.HTTP_404_NOT_FOUND],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ],
    },
)
def delete_holding(
    ticker: str,
    device_uuid: UUID,
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> Response:
    """Remove a single holding from the calling device's portfolio.

    Supplies the ticker-typo correction path for GDPR Art. 16 /
    CCPA §1798.106 (issue #374): a row whose ``ticker`` is wrong
    cannot be PATCHed (``ticker`` is part of the row's natural key);
    it must be removed and re-added via ``POST /portfolio/holdings``.
    This DELETE is **not** the broader erasure mechanism tracked in
    issue #329 — it scopes strictly to one ``(portfolio, ticker)``
    pair and leaves every other row, including the parent portfolio,
    untouched.

    On success the handler also emits a structured ``vca.api`` INFO log
    entry (``event=dsr.row_delete.holding …``) so a supervisory
    inspection has a server-side record that the GDPR Art. 16 /
    Art. 17 (row-scoped) / CCPA §1798.105 (row-scoped) request was
    honored (GDPR Art. 5(2) accountability + CCPA Regulations 11 CCR
    §7102(a) records-of-requests; issue #457). The event name is
    distinct from ``dsr.erasure.full_account`` (``DELETE /portfolio``)
    so an inspector can separate row-scoped corrections from
    full-account erasures in the same journald window. The line is
    redacted to the last-4 hex characters of the device UUID per the
    ``docs/legal/data-retention.md`` "Application logs" row.
    """
    portfolio = _load_portfolio_or_503(db, device_uuid)
    if portfolio is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.PORTFOLIO_NOT_FOUND,
            message="Portfolio not found for device.",
        )

    try:
        holding = db.execute(
            select(Holding).where(
                Holding.portfolio_id == portfolio.id,
                Holding.ticker == ticker,
            )
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        log.warning("holding delete lookup failed: %s", exc)
        raise ApiError(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.SYNC_UNAVAILABLE,
            message="Database is unreachable.",
            retry_after_seconds=60,
        ) from exc

    if holding is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.HOLDING_NOT_FOUND,
            message="Holding not found for portfolio.",
        )

    db.delete(holding)
    portfolio.last_seen_at = datetime.now(UTC)
    portfolio_id = portfolio.id
    deleted_ticker = holding.ticker
    _commit_or_503(db, "holding delete commit")
    # GDPR Art. 5(2) accountability + CCPA Regulations 11 CCR §7102(a)
    # records-of-requests obligation (issue #457): emit AFTER commit so
    # a failed delete never leaves a misleading "honored" record. The
    # event name is deliberately ``dsr.row_delete.holding`` — not the
    # account-level ``dsr.erasure.full_account`` — so inspectors can
    # separate row-scoped typo corrections (Art. 16 path) from
    # full-account erasures (Art. 17 path) in the same journald window.
    log.info(
        "event=dsr.row_delete.holding device_uuid_suffix=%s "
        "portfolio_id=%s ticker=%s",
        redact_device_uuid(device_uuid),
        portfolio_id,
        deleted_ticker,
    )

    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------------------------------------------------------------------------
# Right-to-erasure (GDPR Art. 17 / CCPA §1798.105) — see issue #450
# ---------------------------------------------------------------------------
@app.delete(
    "/portfolio",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    responses={
        status.HTTP_401_UNAUTHORIZED: ERROR_RESPONSES[
            status.HTTP_401_UNAUTHORIZED
        ],
        status.HTTP_404_NOT_FOUND: ERROR_RESPONSES[status.HTTP_404_NOT_FOUND],
        status.HTTP_422_UNPROCESSABLE_ENTITY: ERROR_RESPONSES[
            status.HTTP_422_UNPROCESSABLE_ENTITY
        ],
        status.HTTP_503_SERVICE_UNAVAILABLE: ERROR_RESPONSES[
            status.HTTP_503_SERVICE_UNAVAILABLE
        ],
    },
)
def delete_portfolio(
    device_uuid: UUID,
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> Response:
    """Erase every ``X-Device-UUID``-linked row for the calling device.

    Implements GDPR Art. 17 (right to erasure / right to be forgotten),
    CCPA §1798.105 (right to delete), and the erasure commitment
    referenced in ``docs/legal/privacy-policy.md`` §6 — the
    backend-side prerequisite for the iOS Settings "Erase All My Data"
    flow tracked under issue #329.

    Cascade-deletes the resolved ``Portfolio`` row and, via the
    ``Holding.portfolio_id`` FK ``ON DELETE CASCADE`` and the
    ``Portfolio.holdings`` ``delete-orphan`` relationship cascade
    (``backend/db/models.py``), every ``Holding`` keyed to it. The
    cache-only ``StockCache`` table is **not** touched — ticker market
    data is not personal data and is shared across devices.

    Unlike every other authenticated endpoint, this handler
    deliberately does **not** stamp ``last_seen_at``: the row is
    being removed in the same transaction, and a stamp would either
    no-op (if it runs first) or resurrect a freshly-deleted row (if
    it runs against an orphan reference). The retention-purge sweep
    documented in ``docs/legal/data-retention.md`` does not need a
    stamp here — the row is gone, which is a strictly stronger
    outcome than a stamp could provide.

    Scoped strictly to the calling device — the ``device_uuid`` query
    parameter is the only selector, and the row-scoped ``DELETE``
    contract for holdings (#374) is preserved orthogonally: an
    account-level erasure on device A cannot reach device B's rows.

    On success the handler also emits a structured ``vca.api`` INFO log
    entry (``event=dsr.erasure.full_account …``) so a supervisory
    inspection has a server-side record that the GDPR Art. 17 / CCPA
    §1798.105 request was honored (GDPR Art. 5(2) accountability + CCPA
    Regulations 11 CCR §7102(a) records-of-requests; issue #457). The
    ``holdings_count`` field captures how many cascaded ``Holding`` rows
    went with the parent portfolio so an inspector can correlate the
    erasure scope against a complainant's recollection without
    re-quoting the deleted personal data. The portfolio id and holdings
    count are captured **before** the commit because the ORM reference
    is detached afterwards. The line is redacted to the last-4 hex
    characters of the device UUID per the ``docs/legal/data-retention.md``
    "Application logs" row.
    """
    portfolio = _load_portfolio_or_503(db, device_uuid)
    if portfolio is None:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.PORTFOLIO_NOT_FOUND,
            message="Portfolio not found for device.",
        )

    # Snapshot the audit-log fields BEFORE the ORM-level delete so the
    # log line can be emitted post-commit even after the row + cascaded
    # holdings have been removed from the session.
    portfolio_id = portfolio.id
    holdings_count = len(portfolio.holdings)

    db.delete(portfolio)
    _commit_or_503(db, "portfolio erasure commit")
    # GDPR Art. 5(2) accountability + CCPA Regulations 11 CCR §7102(a)
    # records-of-requests obligation (issue #457): emit AFTER commit so
    # a failed erasure never leaves a misleading "honored" record. The
    # event name is deliberately ``dsr.erasure.full_account`` — distinct
    # from the row-scoped ``dsr.row_delete.holding`` — so inspectors can
    # separate Art. 17 right-to-be-forgotten erasures from Art. 16
    # ticker-typo corrections in the same journald window.
    log.info(
        "event=dsr.erasure.full_account device_uuid_suffix=%s "
        "portfolio_id=%s holdings_count=%d",
        redact_device_uuid(device_uuid),
        portfolio_id,
        holdings_count,
    )

    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------------------------------------------------------------------------
# Background tasks
# ---------------------------------------------------------------------------
async def _fetch_new_ticker(ticker: str, device_uuid: UUID) -> None:
    """Populate ``stock_cache`` for a brand-new ticker, then APNs-push.

    This is the **only** code path in vca-api that calls Polygon. It is
    deliberately kept thin so the same fetch/push helpers can be reused
    by ``backend/poller`` — the implementations live in
    :mod:`poller.polygon` and :mod:`poller.apns` to keep this module
    free of network code at import time.
    """
    # Imported lazily to avoid pulling Polygon / APNs deps into the API
    # process at startup, and to break the api → poller import cycle.
    from poller.apns import push_to_device  # noqa: WPS433
    from poller.polygon import fetch_and_cache_ticker  # noqa: WPS433

    try:
        await fetch_and_cache_ticker(ticker)
        await push_to_device(device_uuid)
    except Exception:  # noqa: BLE001 — log and swallow; client retries via spinner timeout
        log.exception("background fetch for new ticker %s failed", ticker)
