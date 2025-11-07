# io_utils.py
import os
import json
import tempfile
from typing import Any, Dict

# ---------------------------------------------------------------------
# Directory helpers
# ---------------------------------------------------------------------
def ensure_dirs(path: str) -> str:
    """Create directories recursively; return the path for chaining."""
    os.makedirs(path, exist_ok=True)
    return path

ensure_dir = ensure_dirs  # backward-compat alias


# ---------------------------------------------------------------------
# Text I/O
# ---------------------------------------------------------------------
def save_text(path: str, content: str) -> str:
    """
    Write text atomically to `path` (UTF-8). Creates parent dirs.
    Returns the written file path.
    """
    ensure_dirs(os.path.dirname(path) or ".")
    fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp_path, path)
    return path

write_text = save_text  # alias for legacy name


def read_text(path: str) -> str:
    """Read UTF-8 text file; returns empty string if missing."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return ""


# ---------------------------------------------------------------------
# JSON I/O
# ---------------------------------------------------------------------
def save_json(path: str, data: Dict[str, Any], *, indent: int = 2) -> str:
    """Save dict as JSON (UTF-8, pretty)."""
    ensure_dirs(os.path.dirname(path) or ".")
    fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=indent, ensure_ascii=False)
    os.replace(tmp_path, path)
    return path


def read_json(path: str) -> Dict[str, Any]:
    """Load JSON file safely; return {} if missing or invalid."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}
