### CodebaseGenius

## My project structure 
CodebaseGenius/BE/
│
├── agents/
│   ├── code_analyzer.jac   → analyzes repo structure, dependencies, metrics
│   ├── docgenie.jac        → generates documentation via Gemini LLM
│   ├── repo_mapper.jac     → clones & maps repos (foundation walker)
│   └── supervisor.jac      → coordinates multi-agent workflows (optional)
│
├── py_helpers/
│   ├── parse_python.py     → Python helper functions (clone_repo, etc.)
│
├── outputs/                → stores generated reports, docs, file trees
│
├── main.jac                → entrypoint (imports and runs walkers)
│
└── venv/                   → virtual environment
