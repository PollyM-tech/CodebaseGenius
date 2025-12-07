import os
import textwrap

import requests
import streamlit as st
from dotenv import load_dotenv


BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BACKEND_DIR = os.path.join(BASE_DIR, "BE")

ENV_PATH = os.path.join(BACKEND_DIR, ".env")
if os.path.exists(ENV_PATH):
    load_dotenv(ENV_PATH)

BACKEND_URL = os.getenv("BACKEND_URL", "http://0.0.0.0:8000")


def call_codebase_genius(repo_url: str, session_id: str | None = None) -> dict:
    """
    Call the Jac API walker `codebase_genius` with the given repo URL.

    The Jac server instantiates the walker via:
        walker_cls(**fields)

    Expected success shape (from agent_core Toolbox):
        {
            "session_id": "<node id>",
            "response": "<LLM text>"
        }

    On errors (like Gemini quota) the server returns:
        {
            "error": "...",
            "traceback": "..."
        }
    """
    payload: dict = {"repo_url": repo_url}
    if session_id:
        payload["session_id"] = session_id

    resp = requests.post(
        f"{BACKEND_URL}/walker/codebase_genius",
        json=payload,
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()


st.set_page_config(
    page_title="Codebase Genius",
    layout="wide",
    page_icon="",
)

st.title(" Codebase Genius")
st.markdown(
    "Agentic **Jac + byLLM** system for exploring and documenting a GitHub codebase."
)

st.caption(
    "Backend: Jac API server (`jac serve main.jac` in `BE/`)\n\n"
    "Frontend: Streamlit app calling `/walker/codebase_genius`."
)

if "session_id" not in st.session_state:
    st.session_state["session_id"] = ""


with st.sidebar:
    st.header("⚙️ Backend status")
    st.markdown(f"**Backend URL:** `{BACKEND_URL}`")

    if st.button("🔍 Check walkers"):
        try:
            r = requests.get(f"{BACKEND_URL}/walkers", timeout=10)
            st.success("Connected to backend.")
            st.json(r.json())
        except Exception as e:
            st.error(f"Could not reach backend: {e}")

    st.markdown("---")
    st.subheader(" Session control")
    current_session_id = st.text_input(
        "Current session_id (optional)",
        value=st.session_state["session_id"],
        help=(
            "If left blank, the backend creates a new Session node.\n"
            "Re-use a previous session_id to keep conversation / analysis history."
        ),
    )
    st.session_state["session_id"] = current_session_id

    st.markdown("---")
    st.subheader(" About")
    st.markdown(
        "- Multi-agent backend in Jac\n"
        "- byLLM Reason / ReAct for tool-calling\n"
        "- Streamlit UI for assignment demo"
    )

left_col, right_col = st.columns([1.1, 1])

with left_col:
    st.subheader(" Enter GitHub repository URL")

    repo_url = st.text_input(
        "Repository URL",
        value="https://github.com/jaseci-labs/jac-lang",
        placeholder="https://github.com/username/repo.git",
    )

    st.caption(
        "Codebase Genius routes your request through **Supervisor → RepoMapper → "
        "CodeAnalyzer → DocGenie** using byLLM ReAct agents."
    )

    analyze_clicked = st.button(
        " Generate / Analyze Documentation",
        type="primary",
        use_container_width=True,
    )

with right_col:
    st.subheader(" Agent response")

    if analyze_clicked:
        if not repo_url.strip():
            st.error("Please provide a GitHub repository URL.")
        else:
            with st.spinner("Calling Jac backend and LLM agents..."):
                try:
                    result = call_codebase_genius(
                        repo_url=repo_url.strip(),
                        session_id=st.session_state["session_id"] or None,
                    )
                except requests.exceptions.ConnectionError:
                    st.error(
                        "Could not connect to the Jac API server.\n\n"
                        "Make sure you have run:\n\n"
                        "`cd BE && jac serve main.jac`"
                    )
                    result = None
                except requests.HTTPError as e:
                    st.error(f"HTTP error from backend: {e}")
                    result = None
                except Exception as e:
                    st.error(f"Unexpected error: {e}")
                    result = None

                if result is not None:
                    if "error" in result:
                        st.error("Backend reported an error:")
                        st.code(result["error"], language="text")

                        if result.get("traceback"):
                            with st.expander(
                                "Show traceback (developer details)", expanded=False
                            ):
                                st.code(result.get("traceback", ""), language="text")
                    else:
                        session_id = result.get("session_id", "")
                        response_text = result.get("response", "")

                        if session_id:
                            st.session_state["session_id"] = session_id

                        if response_text:
                            st.success("Agent response:")
                            st.markdown(response_text)
                        else:
                            st.info(
                                "Request completed, but the agent did not return a "
                                "`response` field. Check the raw JSON below."
                            )

                        if session_id:
                            st.info(f"Active Session ID: `{session_id}`")

                    with st.expander("Raw JSON response"):
                        st.json(result)
    else:
        st.info(
            "Click **' Generate / Analyze Documentation'** to run the multi-agent "
            "pipeline on the selected repository."
        )



st.markdown("---")
st.subheader(" How this UI maps to the assignment")

st.markdown(
    textwrap.dedent(
        """
        - **Multi-agent backend in Jac**:
          - Nodes: `Supervisor`, `RepoMapper`, `CodeAnalyzer`, `DocGenie`, `GeneralChat`
          - `Toolbox` base node handles LLM calls and session history updates.
        - **Orchestrator walker**: `codebase_genius` (inherits from `agent` in `agent_core.jac`)
          - Accepts `repo_url` (and optional `session_id`).
          - Calls `route_to_node(...)` using byLLM with `method="Reason"`.
        - **ReAct-style tools**:
          - `RepoMapper`: `clone_repo`, `build_file_index`
          - `CodeAnalyzer`: `analyze_file`
          - `DocGenie`: `save_docs`
        - **Persistent session**:
          - `Memory` and `Session` nodes store conversation history + timestamps.
          - `agent` walker manages `session_id` and routes between agents.
        - **Frontend responsibilities**:
          - Sends `POST /walker/codebase_genius` with `repo_url` (and optional `session_id`).
          - Shows either:
            - the agent-generated `response`, or
            - any LLM / backend errors (e.g. Gemini 429 quota) in a clear way.
        """
    )
)
