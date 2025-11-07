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
        root ++> graph;

        files = collect_source_files(root_path);
        for f in files {
            fnode = FileNode(path=f);
            graph ++> fnode;

            info = extract_symbols_and_calls(f);

            for cname in info["classes"] {
                c = ClassNode(name=cname);
                graph ++> c;
                fnode +>:DEFINES:+> c;
            }

            for fname in info["functions"] {
                fn = FuncNode(name=fname);
                graph ++> fn;
                fnode +>:DEFINES:+> fn;
            }

            for call in info["calls"] {
                existing = [];
                for cand in [graph --> (`?FuncNode)] {
                    if cand.name == call {
                        existing = existing + [cand];
                    }
                }
                callee = existing and existing[0] or FuncNode(name=call);
                if not existing { graph ++> callee; }
                fnode +>:CALLS:+> callee;
            }
        }
        return graph;
    }

    def query_calls(func_name: str, repo_name: str) -> list[str] {
        graphs = [root --> (`?CodeGraph)];
        g = null;
        for gg in graphs { if gg.repo_name == repo_name { g = gg; break; } }
        if not g { return []; }

        result = [];
        for f in [g --> (`?FileNode)] {
            matches = false;
            for callee in [f ->:CALLS:->] {
                if callee.name == func_name { matches = true; break; }
            }
            if matches { result = result + [f.path]; }
        }
        return result;
    }

    def query_defined_in(func_name: str, repo_name: str) -> list[str] {
        graphs = [root --> (`?CodeGraph)];
        g = null;
        for gg in graphs { if gg.repo_name == repo_name { g = gg; break; } }
        if not g { return []; }

        result = [];
        for f in [g --> (`?FileNode)] {
            found = false;
            for sym in [f ->:DEFINES:->] {
                if sym.name == func_name { found = true; break; }
            }
            if found { result = result + [f.path]; }
        }
        return result;
    }

    def route_and_run(utterance: str, history: str) -> str by llm(
        method="ReAct",
        tools=([self.build_ccg, self.query_calls, self.query_defined_in])
    );
}

sem CodeAnalyzer.route_and_run = """
You are a Code Analyzer.
- If the user asks to build/parse, call build_ccg(root_path, repo_name).
- If the user asks 'who calls <X>', call query_calls(<X>, repo_name).
- If the user asks 'where is <X> defined', call query_defined_in(<X>, repo_name).
Reply with a short plain-text summary. Select and execute only one tool.
""";
