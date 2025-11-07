include core;
import from byllm.llm { Model }
import from py_helpers.git_ops { validate_url, clone_repo }
import from py_helpers.fs_map { generate_file_tree, to_markdown_tree }
import from py_helpers.readme { find_readme, read_text_safe }

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
    def clone_and_map(url: str) -> RepoInfo {
        ok = validate_url(url);
        assert ok, "Invalid GitHub URL";
        res = clone_repo(url);
        local_path = res[0];
        repo_name = res[1];
        return RepoInfo(url=url, local_path=local_path, repo_name=repo_name);
    }

    def build_tree(repo: RepoInfo) -> RepoInfo {
        t = generate_file_tree(repo.local_path);
        repo.tree_md = to_markdown_tree(t);
        return repo;
    }

    def readme_summary_raw(text: str) -> str by llm();

    def summarise_readme(repo: RepoInfo) -> RepoInfo {
        p = find_readme(repo.local_path);
        if p {
            txt = read_text_safe(p);
            repo.readme_text = txt;
        }
        return repo;
    }

    def route_and_run(utterance: str, history: str) -> str by llm(
        method="ReAct",
        tools=([self.clone_and_map, self.build_tree, self.summarise_readme])
    );
}

sem RepoMapper.route_and_run = """
Extract a single GitHub URL from the user's utterance.
Then:
1) clone_and_map(url)
2) Optionally build_tree(repo) for a concise Markdown tree
3) Optionally summarise_readme(repo)
Return a short plain-text summary like:
- Repo: <repo_name>
- Local: <local_path>
- Tree (first 15 lines):
<tree_md_snippet_or_None>
- README: found|missing
Select and execute only one tool per step.
""";
