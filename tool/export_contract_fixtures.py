"""Refresh synthetic HTTP samples in project cache; never accepts a database URL.

Run with uv and the reference server's existing project-local environment as
specified in docs/implementation/acceptance.md. No dependencies are installed.
"""
import asyncio
import hashlib
import json
import subprocess
import sys
from contextlib import AsyncExitStack, aclosing, closing
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "MileafServer"
sys.path[:0] = [str(SERVER / "src"), str(SERVER)]

STAGE = "imports"
EXPECTED_COMMIT = "146cb3b9a16af3d632b04ed8d197d0f2243d9b71"
ENDPOINTS = [
    ("meta", "/v1/meta", {}),
    ("vehicles", "/v1/vehicles", {}),
    ("summary", "/v1/vehicles/1/summary", {"tz": "Asia/Shanghai"}),
    ("drives", "/v1/vehicles/1/drives", {"limit": 2}),
    ("drive-detail", "/v1/drives/1", {}),
    ("drive-series", "/v1/drives/1/series", {"fields": "speed,battery,elevation", "points": 24}),
    ("drive-empty-series", "/v1/drives/13/series", {}),
    ("charging-sessions", "/v1/vehicles/1/charging-sessions", {"limit": 2}),
    ("charging-detail", "/v1/charging-sessions/1", {}),
    ("charging-active", "/v1/charging-sessions/8", {}),
    ("charging-series", "/v1/charging-sessions/1/series", {"fields": "power,soc", "points": 24}),
    ("driving-stats", "/v1/vehicles/1/stats", {"kind": "driving", "bucket": "month", "from": "2026-01-01T00:00:00Z", "to": "2026-04-01T00:00:00Z", "tz": "Asia/Shanghai"}),
    ("charging-stats", "/v1/vehicles/1/stats", {"kind": "charging", "bucket": "month", "from": "2026-01-01T00:00:00Z", "to": "2026-04-01T00:00:00Z", "tz": "Asia/Shanghai"}),
]


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


async def run():
    global STAGE
    import httpx
    from mileaf.app import create_app
    from mileaf.config import Settings
    from mileaf.dependencies import get_now
    from tests import conftest as fixtures

    STAGE = "server revision"
    commit = subprocess.check_output(["git", "-C", str(SERVER), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(SERVER), "status", "--porcelain"], text=True).strip()
    if commit != EXPECTED_COMMIT or dirty:
        raise RuntimeError("Reference server changed; review and refreeze the contract first")
    output = ROOT / ".cache" / "contract-refresh"
    output.mkdir(parents=True, exist_ok=True)
    # These fixture factories only create their own local Docker PostgreSQL.
    # ExitStack unwinds app, reader, connection, database and container in order.
    async with AsyncExitStack() as stack:
        STAGE = "container"
        container = stack.enter_context(closing(fixtures.postgres_container.__wrapped__()))
        container_url = next(container)
        STAGE = "database"
        admin = await stack.enter_async_context(aclosing(fixtures.admin_dsn.__wrapped__(container_url)))
        admin_url = await anext(admin)
        db = await stack.enter_async_context(aclosing(fixtures.db.__wrapped__(admin_url)))
        connection = await anext(db)
        reader = await stack.enter_async_context(aclosing(fixtures.database_dsn.__wrapped__(connection, admin_url)))
        reader_url = await anext(reader)
        scratch = stack.enter_context(TemporaryDirectory(prefix="auth-", dir=output))
        STAGE = "app construction"
        app = create_app(Settings(database_dsn=reader_url, state_file=Path(scratch) / "state.json"))
        app.dependency_overrides[get_now] = lambda: fixtures.FIXED_NOW
        STAGE = "OpenAPI comparison"
        frozen = json.loads((ROOT / "docs/contracts/openapi-v1.json").read_text())
        if app.openapi() != frozen:
            raise RuntimeError("Runtime OpenAPI differs from the frozen contract")
        STAGE = "app startup"
        await stack.enter_async_context(app.router.lifespan_context(app))
        client = await stack.enter_async_context(httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test"))
        STAGE = "authentication"
        password = "synthetic fixture access password"
        setup = await client.post("/v1/auth/setup", json={"password": password})
        if setup.status_code != 200:
            raise RuntimeError("Synthetic setup failed")
        login = await client.post("/v1/auth/login", json={"password": password})
        if login.status_code != 200:
            raise RuntimeError("Synthetic login failed")
        client.headers["Authorization"] = "Bearer " + login.json()["token"]
        STAGE = "business endpoints"
        manifest = []
        for name, path, params in ENDPOINTS:
            response = await client.get(path, params=params)
            if response.status_code != 200:
                raise RuntimeError("Synthetic endpoint contract failed")
            write_json(output / f"{name}.json", response.json())
            manifest.append({"name": name, "path": path, "params": params, "status": 200})
        write_json(output / "source.json", {
            "synthetic": True, "serverCommit": commit,
            "fixedNow": fixtures.FIXED_NOW.isoformat(),
            "method": "Actual authenticated HTTP ASGI + isolated PostgreSQL. No credentials exported.",
            "openapiSha256": hashlib.sha256((ROOT / "docs/contracts/openapi-v1.json").read_bytes()).hexdigest(),
            "responses": manifest,
        })
    print("CONTRACT_REFRESH_OK: 13 synthetic responses; frozen OpenAPI unchanged; fixture resources stopped")


if __name__ == "__main__":
    try:
        asyncio.run(run())
    except BaseException as error:
        # Do not expose connection strings, auth state or HTTP body in tracebacks.
        print(f"Stage: {STAGE}; exception type: {type(error).__name__}", file=sys.stderr)
        print("CONTRACT_REFRESH_FAILED: verify frozen server, existing uv environment and cached Docker image", file=sys.stderr)
        raise SystemExit(1) from None
