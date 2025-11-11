import streamlit as st
import requests
import json
import os

BACKEND = os.getenv("CBG_BACKEND", "http://127.0.0.1:8000")

ENDPOINTS = {
    "supervisor": f"{BACKEND}/walker/supervisor",
    "generate_full_docs": f"{BACKEND}/walker/generate_full_docs",
    "list_artifacts": f"{BACKEND}/walker/list_artifacts"
}

st.set_page_config(page_title="Codebase Genius", layout="centered")

# --- MAIN UI ---
st.title("🤖 Codebase Genius")
st.write("Generate documentation and diagrams from any public GitHub repository.")

# --- INPUT BOX ---
github_url = st.text_input(
    "GitHub Repository URL",
    placeholder="https://github.com/user/repo",
)

# --- RUN PIPELINE ---
if st.button("🚀 Run Full Pipeline", use_container_width=True):
    if not github_url.strip():
        st.error("Please enter a valid GitHub repository URL.")
    else:
        payload = {"url": github_url}
        with st.spinner("Cloning, analyzing, and generating documentation..."):
            try:
                r = requests.post(ENDPOINTS["generate_full_docs"], json=payload)
                data = r.json()
                st.success("Pipeline complete!")

                st.subheader("📄 Generated Files")
                for f in data.get("artifacts", []):
                    st.code(f, language="text")

            except Exception as e:
                st.error(f"Error running pipeline: {e}")

st.markdown("---")

# --- LIST ALL ARTIFACTS ---
st.subheader("📁 Existing Artifacts")
if st.button("🔍 Refresh Artifact List", use_container_width=True):
    try:
        r = requests.post(ENDPOINTS["list_artifacts"])
        files = r.json()
        if files:
            for f in files:
                st.code(f, language="text")
        else:
            st.info("No artifacts found.")
    except Exception as e:
        st.error(f"Error loading artifacts: {e}")

# Footer
st.markdown("---")
st.caption("Codebase Genius • Multi-Agent Automated Code Documentation System")
