import threading
from pathlib import Path
from ..config import get_settings

_lock = threading.Lock()
_running = False


def is_running():
    return _running


def run_sync():
    global _running
    if not _lock.acquire(blocking=False):
        return
    _running = True
    try:
        from etl.pipeline import run

        s = get_settings()
        run(s.etl_config_path)
    finally:
        _running = False
        _lock.release()
