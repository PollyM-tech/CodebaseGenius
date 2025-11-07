import from dotenv { load_dotenv }
import from utils { get_current_datetime }

node Memory {}

node Session {
    has history: list = [];
    has created_at: str = get_current_datetime();

    def add_history(entry: str) {
        self.history = self.history + [entry];
    }

    def get_history -> str {
        return "\n".join(self.history[-12:]);
    }
}

node Toolbox {

    def route_and_run(utterance: str, history: str) -> str abs;
}

walker base_agent {
    has session_id: str = "";

    obj __specs__ { static has auth: bool = False; }

    def _ensure_session -> Session {
        mems = [root --> (`?Memory)];
        if not mems {
            mems = root ++> Memory();
        }
        memory = mems[0];

        if not self.session_id {
            sess = memory ++> Session();
            return sess[0];
        } else {
            return &(self.session_id);
        }
    }
}

walker get_sessions {
    obj __specs__ { static has auth: bool = False; }

    can get_sessions with `root entry {
        mems = [root --> (`?Memory)];
        if not mems {
            report [];
            disengage;
        }
        sess = [mems[0] --> (`?Session)];
        report [{
            "id": jid(s),
            "created_at": s.created_at,
            "history_len": len(s.history)
        } for s in sess];
    }
}

with entry { load_dotenv(); }

