import unittest
from pathlib import Path
from orchestration.runtime.policy_engine import PolicyEngine, PolicyError

class PermissionTests(unittest.TestCase):
    def setUp(self):
        self.policy = PolicyEngine(Path.cwd())

    def test_sensitive_action_requires_approval(self):
        with self.assertRaises(PolicyError):
            self.policy.check_action("release")

    def test_path_escape_rejected(self):
        with self.assertRaises(PolicyError):
            self.policy.safe_path("../outside")

if __name__ == "__main__":
    unittest.main()
