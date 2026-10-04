"""Apply init.sql to an empty database before the API starts.

docker-compose mounts init.sql into the Postgres entrypoint so it runs on first
boot. Railway's managed Postgres has no equivalent hook, so this script does it
once: if the ``users`` table already exists it leaves the database alone.
"""

import asyncio
import os
from pathlib import Path

import asyncpg

INIT_SQL = Path(__file__).with_name("init.sql")


async def connect(url: str) -> asyncpg.Connection:
    for _ in range(30):
        try:
            return await asyncpg.connect(url)
        except (OSError, asyncpg.PostgresError) as exc:
            print(f"Waiting for Postgres: {exc}", flush=True)
            await asyncio.sleep(2)
    raise SystemExit("Postgres did not become reachable")


async def main() -> None:
    url = os.environ["DATABASE_URL"].replace("postgresql+asyncpg://", "postgresql://", 1)
    conn = await connect(url)
    try:
        if await conn.fetchval("SELECT to_regclass('public.users') IS NOT NULL"):
            print("Database schema already present", flush=True)
            return
        print("Empty database, applying init.sql", flush=True)
        # Without arguments asyncpg uses the simple query protocol, which runs
        # the whole multi-statement script as a single implicit transaction.
        await conn.execute(INIT_SQL.read_text())
        print("init.sql applied", flush=True)
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
