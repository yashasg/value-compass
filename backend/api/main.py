"""FastAPI application for vca-api.

Implements the endpoints documented in ``backend/api/README.md`` and the
original services spec:

* ``GET  /health``              — liveness + DB reachability
* ``GET  /portfolio/status``    — last_modified / next_modified, cacheable
* ``GET  /portfolio/data``      — full portfolio allocation for the device
* ``GET  /schema/version``      — current API schema version
* ``POST /portfolio/holdings``  — add a ticker; queues a background fetch

The app reads from Postgres only and **never** calls Polygon directly,
with one explicit exception: ``POST /portfolio/holdings`` queues an
asyncio background task to populate ``stock_cache`` for a brand-new
ticker — see the New Ticker Flow in the README.
"""

from __future__ import annotations

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
from pydantic import BaseModel, ConfigDict, Field, PlainSerializer, WithJsonSchema
from sqlalchemy import select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from common import config
from common import db as common_db
from db.models import Holding, Portfolio, StockCache

log = logging.getLogger("vca.api")


class ErrorCode(StrEnum):
    """Stable machine-readable error codes for clients."""

    APP_ATTEST_MISSING = "appAttestMissing"
    CONFLICT_DETECTED = "conflictDetected"
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

    app.openapi_schema = openapi_schema
    return app.openapi_schema


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
        ]
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
        ]
    },
)
def portfolio_status(
    db: Session = Depends(get_db),
    _: str = Depends(require_app_attest),
) -> PortfolioStatusResponse:
    """Return the freshest ``last_modified`` / ``next_modified``.

    The cache response is lightweight and Cloudflare-cacheable.
    """
    row = db.execute(
        select(StockCache.last_modified, StockCache.next_modified)
        .order_by(StockCache.last_modified.desc())
        .limit(1)
    ).first()
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
    return PortfolioDataResponse(
        portfolio_id=portfolio.id,
        name=portfolio.name,
        monthly_budget=portfolio.monthly_budget,
        ma_window=portfolio.ma_window,
        holdings=holdings_out,
    )


@app.post(
    "/portfolio/holdings",
    status_code=status.HTTP_202_ACCEPTED,
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
