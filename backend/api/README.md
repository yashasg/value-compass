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
| GET    | `/portfolio/data`     | Full portfolio allocation for the device          | Only called on client cache miss.                  |
| GET    | `/schema/version`     | Current API schema version number                 |                                                    |
| POST   | `/portfolio/holdings` | `202 Accepted`, queues a background fetch         | See [New Ticker Flow](#new-ticker-flow).           |

## Response Headers

All responses set:

```
Cache-Control: max-age=3600
Last-Modified: <UTC timestamp>
X-Min-App-Version: <minimum supported iOS app version>
```

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
    │ writes to stock_cache
    ▼
APNs push → client dismisses spinner, renders allocation
```

The `POST /portfolio/holdings` handler is the **only** place in `vca-api`
that triggers a Polygon fetch, and it does so via an asyncio background
task — the request itself returns `202` immediately so the client is
never blocked.

## OpenAPI

The schema served at `/openapi.json` is exported to the repo-root
`openapi.json` and consumed by SwiftOpenAPIGenerator in the iOS client.
Never edit `openapi.json` manually.
