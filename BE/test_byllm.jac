import from byllm.lib { Model }

glob llm = Model(
    model_name = "gemini/gemini-2.0-flash",
    verbose = True
);

"""Simple connection test with Gemini via byLLM."""
def test_connection() -> str by llm();

with entry {
    print("🚀 Calling Gemini via byLLM...");
    result = test_connection();
    print("\n✅ Gemini API test result:\n" + result);
}
