
import os
from typing import Optional


CANDIDATES = [
    "README.md", "readme.md", "README", "Readme.md", "README.rst", "readme.rst"
]


def find_readme(root: str) -> Optional[str]:
    """
    Find a README-like file in the root or shallow subdirs (depth <= 2).
    """
    root = os.path.abspath(root)
    for c in CANDIDATES:
        p = os.path.join(root, c)
        if os.path.exists(p):
            return p

    for dirpath, _, filenames in os.walk(root):
        # depth guard
        rel = os.path.relpath(dirpath, root)
        depth = 0 if rel == "." else len(rel.split(os.sep))
        if depth > 2:
            continue

        for f in filenames:
            if f.lower().startswith("readme"):
                return os.path.join(dirpath, f)
    return None


def read_text_safe(path: str, max_chars: int = 20000) -> str:
    """
    Read a text file safely with utf-8 fallback, and cap length for LLM prompts.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()[:max_chars]
    except Exception:
        return ""
