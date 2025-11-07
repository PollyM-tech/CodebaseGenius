
import os
from typing import Dict, List, Tuple, Optional

from tree_sitter import Parser
from tree_sitter_languages import get_parser


# Map extensions to the tree-sitter language "slugs" that tree_sitter_languages supports
SUPPORTED = {
    ".py": "python",
    # NOTE: Jac does not have an official grammar here. We treat it like generic text,
    # and still try to extract def/class/call tokens naively.
    ".jac": "python",  # best-effort scanning for names/defs
}


def collect_source_files(root: str) -> List[str]:
    """
    Collect source file paths for supported languages, skipping common junk dirs.
    """
    root = os.path.abspath(root)
    results: List[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        # prune
        dirnames[:] = [
            d for d in dirnames
            if d not in {".git", "node_modules", "__pycache__", ".venv", "venv", "dist", "build"}
        ]
        for f in filenames:
            ext = os.path.splitext(f)[1].lower()
            if ext in SUPPORTED:
                results.append(os.path.join(dirpath, f))
    return results


def parse_file(path: str) -> Optional[Tuple[object, bytes, str]]:
    """
    Parse file using tree-sitter (if supported). Returns (tree, src_bytes, lang_slug).
    """
    ext = os.path.splitext(path)[1].lower()
    lang_slug = SUPPORTED.get(ext)
    if not lang_slug:
        return None
    parser: Parser = get_parser(lang_slug)
    with open(path, "rb") as f:
        src = f.read()
    tree = parser.parse(src)
    return tree, src, lang_slug


def extract_symbols_and_calls(path: str) -> Dict[str, List[str]]:
    """
    Lightweight symbol/call extraction:
      - functions: lines starting with 'def <name>('
      - classes:   lines starting with 'class <Name>(' or 'class <Name>:'
      - calls:     occurrences of identifier followed by '(' (very naive)

    Works reliably for Python; Jac gets best-effort scanning.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            text = f.read()
    except Exception:
        return {"functions": [], "classes": [], "calls": []}

    functions: List[str] = []
    classes: List[str] = []
    calls: List[str] = []

    for raw in text.splitlines():
        line = raw.strip()
        # function defs
        if line.startswith("def ") and "(" in line:
            name = line.split("(")[0].replace("def ", "").strip()
            if name.isidentifier():
                functions.append(name)
        # class defs
        if line.startswith("class ") and ("(" in line or line.endswith(":")):
            name = line.split("(")[0].replace("class ", "").strip().rstrip(":")
            if name and all(ch.isidentifier() or ch == "." for ch in [name]):
                classes.append(name)
        # calls (skip obvious keywords)
        if "(" in line and ")" in line and not line.startswith("#"):
            token = line.split("(")[0].strip()
            if token.isidentifier() and token not in {
                "def", "class", "if", "for", "while", "return", "with", "await",
                "elif", "else", "match", "case", "lambda", "yield", "except", "finally", "try",
            }:
                calls.append(token)

    # Deduplicate while preserving order
    def _uniq(seq: List[str]) -> List[str]:
        seen = set()
        out = []
        for x in seq:
            if x not in seen:
                seen.add(x)
                out.append(x)
        return out

    return {
        "functions": _uniq(functions),
        "classes": _uniq(classes),
        "calls": _uniq(calls),
    }
