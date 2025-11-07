include core;
import from byllm.llm { Model }
import from py_helpers.diagrams { mermaid_from_ccg }
import from py_helpers.io_utils { write_text }

glob llm = Model(model_name="gpt-4o", verbose=False);

node DocBundle {
    has repo_name: str = "";
    has overview: str = "";
    has file_tree_md: str = "";
    has readme_summary: str = "";
    has api_notes: str = "";
    has diagram: str = "";
    has output_path: str = "";
}

node DocGenie(Toolbox) {
    def build_mermaid(repo_name: str) -> str {
        graphs = [root --> (`?CodeGraph)];
        g = null;
        for gg in graphs { if gg.repo_name == repo_name { g = gg; break; } }
        if not g { return ""; }

        nodes = [];
        edges = [];
        for f in [g --> (`?FileNode)] {
            nodes = nodes + [{"id":"file:"+f.path, "label":f.path}];
            for fn in [f ->:DEFINES:-> (`?FuncNode)] {
                nodes = nodes + [{"id":"func:"+fn.name, "label":fn.name}];
                edges = edges + [{"src":"file:"+f.path, "dst":"func:"+fn.name, "type":"DEFINES"}];
            }
            for cal in [f ->:CALLS:-> (`?FuncNode)] {
                edges = edges + [{"src":"file:"+f.path, "dst":"func:"+cal.name, "type":"CALLS"}];
            }
        }
        return mermaid_from_ccg(nodes, edges);
    }

    def synthesize_markdown(repo_name: str, overview: str, tree_md: str, readme_sum: str, diagram: str) -> str by llm();

    def write_doc(repo_name: str, content: str) -> str {
        out_dir = "outputs/" + repo_name;
        path = out_dir + "/docs.md";
        write_text(path, content);
        return path;
    }

    def assemble(repo_name: str, overview: str, tree_md: str, readme_sum: str) -> DocBundle {
        diag = self.build_mermaid(repo_name);
        content = self.synthesize_markdown(repo_name, overview, tree_md, readme_sum, diag);
        path = self.write_doc(repo_name, content);
        return DocBundle(repo_name=repo_name, overview=overview, file_tree_md=tree_md, readme_summary=readme_sum, diagram=diag, output_path=path);
    }

    def route_and_run(utterance: str, history: str) -> str by llm(
        method="ReAct",
        tools=([self.build_mermaid, self.synthesize_markdown, self.write_doc, self.assemble])
    );
}

sem DocGenie.synthesize_markdown = "Create a single Markdown document for the repository named {repo_name}.\\nSections:\\n# {repo_name}: Technical Overview\\n## Repository Overview\\n<use `overview`>\\n\\n## File Tree (Top-Level)\\n```text\\n<use `tree_md`>\\n```\\n\\n## README Highlights\\n<use `readme_sum` or 'No README found.'>\\n\\n## Code Context Diagram\\n<embed the Mermaid block verbatim>\\n<use `diagram`>\\n\\n## API & Key Functions\\nSummarize important functions/classes inferred from context. Be concise and actionable.";

sem DocGenie.route_and_run = "If the user asks to 'assemble' or 'write docs', call assemble(repo_name, overview, tree_md, readme_sum). If they ask only for a diagram, call build_mermaid(repo_name). Otherwise, draft the Markdown via synthesize_markdown then write_doc. Return a short confirmation with the output path or the Mermaid block when relevant. Select and execute only one tool.";
