walker code_analyzer {
    # Start at a repository node or pass one in
    has repo_root: any = null;

    # Tunables
    has include_exts: list = ["py"];       # analyze only these file types
    has max_files: int = 0;                # 0 = no limit; >0 = cap analysis

    with entry {
        std.out("🔎 Starting code analysis");

        # Find repository node
        let repo = null;
        if (here.type == "repository") {
            repo = here;
        } else if (repo_root != null and repo_root.type == "repository") {
            repo = repo_root;
        } else {
            std.err("No repository node found. Start at a repository or set repo_root.");
            stop;
        }

        let analyzed = 0;
        let skipped  = 0;
        let failed   = 0;

        # Iterate typed edges to files created by repo_mapper
        for e in repo.edges {
            if (e.type == "contains_file") {
                let f = e.target;

                # Only act on file nodes
                if (f.type != "file") {
                    continue;
                }

                # Respect include_exts and is_source_code flag
                if (!(f.is_source_code) or !(f.file_type in include_exts)) {
                    skipped += 1;
                    continue;
                }

                # Optional cap
                if (max_files > 0 and analyzed >= max_files) {
                    break;
                }

                std.out("• Analyzing " + f.path);

                # Call Python helper to extract a summary
                let result = py_exec("""
import sys, os
sys.path.append('py')
try:
    from parse_python import extract_code_summary
    summary = extract_code_summary('''{{f.path}}''')
    out = {'status': 'success', 'summary': summary}
except Exception as e:
    out = {'status': 'error', 'error': str(e)}
out
                """, "out", []);

                if (result and ("status" in result) and result["status"] == "success") {
                    f.code_summary = result["summary"];   # attach to the file node
                    analyzed += 1
                } else {
                    std.err("  × Failed: " + (result["error"] if (result and "error" in result) else "unknown error"));
                    failed += 1
                }
            }
        }

        std.out("   Code analysis complete.");
        std.out("   analyzed: " + str(analyzed));
        std.out("   skipped : " + str(skipped) + " (non-target ext or not source)");
        std.out("   failed  : " + str(failed));

        # Handy result for API/supervisor
        report({
            "status": "done",
            "analyzed": analyzed,
            "skipped": skipped,
            "failed": failed,
            "exts": include_exts
        });
    }
}
