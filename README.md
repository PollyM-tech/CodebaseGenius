# Codebase Genius – Agentic Codebase Documentation Generator

Codebase Genius is a multi-agent system built in **JacLang + byLLM** that can:

# Features
- Multi-agent architecture (Supervisor, RepoMapper, CodeAnalyzer, DocGenie).
- Clones Git repositories and indexes `.py` / `.jac` files.
- Uses byLLM’s Reason/ReAct models for planning and tool execution.
- Outputs Markdown docs with diagrams.
- Includes a Streamlit frontend and Jac API backend.


## 1. Project Structure

CodebaseGenius/
├── BE/                      # Backend: Jac agents + API server
│   ├── agent_core.jac       # Shared Memory/Session + agent walker
│   ├── main.jac             # Agent nodes + codebase_genius orchestrator
│   ├── main.impl.jac        # Implementation of tools (clone, index, save docs)
│   ├── utils.jac            # Utility function(s), e.g. get_current_datetime
│   ├── outputs/
│   │   └── docs/            # Generated Markdown documentation goes here
│   ├── .env                 # Backend environment variables (GEMINI_API_KEY, etc.)
│   └── README.md            # (Optional) backend-specific readme
│
├── FE/                      # Frontend: Streamlit UI
│   └── app.py               # Web UI calling the Jac API server
│
├── CodebaseGenius/          # Python virtual environment (created locally)
│   ├── bin/
│   ├── lib/
│   └── ...
│
├── requirements.txt         # Python dependencies for FE + tooling
└── README.md                # This file

## Setup & Run

# Create environment
```bash
python3 -m venv CodebaseGenius
source CodebaseGenius/bin/activate
pip install -r requirements.txt

Configure .env in BE/.env
GEMINI_API_KEY=your_api_key
BACKEND_URL=http://0.0.0.0:8000

start backend -jac serve main.jac
GEMINI_API_KEY=your_api_key
BACKEND_URL=http://0.0.0.0:8000

start frontent in FE folder - cd FE
streamlit run app.py

API CALL example 
curl -X POST http://0.0.0.0:8000/walker/codebase_genius \
  -H "Content-Type: application/json" \
  -d '{"repo_url": "https://github.com/jaseci-labs/jac-lang"}'

Output
Generated docs are saved in:
BE/outputs/docs/<repo_name>.md

NB
If you see a RateLimitError, your Gemini free-tier quota is exhausted; the system still functions correctly.
Easily switch models or mock LLMs in main.jac (glob llm = Model(...)).

Credits
Built using:
JacLang
byLLM
Streamlit, GitPython, python-dotenv, and LiteLLM.

© 2025 Codebase Genius Project

