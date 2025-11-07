import from datetime { datetime }
import from py_helpers.io_utils { write_text, ensure_dir }

def get_current_datetime() -> str {
    return str(datetime.now());
}

def safe_write(path: str, content: str) -> str {
    return write_text(path, content);
}
