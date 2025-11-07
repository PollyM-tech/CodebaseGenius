
import os
import re
import shutil
import tempfile
from typing import Tuple

from git import Repo


_GITHUB_URL_RE = re.compile(
    r"^https?://(www\.)?github\.com/[^/]+/[^/]+/?$",
    re.IGNORECASE,
)


def validate_url(url: str) -> bool:
    """
    Quick sanity check for a public GitHub repo URL.
    Accepts: https://github.com/<org>/<repo>[/]
    """
    return bool(_GITHUB_URL_RE.match(url or ""))


def clone_repo(url: str, base_dir: str | None = None, depth: int = 1) -> Tuple[str, str]:
    """
    Clone a public GitHub repo into a temp directory (or provided base_dir).

    Returns:
        (local_path, repo_name)
    Raises:
        ValueError: if URL is invalid
        git.GitError: if clone fails
    """
    if not validate_url(url):
        raise ValueError("Invalid GitHub URL (expected https://github.com/<org>/<repo>).")

    base = base_dir or tempfile.gettempdir()
    repo_name = url.rstrip("/").split("/")[-1]
    target = os.path.join(base, f"cbg_{repo_name}")

    # Clean existing target path for repeatable runs
    if os.path.exists(target):
        shutil.rmtree(target, ignore_errors=True)

    Repo.clone_from(url, target, depth=depth)
    return target, repo_name
