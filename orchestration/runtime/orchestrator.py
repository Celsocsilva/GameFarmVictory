from pathlib import Path
import json
from .state_machine import StateMachine
from .task_dispatcher import Dispatcher
from .evidence_manager import EvidenceManager

class Orchestrator:
    def __init__(self, root: Path):
        self.root = root
        self.state_dir = root / "orchestration" / "state"
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.dispatcher = Dispatcher(root / "orchestration" / "config" / "agents.yaml")
        self.evidence = EvidenceManager(root / "docs" / "evidence" / "runs")

    def create(self, task: dict) -> Path:
        task = dict(task)
        task.setdefault("status", "BACKLOG")
        task.setdefault("schema_version", 1)
        task["state_history"] = StateMachine().to_dict()
        path = self.state_dir / f"{task['task_id']}.json"
        if path.exists():
            raise FileExistsError(f"task already exists: {task['task_id']}")
        path.write_text(json.dumps(task, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        return path

    def load(self, task_id: str) -> dict:
        return json.loads((self.state_dir / f"{task_id}.json").read_text(encoding="utf-8"))

    def dispatch(self, task_id: str, domain: str) -> dict:
        task = self.load(task_id)
        machine = StateMachine.from_dict(task["state_history"])
        if machine.state == "BACKLOG": machine.transition("REFINEMENT", "orchestrator intake")
        if machine.state == "REFINEMENT": machine.transition("READY", "input complete")
        if machine.state == "READY": machine.transition("IN_PROGRESS", "dispatched")
        task["state_history"] = machine.to_dict()
        task["status"] = machine.state
        package = self.dispatcher.package(task, self.dispatcher.select(domain))
        task["last_handoff"] = package
        (self.state_dir / f"{task_id}.json").write_text(json.dumps(task, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        return package
