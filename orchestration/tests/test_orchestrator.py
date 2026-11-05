import shutil, unittest
from pathlib import Path
from orchestration.runtime.orchestrator import Orchestrator

class OrchestratorTests(unittest.TestCase):
    def test_duplicate_and_dispatch(self):
        root = Path(__file__).parents[1]
        work = Path.cwd() / "orchestration" / ".test-runtime"
        if work.exists():
            shutil.rmtree(work)
        try:
            (work / "orchestration/config").mkdir(parents=True)
            source = root / "config/agents.yaml"
            (work / "orchestration/config/agents.yaml").write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
            runtime = Orchestrator(work)
            runtime.create({"task_id":"FV-001","objective":"Inventory seven boxes","acceptance_criteria":["capacity is seven"]})
            handoff = runtime.dispatch("FV-001", "architecture")
            self.assertEqual(handoff["target_agent"], "AGENT-02")
            with self.assertRaises(FileExistsError):
                runtime.create({"task_id":"FV-001","objective":"duplicate","acceptance_criteria":["x"]})
        finally:
            if work.exists():
                shutil.rmtree(work)

if __name__ == "__main__":
    unittest.main()
