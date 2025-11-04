from datetime import datetime

def get_current_datetime() -> str:
    """Return current datetime as string."""
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")
