import os;
import subprocess;
import pathlib;
import json;
import re;

impl RepoMapper.do_clone(url: str) {
    def slugify(u: str) -> str {
        base = u.rstrip("/").split("/")[-1];
        if base.endswith(".git") { return base[:-4]; }
        return base;
    };

    s = slugify(url);
    dest = os.path.join("outputs", "repos", s);
    pathlib.Path(os.path.dirname(dest)).mkdir(0o777, True);

    if not pathlib.Path(os.path.join(dest, ".git")).exists() {
        subprocess.run(["git", "clone", url, dest], check=True);
    };

    return RepoInfo(url=url, local_path=dest, slug=s);
}

impl RepoMapper.map_tree(local_path: str) {
    root = os.path.abspath(local_path);
    lines = [];

    for entry in os.walk(root) {
        dp = entry[0];
        dirs = entry[1];
        files = entry[2];

        rel = os.path.relpath(dp, root);
        depth = 0 if rel == "." else rel.count(os.sep) + 1;
        prefix = "" if rel == "." else "  " * depth + "- ";
        name = os.path.basename(dp) if rel != "." else os.path.basename(root);
        lines = lines + [prefix + name + "/"];

        kept = [];
        for d in dirs {
            if d not in [".git", "venv", "node_modules", "__pycache__"] {
                kept = kept + [d];
            };
        };
        dirs[:] = sorted(kept);

        for f in sorted(files) {
            lines = lines + ["  " * (depth + 1) + "- " + f];
        };
    };

    return "\n".join(lines);
}

impl RepoMapper.readme_digest(local_path: str) {
    rootp = pathlib.Path(local_path);
    first = "";

    for p in rootp.glob("README*") { first = str(p); break; };
    if not first {
        for p in rootp.rglob("README*") { first = str(p); break; };
    };
    if not first { return "No README found."; };

    txt = "";
    file_path = pathlib.Path(first);

    if file_path.exists() {
        txt_bytes = file_path.read_bytes();
        txt = txt_bytes.decode("utf-8", "ignore");
    };

    if txt.len() > 1500 { return txt[0:1500] + "\n...\n"; };
    return txt;
}

impl CodeAnalyzer.parse_sources(local_path: str) -> str {
    root = os.path.abspath(local_path);

    nodes: dict[str, dict[str, str]] = {};
    edges: list[dict[str, str]] = [];

    for entry in os.walk(root) {
        dp = entry[0];
        files = entry[2];
        for f in files {
            if not f.endswith(".py") { continue; };

            full = os.path.join(dp, f);
            txt = pathlib.Path(full).read_text(encoding="utf-8");

            defs = func_re.findall(txt);
            calls = call_re.findall(txt);

            for d in defs { nodes[d] = {"file": full}; };
            for c in calls {
                if not nodes.get(c) {
                    nodes[c] = {"file": ""};
    };
};


            for a in defs {
                for b in calls {
                    edges = edges + [{"from": a, "to": b}];
                };
            };
        };
    };

    outdir = pathlib.Path("outputs/ccg");
    outdir.mkdir(0o777, True);
    out = outdir / (os.path.basename(root) + ".json");
    payload = {"nodes": nodes, "edges": edges};
    out.write_text(json.dumps(payload, indent=2), encoding="utf-8");

    self.last_ccg = str(out);
    return self.last_ccg;
}

impl CodeAnalyzer.where_defined(symbol: str) {
    res = [];
    data = json.loads(pathlib.Path(self.last_ccg).read_text(encoding="utf-8"));
    nodes_dict = data.get("nodes", {});

    for pair in nodes_dict.items() {
        name = pair[0];
        meta = pair[1];
        if name == symbol and meta.get("file") {
            res = res + [meta.get("file")];
        };
    };
    return res;
}

impl DocGenie.overview(repo: RepoInfo, tree_md: str, readme_sum: str) {
    outdir = pathlib.Path(os.path.join("outputs", "docs", repo.slug));
    outdir.mkdir(0o777, True);
    out = outdir / "overview.md";

    text = "# " + repo.slug + " — Overview\n\n## Structure\n" + tree_md + "\n\n## README Highlights\n" + readme_sum + "\n";
    out.write_text(text, encoding="utf-8");

    return DocArtifact(kind="overview", path=str(out), summary="overview");
}

impl DocGenie.api_docs(ccg_json_path: str) {
    base = os.path.splitext(os.path.basename(ccg_json_path))[0];
    outdir = pathlib.Path(os.path.join("outputs", "docs", base));
    outdir.mkdir(0o777, True);
    out = outdir / "api.md";

    out.write_text("# API Documentation\n\n(Generated from CCG)\n", encoding="utf-8");
    return DocArtifact(kind="api_docs", path=str(out), summary="api");
}

impl DocGenie.diagrams(ccg_json_path: str) {
    data = json.loads(pathlib.Path(ccg_json_path).read_text(encoding="utf-8"));
    lines = ["mermaid", "graph TD"];

    for n in sorted(data.get("nodes", {}).keys()) { lines = lines + ['  ' + n + '["' + n + '"]']; };
    for e in data.get("edges", []) { lines = lines + ['  ' + e.get("from") + " --> " + e.get("to")]; };
    lines = lines + [" "];

    outdir = pathlib.Path(os.path.join("outputs", "diagrams"));
    outdir.mkdir(0o777, True);
    base = os.path.splitext(os.path.basename(ccg_json_path))[0];
    out = outdir / (base + ".mmd");
    out.write_text("\n".join(lines), encoding="utf-8");

    return DocArtifact(kind="diagram", path=str(out), summary="diagram");
}

impl CodeGenius.prioritize_files { return []; }

impl CodeGenius.run_pipeline(url: str) {
    rm = RepoMapper();
    ca = CodeAnalyzer();
    dg = DocGenie();

    rep = rm.do_clone(url);
    self.repo = rep;

    self.tree_md = rm.map_tree(rep.local_path);
    self.readme_summary = rm.readme_digest(rep.local_path);
    self.ccg_json = ca.parse_sources(rep.local_path);

    ov  = dg.overview(rep, self.tree_md, self.readme_summary);
    api = dg.api_docs(self.ccg_json);
    di  = dg.diagrams(self.ccg_json);

    self.docs_paths = [ov.path, api.path, di.path];
    return "Pipeline complete:\n" + "\n".join(self.docs_paths);
}

impl generate_full_docs.generate_full_docs {
    if not url { report {"error": "missing url"}; disengage; };
    cg = CodeGenius();
    r = cg.run_pipeline(url);
    report {"session_id": jid(here), "response": r, "artifacts": cg.docs_paths};
}

impl list_artifacts.list_artifacts {
    res = [];
    base = pathlib.Path("outputs");
    for p in base.rglob("*") {
        if p.is_file() { res = res + [str(p)]; };
    };
    report res;
}
