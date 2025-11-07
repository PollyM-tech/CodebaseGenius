include core;
import from byllm.llm { Model }
import from os { getenv }
import from py_helpers.ts_parse { collect_source_files, extract_symbols_and_calls }

glob llm = Model(model_name="gpt-4o", verbose=False);

node FileNode { has path: str = ""; }
node FuncNode { has name: str = ""; }
node ClassNode { has name: str = ""; }

edge DEFINES {}
edge CALLS {}
edge INHERITS {}
edge IMPORTS {}

node CodeGraph {
    has repo_name: str = "";
    has root_path: str = "";
}

node CodeAnalyzer(Toolbox) {
    def build_ccg(root_path: str, repo_name: str) -> CodeGraph {
        graph = CodeGraph(repo_name=repo_name, root_path=root_path);
        files = collect_source_files(root_path);

        for f in files {
            info = extract_symbols_and_calls(f);
            fnode = FileNode(path=f); graph ++> fnode;

            for cname in info["classes"] {
                c = ClassNode(name=cname);
                fnode ++> c;
                fnode -[DEFINES]-> c;
                }



            for fname in info["functions"] { 
                fn = FuncNode(name=fname); fnode ++> fn; fnode -:DEFINES-> fn; 
            }

            for call in info["calls"] { 
                callee = FuncNode(name=call); graph ++> callee; fnode -:CALLS-> callee; 
            }
        }
        return graph;
    }

    def query_calls(func_name: str, repo_name: str) -> list[str] {
        graphs = [root --> (`?CodeGraph) where .repo_name == repo_name];
        if not graphs { return []; }
        g = graphs[0];

        result = [];
        for f in [g --> (`?FileNode)] {
            if [f -:CALLS-> (`?FuncNode) where .name == func_name] {
                result = result + [f.path];
            }
        }
        return result;
    }

    def query_defined_in(func_name: str, repo_name: str) -> list[str] {
        graphs = [root --> (`?CodeGraph) where .repo_name == repo_name];
        if not graphs { return []; }
        g = graphs[0];

        result = [];
        for f in [g --> (`?FileNode)] {
            if [f -:DEFINES-> (`?FuncNode) where .name == func_name] {
                result = result + [f.path];
            }
        }
        return result;
    }

    def route_and_run(utterance: str, history: str) -> str by llm();
}