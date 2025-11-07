include core;

import from py_helpers.git_ops { validate_url, clone_repo }
import from py_helpers.fs_map { generate_file_tree, to_markdown_tree }
import from py_helpers.readme { find_readme, read_text_safe }
import from byllm.llm { Model }
import from os { getenv }

glob llm = Model(model_name="gpt-4o", verbose=False);

node RepoInfo {
    has url: str = "";
    has local_path: str = "";
    has repo_name: str = "";
    has tree_md: str = "";
    has readme_text: str = "";
    has readme_summary: str = "";
}

node RepoMapper(Toolbox) {
    # 1) Clone + capture basic info
    def clone_and_map(url: str) -> RepoInfo {
        ok = validate_url(url);
        assert ok, "Invalid GitHub URL";
        res = clone_repo(url);              # expected: (local_path, repo_name)
        local_path = res[0];
        repo_name = res[1];
        return RepoInfo(url=url, local_path=local_path, repo_name=repo_name);
    }

    # 2) Build high-level file tree (ignores .git, node_modules in helper)
    def build_tree(repo: RepoInfo) -> RepoInfo {
        t = generate_file_tree(repo.local_path);
        repo.tree_md = to_markdown_tree(t);
        return repo;
    }

    # 3) Optional LLM summarizer for README (kept off by default to save tokens)
    def readme_summary_raw(text: str) -> str by llm();

    # 4) Find & read README.* and (optionally) summarize
    def summarise_readme(repo: RepoInfo) -> RepoInfo {
        p = find_readme(repo.local_path);
        if p {
            txt = read_text_safe(p);
            repo.readme_text = txt;
            # Uncomment to auto-summarize via LLM:
            # repo.readme_summary = self.readme_summary_raw(txt);
        }
        return repo;
    }

    # 5) Single ReAct entry: LLM may call clone -> tree -> readme
    def route_and_run(url: str) -> RepoInfo by llm(
        method="ReAct",
        tools=([self.clone_and_map, self.build_tree, self.summarise_readme])
    );
}
