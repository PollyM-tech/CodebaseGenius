# git_ops.py
import os
import re
import shutil
import tempfile
from typing import Optional, Tuple

from git import Repo, GitCommandError, InvalidGitRepositoryError

_GITHUB_URL_RE = re.compile(
    r"^https?://(www\.)?github\.com/[^/]+/[^/]+(\.git)?/?$",
    re.IGNORECASE,
)

def validate_url(url: str) -> bool:
    """Accepts: https://github.com/<org>/<repo>[.git][/]."""
    return bool(_GITHUB_URL_RE.match((url or "").strip()))

def _repo_name_from_url(url: str) -> str:
    clean = url.rstrip("/").split("/")[-1]
    if clean.endswith(".git"):
        clean = clean[:-4]
    return clean

def _inject_token(url: str, token: Optional[str]) -> str:
    if not token:
        return url
    # only for github.com https urls
    return re.sub(r"^https://", f"https://{token}@", url, count=1, flags=re.IGNORECASE)

def clone_repo(
    url: str,
    base_dir: Optional[str] = None,
    depth: int = 1,
    *,
    dest_dir: Optional[str] = None,
    branch: Optional[str] = None,
    token: Optional[str] = None,
    recurse_submodules: bool = False,
    clean_if_exists: bool = True,
    single_branch: bool = True,
) -> Tuple[str, str]:
    """
    Clone a GitHub repo.

    Returns:
        (local_path, repo_name)

    Raises:
        ValueError           – invalid URL
        GitCommandError     – git clone/fetch errors
    """
    if not validate_url(url):
        raise ValueError("Invalid GitHub URL (expected https://github.com/<org>/<repo>[.git]).")

    repo_name = _repo_name_from_url(url)
    base = base_dir or tempfile.gettempdir()
    target = dest_dir or os.path.join(base, f"cbg_{repo_name}")

    if os.path.exists(target):
        if clean_if_exists:
            shutil.rmtree(target, ignore_errors=True)
        else:
            # If target exists and is a repo, try update instead
            try:
                r = Repo(target)
                # fetch + reset to origin/<branch or default>
                remote = r.remotes.origin
                remote.fetch(depth=depth if depth and depth > 0 else None)
                if branch:
                    r.git.checkout(branch)
                    r.git.reset("--hard", f"origin/{branch}")
                else:
                    # stay on current branch but hard reset to its remote
                    cur = r.active_branch.name
                    r.git.reset("--hard", f"origin/{cur}")
                return target, repo_name
            except (InvalidGitRepositoryError, GitCommandError):
                shutil.rmtree(target, ignore_errors=True)

    # Prepare options
    effective_url = _inject_token(url, token or os.getenv("GH_TOKEN"))
    clone_kwargs = {
        "to_path": target,
        "depth": depth if depth and depth > 0 else None,
        "multi_options": ["--single-branch"] if single_branch else None,
        "recurse_submodules": recurse_submodules,
        "branch": branch,
    }
    # Clean out None values for GitPython
    clone_kwargs = {k: v for k, v in clone_kwargs.items() if v is not None}

    Repo.clone_from(effective_url, **clone_kwargs)
    return target, repo_name
