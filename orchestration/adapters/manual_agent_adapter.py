class ManualAgentAdapter:
    """Assisted mode adapter: packages work; a human forwards it to ChatGPT/Claude."""
    mode = "assisted"
    api_required = False

    def prepare(self, handoff: dict) -> dict:
        return {"mode": self.mode, "instructions": "Forward this package to the assigned session and record its response.", "handoff": handoff}
