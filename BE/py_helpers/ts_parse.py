# ts_parse.py
import os
import re
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass, asdict

try:
    from tree_sitter import Parser
    from tree_sitter_languages import get_parser
except Exception:  # make module import-safe even if tree-sitter not installed yet
    Parser = None
    def get_parser(_lang: str):
        raise RuntimeError("tree_sitter_languages not available")

# ---------------------------
# Config / language mapping
# ---------------------------
SUPPORTED = {
    ".py": "python",
    # No official Jac grammar; treat as "python-like" for signature scanning
    ".jac": "python",
}

EXCLUDE_DIRS = {
    ".git", ".github", ".gitlab", "node_modules", "__pycache__", ".venv", "venv",
    "dist", "build", ".mypy_cache", ".pytest_cache", ".idea", ".vscode",
}

MAX_FILE_BYTES = 1_000_000  # 1MB cap to avoid huge blobs

# Cached parsers by language slug
_PARSER_CACHE: Dict[str, Parser] = {}

def _get_parser_cached(lang_slug: str) -> Parser:
    if lang_slug not in _PARSER_CACHE:
        _PARSER_CACHE[lang_slug] = get_parser(lang_slug)
    return _PARSER_CACHE[lang_slug]

# ---------------------------
# Basic collection
# ---------------------------
def collect_source_files(root: str, include_exts: Optional[List[str]] = None) -> List[str]:
    """
    Collect source file paths for supported languages, skipping common junk dirs.
    Optionally restrict to specific extensions (lowercased, with dot).
    """
    root = os.path.abspath(root)
    results: List[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for f in filenames:
            ext = os.path.splitext(f)[1].lower()
            if include_exts is not None and ext not in include_exts:
                continue
            if ext in SUPPORTED:
                results.append(os.path.join(dirpath, f))
    return results

# ---------------------------
# Naive text extraction (regex)
# ---------------------------
_FUNC_RE = re.compile(r"^\s*def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)
_CLASS_RE = re.compile(r"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)\s*(\(|:)", re.M)
# dotted call like obj.method(  or  bare call like foo(
_CALL_RE = re.compile(r"(?<![\w.])([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\s*\(")

_PY_KEYWORDS = {
    "def","class","if","for","while","return","with","await","elif","else",
    "match","case","lambda","yield","except","finally","try","print",
}

# Jac-ish signatures (very light)
_JAC_NODE_RE = re.compile(r"^\s*node\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{", re.M)
_JAC_WALKER_RE = re.compile(r"^\s*walker\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{", re.M)

def _read_text(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()
    except Exception:
        return ""

def extract_symbols_and_calls(path: str) -> Dict[str, List[str]]:
    """
    Lightweight symbol/call extraction via regex for Python/Jac-like text.
    Returns:
      { "functions": [...], "classes": [...], "walkers": [...], "nodes": [...], "calls": [...] }
    """
    text = _read_text(path)
    if not text:
        return {"functions": [], "classes": [], "walkers": [], "nodes": [], "calls": []}

    # strip obvious comments/strings is overkill here; keep it simple & fast
    functions = _FUNC_RE.findall(text)
    classes = [m[0] for m in _CLASS_RE.findall(text)]
    nodes   = _JAC_NODE_RE.findall(text)
    walkers = _JAC_WALKER_RE.findall(text)

    # calls
    calls_raw = _CALL_RE.findall(text)
    calls: List[str] = []
    for c in calls_raw:
        head = c.split(".")[0]
        if head in _PY_KEYWORDS:
            continue
        calls.append(c)

    # de-dup while preserving order
    def uniq(seq: List[str]) -> List[str]:
        seen = set(); out = []
        for x in seq:
            if x not in seen:
                seen.add(x); out.append(x)
        return out

    return {
        "functions": uniq(functions),
        "classes":   uniq(classes),
        "walkers":   uniq(walkers),
        "nodes":     uniq(nodes),
        "calls":     uniq(calls),
    }

# ---------------------------
# Tree-sitter parse (optional / per-file)
# ---------------------------
def parse_file(path: str) -> Optional[Tuple[Any, bytes, str]]:
    """
    Parse file using tree-sitter (if supported). Returns (tree, src_bytes, lang_slug).
    """
    ext = os.path.splitext(path)[1].lower()
    lang_slug = SUPPORTED.get(ext)
    if not lang_slug or Parser is None:
        return None
    try:
        parser = _get_parser_cached(lang_slug)
        with open(path, "rb") as f:
            src = f.read(MAX_FILE_BYTES)
        tree = parser.parse(src)
        return tree, src, lang_slug
    except Exception:
        return None

# ---------------------------
# Contract functions for CodeAnalyzer
# ---------------------------
@dataclass
class SymbolRef:
    kind: str       # "func" | "class" | "node" | "walker"
    name: str
    file: str
    line: int       # 1-based
    qname: str      # qualified name (module.name); here: file-basename + name

def parse_sources(root: str, exts: Optional[List[str]] = None) -> Dict[str, Any]:
    """
    Walk the repo and extract per-file symbols and calls (regex-fast).
    Returns:
      {
        "files": {
          "<rel_path>": {
            "functions": [...], "classes": [...], "nodes": [...], "walkers": [...],
            "calls": [...],
          }, ...
        }
      }
    """
    root = os.path.abspath(root)
    files = collect_source_files(root, include_exts=exts)
    out: Dict[str, Any] = {"files": {}}
    for abspath in files:
        rel = os.path.relpath(abspath, root)
        data = extract_symbols_and_calls(abspath)
        out["files"][rel] = data
    return out

def build_ccg(parsed: Dict[str, Any]) -> Dict[str, Any]:
    """
    Construct a best-effort Code Context Graph (CCG) from parsed symbols/calls.
    Strategy:
      - Create nodes for each function/class/walker/node discovered.
      - Add edges for calls when callee matches a discovered function name
        (same-file resolution + dotted calls last segment match).
      - Node ids: kind:file:Name
    Returns: { "nodes": [...], "edges": [...] }
    """
    files = parsed.get("files", {})
    nodes: List[Dict[str, str]] = []
    edges: List[Dict[str, str]] = []

    # index: name -> [(file, kind)]
    func_index: Dict[str, List[Tuple[str, str]]] = {}
    def _add_node(kind: str, file: str, name: str):
        nid = f"{kind}:{file}:{name}"
        nodes.append({"id": nid, "label": f"{name} ({file})", "kind": kind, "file": file})
        if kind == "func":
            func_index.setdefault(name, []).append((file, kind))

    for file, info in files.items():
        for fn in info.get("functions", []):
            _add_node("func", file, fn)
        for cl in info.get("classes", []):
            _add_node("class", file, cl)
        for nd in info.get("nodes", []):
            _add_node("jac_node", file, nd)
        for wk in info.get("walkers", []):
            _add_node("walker", file, wk)

    # edges: simple same-file resolution or dotted callee last segment
    for file, info in files.items():
        known_funcs_here = {fn for fn in info.get("functions", [])}
        for call in info.get("calls", []):
            callee = call.split(".")[-1]
            # same-file match first
            if callee in known_funcs_here:
                src_id = f"file:{file}"
                dst_id = f"func:{file}:{callee}"
                edges.append({"src": src_id, "dst": dst_id, "type": "CALLS"})
                continue
            # cross-file: if unique function name across repo
            matches = func_index.get(callee, [])
            if len(matches) == 1:
                dst_file, _ = matches[0]
                src_id = f"file:{file}"
                dst_id = f"func:{dst_file}:{callee}"
                edges.append({"src": src_id, "dst": dst_id, "type": "CALLS"})

    # also add file nodes so edges have a src
    for file in files.keys():
        fid = f"file:{file}"
        nodes.append({"id": fid, "label": file, "kind": "file", "file": file})

    # de-dup
    def uniq_dicts(seq: List[Dict[str, str]]) -> List[Dict[str, str]]:
        seen = set(); out=[]
        for d in seq:
            t = tuple(sorted(d.items()))
            if t not in seen:
                seen.add(t); out.append(d)
        return out

    return {"nodes": uniq_dicts(nodes), "edges": uniq_dicts(edges)}

def calls_of(parsed_or_ccg: Dict[str, Any], symbol: str) -> List[str]:
    """
    If given parsed: search in 'files' for call strings matching 'symbol' (last segment).
    If given ccg: return edges whose dst matches '*:symbol'.
    """
    if "edges" in parsed_or_ccg:
        out = []
        for e in parsed_or_ccg.get("edges", []):
            dst = e.get("dst", "")
            if dst.endswith(f":{symbol}"):
                out.append(e.get("src", ""))
        return out

    # parsed mode
    symbol = symbol.split(".")[-1]
    out = []
    files = parsed_or_ccg.get("files", {})
    for file, info in files.items():
        for c in info.get("calls", []):
            if c.split(".")[-1] == symbol:
                out.append(f"{file}:{c}")
    return out

def defs_of(parsed_or_ccg: Dict[str, Any], symbol: str) -> List[str]:
    """
    Return files where a function/class/walker/node named 'symbol' is defined.
    """
    symbol = symbol.split(".")[-1]
    out = []
    files = parsed_or_ccg.get("files", {})
    for file, info in files.items():
        if symbol in info.get("functions", []) or symbol in info.get("classes", []) \
           or symbol in info.get("walkers", []) or symbol in info.get("nodes", []):
            out.append(file)
    return out
