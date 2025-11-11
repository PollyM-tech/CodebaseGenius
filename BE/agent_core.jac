import from dotenv { load_dotenv }
import from utils { get_current_datetime }
import from byllm.llm { Model }
import os;

glob llm = Model(model_name="gemini/gemini-1.5-flash", verbose=False);

node Memory {}

node Session {
    has history: list = [];
    has created_at: str = get_current_datetime();

    def add_history(entry: str) {
        self.history = self.history + [entry];
    }

    def get_history -> str {
        return "\n".join(self.history[-20:]);
    }
}

node Toolbox {
    def route_and_run(utterance: str, history: str) -> str abs;

    can execute with agent entry {
        session = visitor.session;
        response = self.route_and_run(visitor.utterance, session.get_history());
        session.add_history("user: " + visitor.utterance + "\nai: " + response);

        report {
            "session_id": jid(visitor.session),
            "response": response
        };
    }
}

def _get_node_class(class_name: str) {
    if class_name == "RepoMapper" { return RepoMapper; }
    if class_name == "CodeAnalyzer" { return CodeAnalyzer; }
    if class_name == "DocGenie" { return DocGenie; }
    if class_name == "GeneralChat" { return GeneralChat; }
    if class_name == "CodeGenius" { return CodeGenius; }
    return None;
}

def _ensure_outputs_tree() {
    folders = [
        "outputs",
        "outputs/repos",
        "outputs/trees",
        "outputs/readme",
        "outputs/ccg",
        "outputs/diagrams",
        "outputs/docs",
    ];
    for d in folders { os.makedirs(d, exist_ok=True); }
}

walker agent {
    has utterance: str = "";
    has session_id: str = "";

    obj __specs__ { static has auth: bool = False; }

    def get_node_class(class_name: str) { return _get_node_class(class_name); }
    def route_to_node(utterance: str, history: str) -> str abs;

    can execute with `root entry {
        memory_list = [root --> (`?Memory)];
        if not memory_list { memory_list = root ++> Memory(); }
        memory = memory_list[0];

        if not self.session_id { session_list = memory ++> Session(); self.session = session_list[0]; }
        else { self.session = &(self.session_id); }

        routed = self.route_to_node(self.utterance, self.session.get_history());
        node_cls = self.get_node_class(routed);
        if not node_cls { report { "response": "Unknown node: " + routed }; disengage; }

        inst = node_cls();
        linked = here ++> inst;
        visit linked;
    }
}

walker get_all_sessions {
    obj __specs__ { static has auth: bool = False; }

    can get_all_sessions with `root entry {
        memory_list = [here --> (`?Memory)];
        if not memory_list { report "No sessions found."; disengage; }
        memory = memory_list[0];
        sessions = [memory --> (`?Session)];

        report [
            { "id": jid(s), "created_at": s.created_at } for s in sessions
        ];
    }
}

with entry {
    load_dotenv();
    _ensure_outputs_tree();
}
