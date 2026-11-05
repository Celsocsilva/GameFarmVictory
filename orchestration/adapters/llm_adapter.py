class LLMAdapter:
    """Interface only. No model calls are enabled by default."""
    enabled = False

    def run(self, package: dict) -> dict:
        raise RuntimeError("LLM automation is disabled; use manual_agent_adapter in assisted mode")
