Codebase Genius

## Multi-Agent Automated Code Documentation System
1. Project Overview

Purpose:
Codebase Genius is a multi-agent system that automatically analyzes GitHub repositories, generates documentation, diagrams, and structured summaries for easier understanding of codebases.

# Key Features:

Clone and parse any public GitHub repository

Generate README summaries

Create API documentation from code structure

Generate Mermaid diagrams of function/class dependencies

Multi-agent architecture with specialized nodes for chat, code analysis, and documentation

2. Architecture

Nodes (Agents):

RepoMapper – Clones repositories and maps the file tree

CodeAnalyzer – Analyzes source code, tracks function definitions and calls

DocGenie – Generates documentation and diagrams

GeneralChat – Handles general conversational queries

CodeGenius – Orchestrates the pipeline for full repository analysis

Walkers:

codegenius_route – Determines which agent should handle a given query

generate_full_docs – Runs the full documentation pipeline

list_artifacts – Lists all generated documentation files

3. Requirements

Python 3.11+

Jac 0.8.10+

Streamlit (for front-end UI)

Git installed on your machine

4. Installation
# Clone the repo
git clone <your_repo_url>
cd CodebaseGenius

# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # Linux / Mac
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt


## for linux
set CBG_BACKEND=http://127.0.0.1:8000

# Run backend
jac serve main.jac

# For frontend run FE
streamlit run app.py

