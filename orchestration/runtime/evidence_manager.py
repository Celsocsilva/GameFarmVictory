from datetime import datetime, timezone
from pathlib import Path
import json
import uuid

class EvidenceManager:
    def __init__(self, root: Path):
        self.root = root
        self.root.mkdir(parents=True, exist_ok=True)

    def record(self, task_id: str, agent: str, result: str, actions: list, **extra) -> Path:
        if result not in {"PASS", "FAIL", "BLOCKED", "INCOMPLETE"}:
            raise ValueError("invalid evidence result")
        execution_id = extra.pop("execution_id", str(uuid.uuid4()))
        payload = {"execution_id": execution_id, "task_id": task_id, "agent": agent,
                   "actions": actions, "result": result,
                   "recorded_at": datetime.now(timezone.utc).isoformat(), **extra}
        path = self.root / f"{execution_id}.json"
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        return path
