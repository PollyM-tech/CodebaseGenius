include core;
include utils;
include repo_mapper;
include code_analyzer;
include docgenie;

import from byllm.llm { Model }
import from os { getcwd }
import from os.path { join, exists }
import from py_helpers.io_utils { read_text }

glob llm = Model(model_name="gpt-4o", verbose=False);

node CodeGenius(Toolbox) {
    has url: str = "";
    has repo: RepoInfo;

    def plan(overview: str, tree_md: str, readme_sum: str) -> list[str] by llm();
    def route_and_run(utterance: str, history: str) -> str by llm();
}

walker supervisor(base_agent) {
    has url: str = "";

    obj __specs__ { static has auth: bool = False; }

    can supervisor with `root entry {
        session = self._ensure_session();
        session.add_history("user: " + self.url);

        # 1) Map repo
        rmap = RepoMapper();
        repo = rmap.route_and_run(self.url);
        if not repo.local_path {
            report {"error":"Failed to clone/map repository."};
            disengage;
        }

        # 2) Build CCG
        analyzer = CodeAnalyzer();
        cg = analyzer.build_ccg(repo.local_path, repo.repo_name);

        # 3) High-level plan
        genius = CodeGenius(url=self.url, repo=repo);
        plan_steps = genius.plan(
            "Codebase Genius planning",
            repo.tree_md,
            repo.readme_summary if repo.readme_summary else repo.readme_text
        );

        # 4) Assemble docs
        doc = DocGenie();
        bundle = doc.assemble(
            repo.repo_name,
            "Auto-generated documentation for " + repo.repo_name,
            repo.tree_md,
            repo.readme_summary if repo.readme_summary else repo.readme_text
        );

        session.add_history("ai: " + "Generated docs at " + bundle.output_path);
        report {
            "session_id": jid(session),
            "repo_name": repo.repo_name,
            "output_path": bundle.output_path,
            "diagram_present": bundle.diagram != ""
        };
    }
}

walker get_doc {
    has repo_name: str = "";

    obj __specs__ { static has auth: bool = False; }

    can get_doc with `root entry {
        base = getcwd();
        path = join(base, "outputs", self.repo_name, "docs.md");
        if not exists(path) {
            report {"error":"No docs found for repo", "repo": self.repo_name};
            disengage;
        }
        content = read_text(path);
        report {"repo": self.repo_name, "docs": content};
    }
}

walker query_calls {
    has repo_name: str = "";
    has func_name: str = "";

    obj __specs__ { static has auth: bool = False; }

    can query_calls with `root entry {
        analyzer = CodeAnalyzer();
        callers = analyzer.query_calls(self.func_name, self.repo_name);
        report {"func": self.func_name, "callers": callers};
    }
}
