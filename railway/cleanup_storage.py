"""Hourly storage cleanup for the Railway deployment.

SupoClip keeps every uploaded source video (clip edits re-render from it) and
leaves clip files on disk when a generation or clip is deleted. On a small
Railway volume that eventually fills the disk, so this script:

- deletes uploaded sources, exports and editor workspaces untouched for
  UPLOAD_RETENTION_DAYS (default 7); clips stay editable until then,
- deletes clip files that no generated_clips row references any more,
- removes the openai-whisper model cache while faster-whisper is in use.

Anything that depends on the database is skipped if the database is down.
"""

import asyncio
import hashlib
import importlib.util
import os
import shutil
import time
from pathlib import Path

import asyncpg

# Clips are rendered to disk before their row is inserted, so a file without a
# row is only treated as orphaned once it is clearly not part of a running job.
ORPHAN_GRACE_SECONDS = 2 * 3600
UPLOAD_PREFIX = "upload://"


def _stem(path: Path) -> str:
    # Sidecars share the clip's stem: clip_1_x.mp4, clip_1_x.source_map.json
    return path.name.split(".", 1)[0]


def _last_modified(path: Path) -> float:
    if path.is_file():
        return path.stat().st_mtime
    times = [p.stat().st_mtime for p in path.rglob("*") if p.is_file()]
    return max(times, default=path.stat().st_mtime)


def _size(path: Path) -> int:
    if path.is_file():
        return path.stat().st_size
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def _remove(path: Path, reason: str) -> int:
    size = _size(path)
    if path.is_dir():
        shutil.rmtree(path, ignore_errors=True)
    else:
        path.unlink(missing_ok=True)
    print(f"Removed {path} ({size / 1e6:.1f} MB, {reason})", flush=True)
    return size


async def _load_references() -> tuple[list[asyncpg.Record], set[str]]:
    url = os.environ["DATABASE_URL"].replace("postgresql+asyncpg://", "postgresql://", 1)
    conn = await asyncpg.connect(url, timeout=30)
    try:
        clips = await conn.fetch("SELECT task_id, id, filename, file_path FROM generated_clips")
        active_sources = await conn.fetch(
            """
            SELECT s.url FROM tasks t JOIN sources s ON s.id = t.source_id
            WHERE t.status IN ('queued', 'processing')
            """
        )
    finally:
        await conn.close()
    active_uploads = {
        _stem(Path(row["url"].removeprefix(UPLOAD_PREFIX)))
        for row in active_sources
        if row["url"] and row["url"].startswith(UPLOAD_PREFIX)
    }
    return clips, active_uploads


def main() -> None:
    work_dir = Path(os.environ.get("TEMP_DIR", "/data/work"))
    retention = float(os.getenv("UPLOAD_RETENTION_DAYS", "7")) * 86400
    now = time.time()
    freed = 0

    try:
        clips, active_uploads = asyncio.run(_load_references())
    except Exception as exc:
        print(f"Storage cleanup: database unavailable ({exc}); skipping clip and upload cleanup")
        clips, active_uploads = None, None

    if clips is not None:
        uploads = work_dir / "uploads"
        if uploads.is_dir():
            for path in uploads.iterdir():
                if path.is_file() and _stem(path) not in active_uploads:
                    if now - _last_modified(path) > retention:
                        freed += _remove(path, "upload past retention")

        referenced = {_stem(Path(row["filename"])) for row in clips} | {
            _stem(Path(row["file_path"])) for row in clips
        }
        clips_dir = work_dir / "clips"
        if clips_dir.is_dir():
            for path in clips_dir.rglob("*"):
                if path.is_file() and _stem(path) not in referenced:
                    if now - _last_modified(path) > ORPHAN_GRACE_SECONDS:
                        freed += _remove(path, "clip no longer referenced")

        # Mirrors editor_document.editor_dir().
        editor_keys = {
            hashlib.sha256(f"{row['task_id']}:{row['id']}:{row['filename']}".encode()).hexdigest()
            for row in clips
        }
        editor = work_dir / "editor"
        if editor.is_dir():
            for path in editor.iterdir():
                age = now - _last_modified(path)
                if age > retention or (path.name not in editor_keys and age > ORPHAN_GRACE_SECONDS):
                    freed += _remove(path, "editor workspace")

    exports = work_dir / "exports"
    if exports.is_dir():
        for path in exports.iterdir():
            if now - _last_modified(path) > retention:
                freed += _remove(path, "export past retention")

    engine = os.getenv("WHISPER_ENGINE", "auto").strip().lower()
    whisper_cache = Path(os.environ.get("XDG_CACHE_HOME", "/data/cache")) / "whisper"
    uses_faster_whisper = engine == "faster-whisper" or (
        engine != "openai-whisper" and importlib.util.find_spec("faster_whisper") is not None
    )
    if uses_faster_whisper and whisper_cache.is_dir():
        freed += _remove(whisper_cache, "unused openai-whisper model")

    print(f"Storage cleanup done, freed {freed / 1e6:.1f} MB", flush=True)


if __name__ == "__main__":
    main()
