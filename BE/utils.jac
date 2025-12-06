import from datetime { datetime }


def get_current_datetime() -> str {
    return str(datetime.now());
}

def make_safe_repo_name(url: str) -> str {
    # sanitize URL into folder-friendly name
}

def join_path(base: str, child: str) -> str {
    return path.join(base, child);
}