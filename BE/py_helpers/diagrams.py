
from typing import List, Dict


def mermaid_from_ccg(nodes: List[Dict], edges: List[Dict]) -> str:
    """
    Build a Mermaid flow-style graph (LR) from a Code Context Graph (CCG).
    nodes: [{"id":"file:src_app_py","label":"src/app.py"}, ...]
    edges: [{"src":"file:src_app_py","dst":"func:train_model","type":"CALLS"}, ...]
    """
    lines = ["```mermaid", "graph LR"]
    # nodes
    nid_seen = set()
    for n in nodes:
        nid = sanitize(n["id"])
        if nid in nid_seen:
            continue
        nid_seen.add(nid)
        label = n.get("label", n["id"]).replace('"', "'")
        lines.append(f'  {nid}["{label}"]')

    # edges
    for e in edges:
        src = sanitize(e["src"])
        dst = sanitize(e["dst"])
        label = (e.get("type") or "").lower()
        lines.append(f"  {src} -- {label} --> {dst}")

    lines.append("```")
    return "\n".join(lines)


def sanitize(s: str) -> str:
    """
    Mermaid node ids must be simple. Replace separators/punctuation with underscores.
    """
    return (
        s.replace("-", "_")
         .replace(".", "_")
         .replace("/", "_")
         .replace("\\", "_")
         .replace(":", "_")
    )
