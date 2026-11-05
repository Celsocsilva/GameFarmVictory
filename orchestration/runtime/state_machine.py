from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List

STATES = ["BACKLOG","REFINEMENT","READY","IN_PROGRESS","CODE_REVIEW","TESTING","AWAITING_APPROVAL","MERGE_READY","DONE","BLOCKED","FAILED","CANCELLED"]
TRANSITIONS = {
    "BACKLOG": {"REFINEMENT","CANCELLED"}, "REFINEMENT": {"READY","BLOCKED","FAILED"},
    "READY": {"IN_PROGRESS","BLOCKED","CANCELLED"}, "IN_PROGRESS": {"CODE_REVIEW","BLOCKED","FAILED"},
    "CODE_REVIEW": {"TESTING","IN_PROGRESS","BLOCKED"}, "TESTING": {"AWAITING_APPROVAL","IN_PROGRESS","FAILED"},
    "AWAITING_APPROVAL": {"MERGE_READY","BLOCKED","CANCELLED"}, "MERGE_READY": {"DONE","IN_PROGRESS","BLOCKED"},
    "BLOCKED": {"REFINEMENT","READY","CANCELLED"}, "FAILED": {"REFINEMENT","CANCELLED"},
}

@dataclass
class StateMachine:
    state: str = "BACKLOG"
    history: List[dict] = field(default_factory=list)

    def transition(self, target: str, reason: str = "") -> str:
        if target not in STATES or target not in TRANSITIONS.get(self.state, set()):
            raise ValueError(f"invalid transition {self.state} -> {target}")
        old = self.state
        self.state = target
        self.history.append({"from": old, "to": target, "reason": reason, "at": datetime.now(timezone.utc).isoformat()})
        return target

    def to_dict(self) -> dict:
        return {"state": self.state, "history": self.history}

    @classmethod
    def from_dict(cls, data: dict) -> "StateMachine":
        return cls(state=data["state"], history=data.get("history", []))
