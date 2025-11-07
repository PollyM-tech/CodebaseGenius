
import os


def ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


def write_text(path: str, content: str):
    ensure_dir(os.path.dirname(path))
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return path
