import os;
import from dotenv { load_dotenv }

with entry {
    load_dotenv();
}

def get_current_datetime() -> str {
    return os.getenv("CURRENT_TIME") or "2025-01-01T00:00:00Z";
}
