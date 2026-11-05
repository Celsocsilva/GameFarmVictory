from pathlib import Path

class GodotAdapter:
    def __init__(self, executable: str | None = None):
        self.executable = executable

    def available(self) -> bool:
        return bool(self.executable and Path(self.executable).exists())

    def validate(self):
        if not self.available():
            return {"result": "INCOMPLETE", "reason": "Godot executable not configured"}
        raise NotImplementedError("Host-specific headless command must be configured explicitly")
