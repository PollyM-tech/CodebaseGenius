agentic_codebase_genius/
├── BE/
│   ├── requirements.txt
│   ├── .env.example
│   ├── jac/
│   │   ├── core.jac                 # for the Memory/Session + common walker base
│   │   ├── utils.jac                # small helpers
│   │   ├── repo_mapper.jac          # Repo Mapper (agent)
│   │   ├── code_analyzer.jac        # Code Analyzer (agent)
│   │   ├── docgenie.jac             # DocGenie (agent)
│   │   └── code_genius.jac          # Code Genius (Supervisor agent) + API walkers
│   └── py_helpers/
│       ├── __init__.py
│       ├── git_ops.py
│       ├── fs_map.py
│       ├── readme.py
│       ├── ts_parse.py
│       ├── diagrams.py
│       └── io_utils.py
├── FE/
│   ├── requirements.txt
│   └── app.py
└── outputs/
