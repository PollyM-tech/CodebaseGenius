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
    has repo: RepoInfo;
    has url: str = "";

    def plan(overview: str, tree_md: str, readme_sum: str) -> list[str] by llm();
    def route_and_run(utterance: str, history: str) -> str by llm();
}

walker supervisor(agent) {
    has url: str = "";

    obj __specs__ { static has auth: bool = False; }

    can supervisor with root entry {
        self._attach_session();
        session = self.session;
        session.add_history("user: " + self.url);

        rmap = RepoMapper();
        repo = rmap.clone_and_map(self.url);
        repo = rmap.build_tree(repo);
        repo = rmap.summarise_readme(repo);
        if not repo.local_path {
            report {"error":"Failed to clone/map repository."};
            disengage;
        }

        analyzer = CodeAnalyzer();
        cg = analyzer.build_ccg(repo.local_path, repo.repo_name);

        genius = CodeGenius(repo=repo, url=self.url);
        readme = "";
        if repo.readme_summary { readme = repo.readme_summary; }
        else { readme = repo.readme_text; }
        plan_steps = genius.plan("Codebase Genius planning", repo.tree_md, readme);

        doc = DocGenie();
        bundle = doc.assemble(repo.repo_name, "Auto-generated documentation for " + repo.repo_name, repo.tree_md, readme);

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

    can get_doc with root entry {
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

    can query_calls with root entry {
        analyzer = CodeAnalyzer();
        callers = analyzer.query_calls(self.func_name, self.repo_name);
        report {"func": self.func_name, "callers": callers};
    }
}
