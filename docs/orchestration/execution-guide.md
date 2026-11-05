# Execution guide

From the repository root:

    python -m orchestration.runtime.cli --root . create FV-001 "Estruturar inventario e sete caixas" --accept "limite logico sete" --accept "descarga sem duplicacao"
    python -m orchestration.runtime.cli --root . dispatch FV-001 architecture
    python -m unittest discover -s orchestration/tests

The first command persists the demand. The second creates a structured handoff for AGENT-02. A human forwards that package to the appropriate ChatGPT or Claude session and records the result in docs/evidence.
