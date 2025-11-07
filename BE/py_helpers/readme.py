# readme.py
import os
from typing import Optional, Tuple, List

CANDIDATES: List[str] = [
    "README.md", "readme.md", "README", "Readme.md",
    "README.rst", "readme.rst", "README.txt", "readme.txt",
    "README.adoc", "readme.adoc",
]

def find_readme(root: str) -> Optional[str]:
    """
    Find a README-like file in the repo root or shallow subdirs (depth <= 2).
    Returns the path if found, else None.
    """
    root = os.path.abspath(root)
    # check root-level candidates first
    for c in CANDIDATES:
        p = os.path.join(root, c)
        if os.path.exists(p):
            return p

    # shallow walk (depth <= 2)
    for dirpath, _, filenames in os.walk(root):
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
    Read text file safely (UTF-8 with ignore) and cap length for LLM prompts.
    Returns empty string if missing/unreadable.
    """
    if not path or not os.path.exists(path):
        return ""
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            text = f.read(max_chars)
        return text.lstrip("\ufeff")
    except Exception:
        return ""

def load_readme(root: str, max_chars: int = 20000) -> Tuple[Optional[str], str]:
    """
    Convenience: find + read. Returns (path, text).
    """
    p = find_readme(root)
    if not p:
        return None, ""
    return p, read_text_safe(p, max_chars)

# Aliases for Jac import consistency
find_readme_files = find_readme
summarize_readme = read_text_safe
