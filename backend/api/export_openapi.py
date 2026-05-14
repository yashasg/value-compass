"""Export and verify the FastAPI OpenAPI contract artifacts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from api.main import app

REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATHS = (
    REPO_ROOT / "openapi.json",
    REPO_ROOT / "app" / "Sources" / "Backend" / "Networking" / "openapi.json",
)


def render_openapi_contract() -> str:
    """Return the canonical OpenAPI document as deterministic JSON."""
    return json.dumps(app.openapi(), indent=2) + "\n"


def write_contracts(contract: str) -> None:
    """Write the canonical OpenAPI document to every checked-in artifact."""
    for path in CONTRACT_PATHS:
        path.write_text(contract, encoding="utf-8")


def check_contracts(contract: str) -> list[Path]:
    """Return checked-in contract artifacts that differ from FastAPI output."""
    return [
        path
        for path in CONTRACT_PATHS
        if not path.exists() or path.read_text(encoding="utf-8") != contract
    ]


def parse_args() -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Export or verify OpenAPI artifacts generated from FastAPI."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if checked-in OpenAPI artifacts are not current",
    )
    return parser.parse_args()


def main() -> int:
    """Run the OpenAPI export/check command."""
    args = parse_args()
    contract = render_openapi_contract()

    if args.check:
        stale_paths = check_contracts(contract)
        if stale_paths:
            print("OpenAPI artifacts are stale:")
            for path in stale_paths:
                print(f"  - {path.relative_to(REPO_ROOT)}")
            print(
                "Regenerate with: PYTHONPATH=backend "
                "python3 -m api.export_openapi"
            )
            return 1
        print("OpenAPI artifacts are current.")
        return 0

    write_contracts(contract)
    for path in CONTRACT_PATHS:
        print(f"Wrote {path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
