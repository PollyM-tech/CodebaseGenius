import from byllm.lib { Model }

glob llm = Model(model_name = "gemini/gemini-2.0-flash", verbose = False);

def echo_smart(text: str) -> str by llm();

with entry {
    result = echo_smart("Say: Jac + byLLM is working.");
    print(result);
}
