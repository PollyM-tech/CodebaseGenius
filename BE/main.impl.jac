include main;

import os;
import from git { Repo }

def _ensure_dir(path_str: str) {
    try {
        if not os.path.exists(path_str) {
            os.makedirs(path_str);
        }
    } except Exception as e {
        print("Error creating directory:", e);
    }
}

def _make_safe_repo_name(url_or_name: str) -> str {
    safe = url_or_name.replace("https://", "");
    safe = safe.replace("http://", "");
    safe = safe.replace("github.com/", "");
    safe = safe.replace("/", "_");
    safe = safe.replace(".git", "");
    return safe;
}

impl RepoMapper.clone_repo {
    base_dir = "./outputs/tmp_repos";
    _ensure_dir(base_dir);

    safe_name = _make_safe_repo_name(url);
    repo_path = os.path.join(base_dir, safe_name);

    if os.path.exists(repo_path) {
        git_dir = os.path.join(repo_path, ".git");
        if os.path.exists(git_dir) {
            self.last_repo_url = url;
            self.last_repo_path = repo_path;
            self.last_summary = "Reused existing clone at " + repo_path;
            return repo_path;
        }
    }

    try {
        Repo.clone_from(url, repo_path);
        self.last_summary = "Cloned repository to " + repo_path;
    } except Exception as e {
        print("Error cloning repo:", e);
        _ensure_dir(repo_path);
        self.last_summary = "Failed to clone repository; created empty directory at " + repo_path;
    }

    self.last_repo_url = url;
    self.last_repo_path = repo_path;
    return repo_path;
}

impl RepoMapper.build_file_index {
    file_paths = [];

    for entry in os.walk(repo_path) {
        root_dir = entry[0];
        dirs = entry[1];
        files = entry[2];

        if ".git" in root_dir or "node_modules" in root_dir {
            continue;
        }

        for fname in files {
            if fname.endswith(".py") or fname.endswith(".jac") {
                file_paths.append(os.path.join(root_dir, fname));
            }
        }
    }

    self.last_index = file_paths;
    self.last_summary = "Indexed " + str(len(file_paths)) + " code files.";
    return file_paths;
}

impl CodeAnalyzer.analyze_file {
    self.last_target = path;
    if path not in self.analyzed_files {
        self.analyzed_files.append(path);
    }
    return "Queued basic analysis for file: " + path;
}

impl DocGenie.save_docs {
    base_dir = "./outputs/docs";
    _ensure_dir(base_dir);

    safe_name = _make_safe_repo_name(repo_name);
    if not safe_name {
        safe_name = repo_name;
    }

    filename = safe_name + ".md";
    out_path = os.path.join(base_dir, filename);

    try {
        with open(out_path, "w") as f {
            f.write(content);
        }
    } except Exception as e {
        print("Error writing documentation file:", e);
    }

    self.last_doc_preview = out_path;
    return out_path;
}

sem RoutingNodes.SUPERVISOR =
    "High-level Code Genius supervisor coordinating mapping, analysis, and documentation for a repository.";

sem RoutingNodes.REPO_MAPPER =
    "Agent responsible for cloning the repository, indexing source files, and summarizing the README.";

sem RoutingNodes.CODE_ANALYZER =
    "Agent responsible for analyzing source files and constructing a Code Context Graph of symbols and relationships.";

sem RoutingNodes.DOC_GENIE =
    "Agent that generates human-readable Markdown documentation and diagrams from repository and analysis data.";

sem RoutingNodes.GENERAL_CHAT =
    "Agent for general questions, explanations, and free-form conversation about the codebase and tooling.";
