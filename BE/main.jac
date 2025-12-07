import from byllm.lib { Model }
include agent_core;
import from utils { get_current_datetime }

glob llm = Model(
    model_name = "gemini/gemini-2.0-flash",
    verbose = False
);

obj RepoConfig {
    has url: str;
    has name: str;
    has local_path: str;
}

obj FileInfo {
    has path: str;
    has language: str;
    has is_entry_point: bool;
    has size_bytes: int;
}

obj SymbolInfo {
    has name: str;
    has kind: str;
    has file_path: str;
    has calls: list[str];
    has parents: list[str];
}

obj FileDoc {
    has file_path: str;
    has role: str;
    has summary: str;
    has key_functions: list[str];
    has important_flows: list[str];
}

obj RepoDoc {
    has overview: str;
    has install: str;
    has usage: str;
    has architecture: str;
    has api_reference: str;
    has diagram_text: str;
}

obj WorkUnit {
    has description: str;
    has agent_type: RoutingNodes;
    has repo_url: str;
    has repo_name: str;
    has target_files: list[str];
}

enum RoutingNodes {
    SUPERVISOR   = "Supervisor",
    REPO_MAPPER  = "RepoMapper",
    CODE_ANALYZER = "CodeAnalyzer",
    DOC_GENIE    = "DocGenie",
    GENERAL_CHAT = "GeneralChat"
}

node Supervisor(Toolbox) {
    has repo: RepoConfig;
    has files: list[FileInfo] = [];
    has symbols: list[SymbolInfo] = [];
    has work_plan: list[WorkUnit] = [];
    has last_plan_summary: str = "";

    def plan_work(utterance: str, history: str) -> list[WorkUnit] by llm(method = "Reason");
    def summarize_state() -> str by llm();
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools  = ([self.plan_work, self.summarize_state])
    );
}

node RepoMapper(Toolbox) {
    has last_repo_url: str = "";
    has last_repo_path: str = "";
    has last_summary: str = "";
    has last_index: list[str] = [];

    def clone_repo(url: str) -> str;
    def build_file_index(repo_path: str) -> list[str];
    def summarize_readme(repo_path: str) -> str by llm();
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools  = ([self.clone_repo, self.build_file_index, self.summarize_readme])
    );
}

node CodeAnalyzer(Toolbox) {
    has last_target: str = "";
    has analyzed_files: list[str] = [];
    has symbols: list[SymbolInfo] = [];

    def analyze_file(path: str) -> str;
    def build_ccg(file_paths: list[str]) -> list[SymbolInfo] by llm();
    def get_entry_points(symbols: list[SymbolInfo]) -> list[SymbolInfo] by llm();
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools  = ([self.analyze_file, self.build_ccg, self.get_entry_points])
    );
}

node DocGenie(Toolbox) {
    has last_repo_doc: RepoDoc;
    has last_doc_preview: str = "";
    has last_file_docs: list[FileDoc] = [];

    def generate_file_doc(file: FileInfo, symbols: list[SymbolInfo]) -> FileDoc by llm();
    def generate_repo_doc(
        repo: RepoConfig,
        files: list[FileInfo],
        symbols: list[SymbolInfo],
        file_docs: list[FileDoc]
    ) -> RepoDoc by llm(method = "Reason");
    def generate_diagram_text(
        repo: RepoConfig,
        symbols: list[SymbolInfo]
    ) -> str by llm();
    def save_docs(repo_name: str, content: str) -> str;
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools  = ([self.generate_file_doc, self.generate_repo_doc,
                   self.generate_diagram_text, self.save_docs])
    );
}


node GeneralChat(Toolbox) {
    def chat(utterance: str, history: str) -> str by llm();
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools  = ([self.chat])
    );
}

walker codebase_genius(agent) {
    has repo_url: str = "";

    def route_to_node(utterance: str, history: str) -> str by llm(method = "Reason");

    can generate_docs with `root entry {
        if not self.repo_url {
            self.utterance = "Explain what Codebase Genius can do.";
        } else {
            self.utterance =
                "Generate complete documentation for repository: " + self.repo_url +
                ". Use RepoMapper to clone and index, CodeAnalyzer for structure, " +
                "and DocGenie for Markdown documentation.";
        }

        memory_list = [root --> (`?Memory)];
        if not memory_list {
            memory_list = root ++> Memory();
        }
        memory = memory_list[0];

        if not self.session_id {
            session_list = memory ++> Session();
            self.session = session_list[0];
        } else {
            self.session = &(self.session_id);
            if not self.session {
                session_list = memory ++> Session();
                self.session = session_list[0];
            }
        }

        routed_class_name = self.route_to_node(
            self.utterance,
            self.session.get_history()
        );

        node_cls = self.get_node_class(routed_class_name);
        if not node_cls {
            print("Failed to get node class:", routed_class_name);
            report {
                "session_id": jid(self.session),
                "response": "Internal error: could not route to agent '" +
                            routed_class_name + "'."
            };
            return;
        }

        visit [-->(`?node_cls)] else {
            attached_routed_node = here ++> node_cls();
            visit attached_routed_node;
        }
    }
}
