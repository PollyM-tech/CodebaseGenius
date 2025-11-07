
import os
from typing import Dict, List


# Directories we ignore for mapping to keep the tree clean
EXCLUDE_DIRS = {
    ".git", ".github", ".gitlab", "node_modules", "__pycache__", ".venv", "venv",
    "dist", "build", ".mypy_cache", ".pytest_cache", ".idea", ".vscode"
}


def _is_excluded_dir(name: str) -> bool:
    return name in EXCLUDE_DIRS or name.startswith(".")


def generate_file_tree(root: str) -> Dict:
    """
    Walk the file system from `root` and return a nested dictionary
    representing folders/files. Skips EXCLUDE_DIRS.
    """
    root = os.path.abspath(root)

    def walk(path: str) -> List[Dict]:
        entries: List[Dict] = []
        try:
            items = sorted(os.listdir(path))
        except Exception:
            return entries

        for name in items:
            full = os.path.join(path, name)
            rel = os.path.relpath(full, root)

            if os.path.isdir(full):
                if _is_excluded_dir(name):
                    continue
                entries.append({
                    "type": "dir",
                    "name": name,
                    "children": walk(full),
                })
            else:
                entries.append({
                    "type": "file",
                    "name": name,
                    "path": rel,
                })
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
