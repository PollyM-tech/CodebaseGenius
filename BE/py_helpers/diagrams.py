# diagrams.py
from typing import List, Dict, Iterable, Optional, Tuple
import re

def mermaid_from_ccg(
    nodes: List[Dict],
    edges: List[Dict],
    *,
    direction: str = "LR",
    fenced: bool = True,
    max_label_len: int = 48,
    cluster_by: Optional[str] = None,   # e.g., "group" or "module"
) -> str:
    """
    Build a Mermaid graph from a Code Context Graph (CCG).

    nodes: [{"id":"file:src_app_py","label":"src/app.py","group":"app"}, ...]
    edges: [{"src":"file:src_app_py","dst":"func:train_model","type":"CALLS"}, ...]

    Returns a string suitable for Markdown (if fenced=True) or .mmd (if fenced=False).
    """

    # Header
    lines: List[str] = []
    if fenced:
        lines.append("```mermaid")
    lines.append(f"graph {direction}")

    # --- nodes ---
    nid_seen = set()
    clusters = {}  # {group_value: [(id,label), ...]}
    plain_nodes: List[Tuple[str,str]] = []

    for n in nodes or []:
        nid_raw = n.get("id")
        if not nid_raw:
            continue
        nid = _sanitize_id(nid_raw)
        if nid in nid_seen:
            continue
        nid_seen.add(nid)

        label = n.get("label") or nid_raw
        label = _trim_label(label, max_label_len)

        if cluster_by and n.get(cluster_by):
            clusters.setdefault(n[cluster_by], []).append((nid, label))
        else:
            plain_nodes.append((nid, label))

    # Emit clustered nodes first
    for grp, items in clusters.items():
        grp_label = _trim_label(str(grp), max_label_len)
        grp_id = _sanitize_id(f"cluster_{grp}")
        lines.append(f"  subgraph {grp_id}[\"{_escape(grp_label)}\"]")
        for nid, label in items:
            lines.append(f'    {nid}["{_escape(label)}"]')
        lines.append("  end")

    # Emit non-clustered nodes
    for nid, label in plain_nodes:
        lines.append(f'  {nid}["{_escape(label)}"]')

    # --- edges ---
    emitted = set()
    for e in edges or []:
        src_raw, dst_raw = e.get("src"), e.get("dst")
        if not src_raw or not dst_raw:
            continue
        src = _sanitize_id(src_raw)
        dst = _sanitize_id(dst_raw)
        etype = (e.get("type") or "").lower()
        key = (src, dst, etype)
        if key in emitted:
            continue
        emitted.add(key)
        if etype:
            lines.append(f"  {src} -- {etype} --> {dst}")
        else:
            lines.append(f"  {src} --> {dst}")

    if fenced:
        lines.append("```")
    return "\n".join(lines)


# Backward/forward compatibility alias
def ccg_to_mermaid(*args, **kwargs) -> str:
    """Alias so Jac code can import either name."""
    return mermaid_from_ccg(*args, **kwargs)


# ----------------------
# Helpers (internal)
# ----------------------
_ID_SAFE_RE = re.compile(r"[^A-Za-z0-9_]")
def _sanitize_id(s: str) -> str:
    # Replace separators with underscores, and ensure it doesn’t start with a digit
    s = s.strip()
    s = s.replace(" ", "_")
    s = s.replace("-", "_")
    s = s.replace(".", "_")
    s = s.replace("/", "_")
    s = s.replace("\\", "_")
    s = s.replace(":", "_")
    s = _ID_SAFE_RE.sub("_", s)
    if s and s[0].isdigit():
        s = f"n_{s}"
    return s or "n_unknown"

def _trim_label(label: str, max_len: int) -> str:
    label = label.strip()
    if max_len and len(label) > max_len:
        return label[: max_len - 1] + "…"
    return label

def _escape(s: str) -> str:
    # Mermaid tolerates quotes but we keep it simple
    return s.replace('"', "'")
