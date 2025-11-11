import from byllm.llm { Model }
include agent_core;

glob llm = Model(model_name="gemini/gemini-1.5-flash", verbose=False);

enum RoutingNodes {
    GENERAL_CHAT = "GeneralChat",
    REPO_MAPPER  = "RepoMapper",
    CODE_ANALYZER = "CodeAnalyzer",
    DOC_GENIE     = "DocGenie",
    CODE_GENIUS   = "CodeGenius"
}

node RepoMapper(Toolbox) {
    def do_clone(url: str) -> RepoInfo;
    def map_tree(local_path: str) -> str;
    def readme_digest(local_path: str) -> str;
    def route_and_run(utterance: str, history: str) -> str
        by llm(tools=[self.do_clone, self.map_tree, self.readme_digest]);
}

node CodeAnalyzer(Toolbox) {
    has last_ccg: str = "";
    def parse_sources(local_path: str) -> str;
    def who_calls(symbol: str) -> list;      
    def where_defined(symbol: str) -> list;  
    def route_and_run(utterance: str, history: str) -> str
        by llm(tools=[self.parse_sources, self.who_calls, self.where_defined]);
}

node DocGenie(Toolbox) {
    def overview(repo: RepoInfo, tree_md: str, readme_sum: str) -> DocArtifact;
    def api_docs(ccg_json_path: str) -> DocArtifact;
    def diagrams(ccg_json_path: str) -> DocArtifact;
    def route_and_run(utterance: str, history: str) -> str
        by llm(tools=[self.overview, self.api_docs, self.diagrams]);
}

node GeneralChat(Toolbox) {
    def chat(utterance: str, history: str) -> str by llm();
    def route_and_run(utterance: str, history: str) -> str
        by llm(tools=[self.chat]);
}

node CodeGenius(Toolbox) {
    has repo: RepoInfo;
    has tree_md: str = "";
    has readme_summary: str = "";
    has ccg_json: str = "";
    has docs_paths: list = [];
    def prioritize_files(ccg_json_path: str) -> list;
    def run_pipeline(url: str) -> str;
    def route_and_run(utterance: str, history: str) -> str
        by llm(tools=[self.run_pipeline, self.prioritize_files]);
}


walker codegenius_route(agent) {
    def route_to_node(utterance: str, history: str) -> RoutingNodes by llm();
}

walker generate_full_docs {
    has url: str = "";
    has session_id: str = "";
    obj __specs__ { static has auth: bool = False; }
    can generate_full_docs with root entry;    
} 
 

walker list_artifacts {
    obj __specs__ { static has auth: bool = False; }
    can list_artifacts with root entry;         
}

