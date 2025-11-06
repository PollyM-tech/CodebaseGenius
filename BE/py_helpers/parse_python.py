# BE/py_helpers/parse_python.py
import os
import git
import shutil
from pathlib import Path

SOURCE_EXTS = {".py", ".js", ".ts", ".java", ".cpp", ".c", ".h", ".jac", ".html", ".css", ".md"}

def clone_repo(repo_url: str, dest_dir: str):
    try:
        parent = os.path.dirname(dest_dir)
        if parent and not os.path.exists(parent):
            os.makedirs(parent, exist_ok=True)
        if os.path.exists(dest_dir):
            shutil.rmtree(dest_dir)
        git.Repo.clone_from(repo_url, dest_dir)
        return {"status": "success", "path": dest_dir}
    except Exception as e:
        return {"status": "error", "error": str(e)}

def _is_ignored(path: Path, ignore_dirs: set[str]) -> bool:
    for part in path.parts:
        if part in ignore_dirs:
            return True
    return False

def get_file_info(root_dir: str, ignore_dirs=None):
    """Scan a directory and return aggregate info expected by Jac."""
    if ignore_dirs is None:
        ignore_dirs = set()
    else:
        ignore_dirs = set(ignore_dirs)

    all_files = []
    file_types: dict[str, int] = {}
    source_files = 0

    root = Path(root_dir)
    if not root.exists():
        return {"status": "error", "error": f"Path not found: {root_dir}"}

    for p in root.rglob("*"):
        if p.is_dir():
            if _is_ignored(p.relative_to(root), ignore_dirs):
                # skip walking into ignored dirs by clearing dir contents in place
                continue
            continue
        rel = p.relative_to(root).as_posix()
        parts = p.name.split(".")
        ext = parts[-1].lower() if len(parts) > 1 else "none"

        # skip files inside ignored dirs
        if _is_ignored(Path(rel), ignore_dirs):
            continue

        all_files.append(rel)
        file_types[ext] = file_types.get(ext, 0) + 1
        if p.suffix.lower() in SOURCE_EXTS:
            source_files += 1

    return {
        "all_files": all_files,
        "file_types": file_types,
        "total_files": len(all_files),
        "source_files": source_files,
    }

def summarize_readme(file_path: str, max_chars: int = 500) -> str:
    try:
        text = Path(file_path).read_text(encoding="utf-8", errors="ignore").strip()
        paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
        snippet = paragraphs[0] if paragraphs else text[:max_chars]
        snippet = snippet.replace("#", "").replace("*", "").replace("`", "")
        snippet = " ".join(snippet.split())
        return (snippet[:max_chars] + "…") if len(snippet) > max_chars else snippet
    except Exception as e:
        return f"Error summarizing {file_path}: {e}"

def find_readme_files(root_dir: str):
    """Return list of dicts: path, full_path, preview, size."""
    out = []
    root = Path(root_dir)
    for p in root.rglob("*"):
        if p.is_file() and p.name.lower().startswith("readme"):
            full = p.as_posix()
            rel = p.relative_to(root).as_posix()
            preview = summarize_readme(full, max_chars=500)
            size = len(Path(full).read_text(encoding="utf-8", errors="ignore"))
            out.append({"path": rel, "full_path": full, "preview": preview, "size": size})
    return out

def generate_file_tree(root_dir: str):
    def build_tree(directory: str, prefix: str = ""):
        entries = []
        try:
            items = sorted(os.listdir(directory))
        except PermissionError:
            return [f"{prefix} [Access Denied]"]
        for idx, item in enumerate(items):
            path = os.path.join(directory, item)
            connector = "└── " if idx == len(items) - 1 else "├── "
            if os.path.isdir(path):
                entries.append(f"{prefix}{connector}{item}/")
                extension_prefix = "    " if idx == len(items) - 1 else "│   "
                entries.extend(build_tree(path, prefix + extension_prefix))
            else:
                try:
                    size_kb = os.path.getsize(path) / 1024
                    entries.append(f"{prefix}{connector}{item} ({size_kb:.1f} KB)")
                except Exception:
                    entries.append(f"{prefix}{connector}{item} (size unavailable)")
        return entries

    try:
        root_name = os.path.basename(os.path.normpath(root_dir))
        tree_lines = [f"{root_name}/"]
        tree_lines.extend(build_tree(root_dir))
        return "\n".join(tree_lines)
    except Exception as e:
        return f"Error generating tree: {e}"
