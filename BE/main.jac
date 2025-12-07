import from byllm.lib { Model }

include agent_core;
import from utils { get_current_datetime }

glob llm = Model(
    model_name = "gemini/gemini-2.0-flash",
    verbose = False
);



enum RoutingNodes {
    SUPERVISOR  = "Supervisor",
    REPO_MAPPER = "RepoMapper",
    CODE_ANALYZER = "CodeAnalyzer",
    DOC_GENIE   = "DocGenie",
    GENERAL_CHAT = "GeneralChat"
}

node Supervisor(Toolbox) {
    has last_plan: str = "";
    def route_and_run(utterance: str, history: str) -> str by llm(method = "Reason");
}

node RepoMapper(Toolbox) {
    has last_repo_url: str = "";
    has last_summary: str = "";
    has last_index: list[str] = [];
    def clone_repo(url: str) -> str;
    def build_file_index(repo_path: str) -> list[str];
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools = ([self.clone_repo, self.build_file_index])
    );
}

node CodeAnalyzer(Toolbox) {
    has last_target: str = "";
    def analyze_file(path: str) -> str;
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools = ([self.analyze_file])
    );
}

node DocGenie(Toolbox) {
    has last_doc_preview: str = "";
    def save_docs(repo_name: str, content: str) -> str;
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools = ([self.save_docs])
    );
}

node GeneralChat(Toolbox) {
    def chat(utterance: str, history: str) -> str by llm();
    def route_and_run(utterance: str, history: str) -> str by llm(
        method = "ReAct",
        tools = ([self.chat])
    );
}

walker codebase_genius(agent) {
    def route_to_node(utterance: str, history: str) -> str by llm();
}
