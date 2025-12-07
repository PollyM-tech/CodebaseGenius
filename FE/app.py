import os
import subprocess
import textwrap
from uuid import uuid4

import streamlit as st
from dotenv import load_dotenv 

# Base paths
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BACKEND_DIR = os.path.join(BASE_DIR, "BE")

# Point to BE/.env and load it
ENV_PATH = os.path.join(BACKEND_DIR, ".env")
if os.path.exists(ENV_PATH):
    load_dotenv(ENV_PATH)

