# fs_map.py
import os
from typing import Dict, List, Optional, Set, Tuple

# Defaults – still used if no overrides are passed
EXCLUDE_DIRS: Set[str] = {
    ".git", ".github", ".gitlab", "node_modules", "__pycache__", ".venv", "venv",
    "dist", "build", ".mypy_cache", ".pytest_cache", ".idea", ".vscode"
}
EXCLUDE_FILES: Set[str] = {".DS_Store", "Thumbs.db"}

def _is_excluded_dir(name: str, exclude_dirs: Set[str]) -> bool:
    # Exclude dot-directories and any explicitly listed
    return name in exclude_dirs or name.startswith(".")

def _safe_listdir(path: str) -> List[str]:
    try:
        return os.listdir(path)
    except Exception:
        return []

def _split_sort(items: List[str]) -> Tuple[List[str], List[str]]:
    # Return (dirs, files) – both case-insensitively sorted
    dirs, files = [], []
    for x in items:
        if x is None:
            continue
        (dirs if os.path.isdir(x) else files).append(x)
    key = lambda p: os.path.basename(p).lower()
    return sorted(dirs, key=key), sorted(files, key=key)

def generate_file_tree(
    root: str,
    *,
    exclude_dirs: Optional[Set[str]] = None,
    exclude_files: Optional[Set[str]] = None,
    exclude_exts: Optional[Set[str]] = None,
    include_exts: Optional[Set[str]] = None,
    with_meta: bool = False,
    max_items_per_dir: Optional[int] = None,
) -> Dict:
    """
    Walk the file system from `root` and return a nested dictionary representing folders/files.

    - exclude_dirs: set of directory names to skip (defaults to EXCLUDE_DIRS)
    - exclude_files: set of file names to skip (defaults to EXCLUDE_FILES)
    - exclude_exts/include_exts: file extension filters (include takes precedence)
    - with_meta: include size and mtime on files
    - max_items_per_dir: cap entries per directory for speed on huge trees
    """
    root = os.path.abspath(root)
    exclude_dirs = set(EXCLUDE_DIRS if exclude_dirs is None else exclude_dirs)
    exclude_files = set(EXCLUDE_FILES if exclude_files is None else exclude_files)
    exclude_exts = set(exclude_exts or set())
    include_exts = set(include_exts or set())

    def allow_file(path: str, name: str) -> bool:
        if name in exclude_files:
            return False
        ext = os.path.splitext(name)[1].lower()
        if include_exts:
            return ext in include_exts
        if exclude_exts and ext in exclude_exts:
            return False
        return True

    def walk(path: str) -> List[Dict]:
        entries: List[Dict] = []
        # Build absolute children paths to sort deterministically
        items = [os.path.join(path, n) for n in _safe_listdir(path)]
        dirs, files = _split_sort(items)

        # Optionally trim for performance
        if max_items_per_dir is not None and max_items_per_dir > 0:
            dirs = dirs[:max_items_per_dir]
            files = files[:max_items_per_dir]

        # Directories
        for d in dirs:
            name = os.path.basename(d)
            if _is_excluded_dir(name, exclude_dirs):
                continue
            if os.path.islink(d):
                continue
            entries.append({
                "type": "dir",
                "name": name,
                "children": walk(d),
            })

        # Files
        for f in files:
            name = os.path.basename(f)
            if not allow_file(f, name):
                continue
            try:
                rel = os.path.relpath(f, root)
            except Exception:
                rel = name
            node: Dict = {
                "type": "file",
                "name": name,
                "path": rel,
            }
            if with_meta:
                try:
                    st = os.stat(f)
                    node["size"] = st.st_size
                    node["mtime"] = int(st.st_mtime)
                except Exception:
                    pass
            entries.append(node)

        return entries

    return {"root": os.path.basename(root), "tree": walk(root)}

def to_markdown_tree(tree: Dict, indent: int = 0) -> str:
    """
    Render the nested dict returned by `generate_file_tree` into a Markdown outline.
    """
    lines: List[str] = []

    def emit(node: Dict, depth: int):
        prefix = "  " * depth + ("- " if depth > 0 else "")
        if node["type"] == "dir":
            lines.append(f"{prefix}{node['name']}/")
            for child in node.get("children", []):
                emit(child, depth + 1)
        else:
            lines.append(f"{prefix}{node['name']}")

    lines.append(f"{tree['root']}/")
    for child in tree.get("tree", []):
        emit(child, 1)
    return "\n".join(lines)

def generate_file_tree_md(
    root: str,
    **kwargs
) -> str:
    """
    Convenience: directly return Markdown tree.
    Accepts same kwargs as generate_file_tree.
    """
    t = generate_file_tree(root, **kwargs)
    return to_markdown_tree(t)
