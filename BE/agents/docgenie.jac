import from byllm.lib { Model }
import os;
import from utils { get_current_datetime }

# Initialize Gemini LLM
glob llm = Model(
    provider="gemini",
    model_name="gemini-2.5-flash",
    api_key=os.getenv("GEMINI_API_KEY"),
    verbose=false
);

# Node to store documentation history
node DocHistory {
    has summary: str;
    has documentation: str;
    has created_at: str = get_current_datetime();
}

# Main DocGenie node
node DocGenie {
    has history: list = [];

    # LLM ability — inline prompt
    def generate_docs(summary: str) -> str by llm(
        """
        You are a professional technical documentation generator.
        Given the following code summary, write clear, detailed, and developer-friendly documentation.
        Include purpose, logic flow, and possible use cases.

        Code Summary:
        {{summary}}
        """
    );

    # Store generated documentation in graph history
    def store_history(summary: str, documentation: str) {
        let entry = DocHistory(summary=summary, documentation=documentation);
        self ++> entry;
        self.history = self.history + [entry];
    }

    # Retrieve stored documentation history
    def show_history() -> list[DocHistory] {
        return [self --> (`?DocHistory)];
    }

    # Main entry point for DocGenie
    def run() {
        report("🧠 Running DocGenie using Gemini 2.5 Flash");

        let example_summary = "This module analyzes a repository and generates developer documentation using Jac and Gemini";
        let documentation = self.generate_docs(example_summary);

        report("✅ Generated Documentation:");
        report(documentation);

        # Store result
        self.store_history(example_summary, documentation);
        report("📘 Documentation stored in history");
    }
}

# Walker to run DocGenie
walker docgenie {
    with entry {
        report("Initializing DocGenie");

        let genie = spawn DocGenie();
        genie.run();

        report("DocGenie process complete");
    }
}
