import from py_helpers.diagrams { mermaid_from_ccg }
import from py_helpers.io_utils { write_text }
import from byllm.llm { Model }
import from os { getenv }

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
        graph = [root --> (`?CodeGraph) where .repo_name == repo_name][0]
        nodes = []
        edges = []
        for f in [graph --> (`?FileNode)] {
            nodes.append({"id":"file:"+f.path, "label":f.path})
            for fn in [f -> DEFINES -> (`?FuncNode)] {
                nodes.append({"id": "func:"+fn.name, "label": fn.name})
                edges.append({"src":"file:"+f.path, "dst":"func:"+fn.name, "type":"DEFINES"})
            }
            for cal in [f -> CALLS -> (`?FuncNode)] {
                edges.append({"src":"file:"+f.path, "dst":"func:"+cal.name, "type":"CALLS"})
            }
        }
        return mermaid_from_ccg(nodes, edges)
    }

    def synthesize_markdown(repo_name: str, overview: str, tree_md: str, readme_sum: str, diagram: str) -> str by llm_doc();
    def write_doc(repo_name: str, content: str) -> str by py {
        import os
        out_dir = os.path.join(os.getcwd(), "outputs", repo_name)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "docs.md")
        write_text(out_path, content)
        return out_path
    }

    def assemble(repo_name: str, overview: str, tree_md: str, readme_sum: str) -> DocBundle by py {
        diag = self.build_mermaid(repo_name)
        content = self.synthesize_markdown(repo_name, overview, tree_md, readme_sum, diag)
        path = self.write_doc(repo_name, content)
        return DocBundle(repo_name=repo_name, overview=overview, file_tree_md=tree_md, readme_summary=readme_sum, diagram=diag, output_path=path)
    }
}
