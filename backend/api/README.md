# backend/api — vca-api

FastAPI application. Serves iOS clients. Reads from Postgres only and
**never** calls Polygon directly — all stock data is written by
`backend/poller` and read here.

Runs as systemd service: **`vca-api.service`** (see `backend/infra/systemd/`).

## Endpoints

| Method | Path                  | Response                                          | Notes                                              |
|--------|-----------------------|---------------------------------------------------|----------------------------------------------------|
| GET    | `/health`             | `200` if API and Postgres are reachable           | Liveness + DB reachability check.                  |
| GET    | `/portfolio/status`   | `last_modified`, `next_modified`                  | Lightweight, Cloudflare-cacheable.                 |
| GET    | `/portfolio/data`     | Full portfolio allocation + band metrics          | Only called on client cache miss.                  |
| GET    | `/schema/version`     | Current API schema version number                 |                                                    |
| POST   | `/portfolio/holdings` | `202 Accepted`, queues a background fetch         | See [New Ticker Flow](#new-ticker-flow).           |

## Response Headers

All responses set:

```
Cache-Control: max-age=3600
Last-Modified: <UTC timestamp>
X-Min-App-Version: <minimum supported iOS app version>
```

## Error Responses

Application and request-validation errors use a top-level structured envelope so
generated clients can branch on stable codes instead of parsing message text:

```json
{
  "code": "syncUnavailable",
  "message": "Database is unreachable.",
  "retry_after_seconds": 60
}
```

Common codes include `appAttestMissing`, `portfolioNotFound`,
`syncUnavailable`, `schemaUnsupported`, `conflictDetected`,
`lossyMappingRejected`, `stockDataPending`, `stockDataMissing`,
`stockDataStale`, and `unsupportedMovingAverageWindow`.

## Security

- App Attest header validated on every request.
- Rate limiting enforced at the Cloudflare layer.
- All responses Brotli-compressed by Cloudflare.

## New Ticker Flow

When a device adds a ticker not yet present in `stock_cache`:

```
Client adds ticker
    │
    ▼
POST /portfolio/holdings
    │ server queues asyncio background task
    ▼
202 Accepted → client shows spinner
    │
    ▼
Background task fetches from Polygon
    │ computes OHLC band metrics and writes to stock_cache
    ▼
APNs push → client dismisses spinner, renders allocation
```

The `POST /portfolio/holdings` handler is the **only** place in `vca-api`
that triggers a Polygon fetch, and it does so via an asyncio background
task — the request itself returns `202` immediately so the client is
never blocked.

## OpenAPI

FastAPI is the source of truth for the backend/iOS contract. The schema served
at `/openapi.json` is exported to the repo-root `openapi.json` and mirrored to
`app/Sources/Backend/Networking/openapi.json` for SwiftOpenAPIGenerator.

Regenerate both checked-in artifacts after changing API routes, response models,
documented response headers, or versioning:

```bash
PYTHONPATH=backend python3 -m api.export_openapi
```

CI verifies the artifacts with:

```bash
PYTHONPATH=backend python3 -m api.export_openapi --check
```

Never edit generated OpenAPI artifacts manually. Newly added response fields
must remain optional unless a schema-versioned breaking change is intentional.
The `X-Min-App-Version` response header and `/schema/version` endpoint are the
machine-readable compatibility signals for clients.

Generated clients see `X-App-Attest` as `required: true` on every protected
route (`/schema/version`, `/portfolio/status`, `/portfolio/data`,
`/portfolio/holdings`); `/health` is the only attestation-free endpoint.
The runtime accepts the header as optional in code and rejects missing values
with the documented `401 appAttestMissing` envelope so clients receive the
contract error rather than a generic 422.
