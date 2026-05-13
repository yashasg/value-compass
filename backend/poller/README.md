# backend/poller — vca-poller

APScheduler job. Fetches stock data from Polygon and writes to Postgres,
then sends an APNs push to affected devices on completion. The poller is
the **only** writer to `stock_cache`.

Runs as systemd service: **`vca-poller.service`** (see `backend/infra/systemd/`).

## Schedule

- Fires at **5:00 PM ET**.
- Trading days only (`pandas_market_calendars`).
- Skips weekends and market holidays.

## Job Steps

1. Fetch the latest daily OHLC bars for each tracked ticker (Polygon
   aggregates endpoint, N requests, 5 req/min).
2. Sort bars ascending, keep the latest 22 bars, and compute the 21-bar
   midline, ATR, upper/lower bands, current close, and band position.
3. Write results to `stock_cache`.
4. Set `job_status = success`.
5. Update `last_modified` and `next_modified`.
6. Send APNs push to affected devices.

The 5 req/min rate limit on the aggregates endpoint is the binding constraint
on the job's wall-clock duration.

## Failure Behaviour

- On any failure: `job_status = failed`.
- `last_modified` and `next_modified` are **not** updated. Clients
  remain within their cached window and do not retry-storm.
- Alert fires if `last_modified` is stale beyond **26 hours** (one
  trading day plus a 2-hour grace window).

This is intentional: the API keeps serving the last successful snapshot
rather than erroring, and the alert — not the client — is what surfaces
a stuck poller.

## New Ticker Flow

The poller is also indirectly triggered by `vca-api` when a device adds
a ticker not yet in `stock_cache`. In that path the fetch is performed
inline by the API process as an asyncio background task — see
`backend/api/README.md`. The nightly poller then takes over the ticker
on its next scheduled run.

## External Dependencies

| Service     | Purpose                          | Tier |
|-------------|----------------------------------|------|
| Polygon.io  | Daily OHLC bars                  | Free |
| Supabase    | Postgres database (writer)       | Free |
| Apple APNs  | Push notifications on completion | Free |
