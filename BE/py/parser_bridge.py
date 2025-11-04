import os
import git
import json
import shutil
from pathlib import Path

def clone_repo(repo_url: str, dest_dir: str):
    """Clone a GitHub repo into a temporary directory"""
    try:
        if os.path.exists(dest_dir):
            shutil.rmtree(dest_dir)

        git.Repo.clone_from(repo_url, dest_dir)
        return {"status": "success", "path": dest_dir}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def get_file_info(base_dir: str):
    """Scan a directory for all files and collect type statistics"""
    file_types = {}
    all_files = []
    source_files = 0

    for root, _, files in os.walk(base_dir):
        for f in files:
            full_path = os.path.join(root, f)
            all_files.append(full_path)
            ext = f.split(".")[-1] if "." in f else "none"
            file_types[ext] = file_types.get(ext, 0) + 1
            if ext in ["py", "jac", "js", "java", "ts", "cpp", "c"]:
                source_files += 1

    return {
        "total_files": len(all_files),
        "source_files": source_files,
        "all_files": all_files,
        "file_types": file_types
    }


def find_readme_files(base_dir: str):
    """Find README files and return short previews"""
    readmes = []
    for root, _, files in os.walk(base_dir):
        for f in files:
            if f.lower().startswith("readme"):
                full_path = os.path.join(root, f)
                try:
                    with open(full_path, "r", encoding="utf-8", errors="ignore") as file:
                        preview = file.read(300)
                    size = os.path.getsize(full_path)
                    readmes.append({
                        "path": f,
                        "full_path": full_path,
                        "preview": preview,
                        "size": size
                    })
                except Exception:
                    continue
    return readmes


def generate_file_tree(base_dir: str):
    """Generate a simple text-based file tree"""
    tree_lines = []
    for root, dirs, files in os.walk(base_dir):
        level = root.replace(base_dir, "").count(os.sep)
        indent = " " * 4 * level
        tree_lines.append(f"{indent}{os.path.basename(root)}/")
        sub_indent = " " * 4 * (level + 1)
        for f in files:
            tree_lines.append(f"{sub_indent}{f}")
    return "\n".join(tree_lines)

def extract_code_summary(file_path: str):
    """Analyze a Python file and extract basic info."""
    try:
        with open(file_path, "r") as f:
            code = f.read()

        # Count lines and functions
        lines = len(code.splitlines())
        imports = [l for l in code.splitlines() if l.strip().startswith("import") or l.strip().startswith("from")]
        functions = [l for l in code.splitlines() if l.strip().startswith("def ")]

        summary = {
            "lines": lines,
            "imports": len(imports),
            "functions": len(functions),
        }

        return summary

    except Exception as e:
        return {"error": str(e)}
