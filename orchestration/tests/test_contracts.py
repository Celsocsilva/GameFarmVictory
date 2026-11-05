import json, unittest
from pathlib import Path

class ContractTests(unittest.TestCase):
    def test_schemas_are_json(self):
        root = Path(__file__).parents[1] / "contracts"
        for path in root.glob("*.schema.json"):
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertIn("$schema", data)

if __name__ == "__main__":
    unittest.main()
