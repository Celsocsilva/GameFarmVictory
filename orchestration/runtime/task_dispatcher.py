from pathlib import Path
import json

class Dispatcher:
    def __init__(self, config: Path):
        self.config = config
        self.agents = self._load()

    def _load(self):
        text = self.config.read_text(encoding="utf-8")
        agents = {}
        for line in text.splitlines():
            if line.startswith("  AGENT-"):
                key = line.split(":", 1)[0].strip()
                agents[key] = line
        return agents

    def select(self, domain: str) -> str:
        mapping = {"product":"AGENT-01","architecture":"AGENT-02","gameplay":"AGENT-03","art":"AGENT-04","ui":"AGENT-05","qa":"AGENT-06","devops":"AGENT-07","review":"AGENT-08","coordination":"AGENT-00"}
        if domain not in mapping:
            raise ValueError(f"unknown domain: {domain}")
        return mapping[domain]

    def package(self, task: dict, target_agent: str) -> dict:
        return {"schema_version": 1, "execution_id": task.get("execution_id", task["task_id"] + "-run-1"),
                "task_id": task["task_id"], "source_agent": "AGENT-00", "target_agent": target_agent,
                "objective": task["objective"], "inputs": task.get("inputs", []),
                "expected_outputs": task.get("expected_outputs", []),
                "acceptance_criteria": task["acceptance_criteria"],
                "dependencies": task.get("dependencies", []), "evidence": [], "status": "READY"}
