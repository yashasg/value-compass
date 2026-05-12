# backend/db

Database layer for value-compass. Provider: **Supabase (Postgres)**, free
tier, hosted on AWS `us-east-1`.

## Layout

```
backend/db/
  models.py            # SQLAlchemy models (Portfolio, Holding, StockCache)
  migrations/
    env.py             # Alembic environment
    script.py.mako     # Migration template
    versions/          # Migration files
```

## Schema

| Table         | Purpose                                                 |
|---------------|---------------------------------------------------------|
| `portfolios`  | One row per device-owned portfolio.                     |
| `holdings`    | Per-portfolio ticker weights (`portfolios 1──* holdings`). |
| `stock_cache` | One row per ticker, refreshed nightly by the poller.    |

See `models.py` and the issue spec for the full column list.

## Principles

- No user accounts — `device_uuid` is the owner identifier, stored in the
  iOS Keychain.
- `stock_cache` is append-never, update-only — one row per ticker.
- `next_modified` is only written when `job_status = 'success'`.
- Migrations managed by Alembic, run before every deploy.
- Schema changes are **additive only** — columns are added, never removed
  or renamed.

## Running migrations

The DB URL is read from the `DATABASE_URL` environment variable (so no
credentials are committed):

```bash
export DATABASE_URL=postgresql+psycopg2://user:pass@host:5432/postgres

# From the repo root:
alembic upgrade head             # apply all migrations
alembic revision -m "add column" # create a new migration (additive only)
```
