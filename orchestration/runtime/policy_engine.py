from pathlib import Path
import json

LEVELS = {"OBSERVE": 0, "PROPOSE": 1, "IMPLEMENT": 2, "VALIDATE": 3, "SUBMIT": 4, "RELEASE": 5}
SENSITIVE = {"merge", "release", "publish", "force_push", "delete", "secret", "sign"}

class PolicyError(Exception):
    pass

class PolicyEngine:
    def __init__(self, workspace: Path):
        self.workspace = workspace.resolve()

    def check_level(self, level: int, required: str) -> None:
        if level < LEVELS[required]:
            raise PolicyError(f"permission level {level} insufficient for {required}")

    def check_action(self, action: str, human_approval: bool = False) -> None:
        if action.lower() in SENSITIVE and not human_approval:
            raise PolicyError(f"human approval required for sensitive action: {action}")

    def safe_path(self, path: str) -> Path:
        resolved = (self.workspace / path).resolve()
        if resolved != self.workspace and self.workspace not in resolved.parents:
            raise PolicyError("path outside authorized workspace")
        return resolved

    def validate_json(self, path: Path, required: list[str]) -> None:
        data = json.loads(path.read_text(encoding="utf-8"))
        missing = [key for key in required if key not in data]
        if missing:
            raise PolicyError(f"{path.name}: missing {missing}")
