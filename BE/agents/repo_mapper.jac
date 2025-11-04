
import from py.parse_python {
    clone_repo,
    get_file_info,
    find_readme_files,
    generate_file_tree
}

walker initialize {
    with entry { report("Graph initialized successfully."); }
}

node repository {
    has name: str;
    has url: str;
    has local_path: str;
    has file_count: int = 0;
    has readme_count: int = 0;
    has source_file_count: int = 0;
    has file_tree_md: str = "";
}

node file {
    has name: str;
    has path: str;
    has file_type: str;
    has is_source_code: bool = false;
}

node readme {
    has name: str;
    has path: str;
    has preview: str;
    has size: int;
}

edge contains_file { }

walker repo_mapper {
    # ---- tunables ----
    has url: str = "https://github.com/<owner>/<repo>.git";   # default so `jac run` works
    has include_exts: list = ["py", "jac", "js", "java", "ts", "cpp", "c"];
    has ignore_dirs: list = [".git", "node_modules", ".venv", "venv", "dist", "build", "__pycache__"];
    has out_base: str = "outputs";    # keep simple & predictable (run from BE/)

    with entry {
        report("Starting Repo Mapper for: " + url);

        let repo_name = url.split("/")[-1].replace(".git", "");
        let unique_dir = out_base + "/temp_repos/" + repo_name;   # simple path; OK to overwrite on rerun

        # ---- clone ----
        let clone_result = clone_repo(url, unique_dir);
        if (not clone_result or not ("status" in clone_result) or clone_result["status"] != "success") {
            report("ERROR: Failed to clone repository");
            if (clone_result and "error" in clone_result) { report("  Reason: " + str(clone_result["error"])); }
            stop;
        }

        let local_path = clone_result["path"];
        report("Repository cloned to: " + local_path);

        let repo_node = spawn repository(
            name = repo_name,
            url = url,
            local_path = local_path
        );

        # ---- scan files ----
        report("Analyzing file structure...");
        let file_info = get_file_info(local_path, ignore_dirs=ignore_dirs);

        if (not file_info or ("status" in file_info and file_info["status"] == "error")) {
            report("ERROR: File scan failed.");
            if (file_info and "error" in file_info) { report("  Reason: " + str(file_info["error"])); }
            stop;
        }

        if (not ("all_files" in file_info)) { file_info["all_files"] = []; }
        if (not ("file_types" in file_info)) { file_info["file_types"] = {}; }
        if (not ("total_files" in file_info)) { file_info["total_files"] = len(file_info["all_files"]); }
        if (not ("source_files" in file_info)) { file_info["source_files"] = 0; }

        report("Found " + str(file_info["total_files"]) + " files total");
        report("Found " + str(file_info["source_files"]) + " source code files");

        for file_path in file_info["all_files"] {
            let file_name = file_path.split("/")[-1];
            let parts = file_name.split(".");
            let file_ext = parts[len(parts) - 1] if len(parts) > 1 else "none";
            let is_source = (file_ext in include_exts);

            let file_node = spawn file(
                name = file_name,
                path = file_path,
                file_type = file_ext,
                is_source_code = is_source
            );

            connect(repo_node, file_node, contains_file);
        }

        repo_node.file_count = file_info["total_files"];
        repo_node.source_file_count = file_info["source_files"];

        report("File type summary:");
        for file_type in file_info["file_types"].keys() {
            let count = file_info["file_types"][file_type];
            report("   - " + file_type + ": " + str(count) + " files");
        }

        # ---- readmes ----
        report("Looking for README files...");
        let readmes = find_readme_files(local_path) or [];
        for readme_data in readmes {
            let readme_node = spawn readme(
                name = readme_data["path"],
                path = readme_data["full_path"],
                preview = readme_data["preview"],
                size = readme_data["size"]
            );
            connect(repo_node, readme_node, contains_file);
            report("   " + readme_data["path"] + " (" + str(readme_data["size"]) + " chars)");
        }
        repo_node.readme_count = len(readmes);

        # ---- file tree (markdown) ----
        let tree_md = generate_file_tree(local_path, ignore_dirs=ignore_dirs) or "";
        if (tree_md != "") {
            repo_node.file_tree_md = str(tree_md);
            report("File tree generated (" + str(len(tree_md)) + " chars)");
        } else {
            report("File tree not available.");
        }

        report("Repo Mapper completed successfully.");
        report("   Total files: " + str(repo_node.file_count));
        report("   Source files: " + str(repo_node.source_file_count));
        report("   README files: " + str(repo_node.readme_count));

        report({
            "repo": repo_name,
            "local_path": local_path,
            "files_total": repo_node.file_count,
            "files_source": repo_node.source_file_count,
            "readmes": repo_node.readme_count
        });
    }
}

walker show_info {
    with entry {
        if (here.type == "repository") {
            report("");
            report("---------");
            report("REPOSITORY: " + here.name);
            report("URL: " + here.url);
            report("Local: " + here.local_path);
            report("Total files: " + str(here.file_count));
            report("Source files: " + str(here.source_file_count));
            report("README files: " + str(here.readme_count));
            if (here.file_tree_md and here.file_tree_md != "") {
                report("File tree (first 300 chars): " + here.file_tree_md[:300] + "...");
            }
            report("-----------");
        } elif (here.type == "readme") {
            report("README " + here.name + " - Preview: " + here.preview);
        }
    }
}
