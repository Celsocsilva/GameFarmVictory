import unittest
from orchestration.runtime.state_machine import StateMachine

class StateMachineTests(unittest.TestCase):
    def test_valid_flow(self):
        machine = StateMachine()
        for state in ["REFINEMENT","READY","IN_PROGRESS","CODE_REVIEW","TESTING","AWAITING_APPROVAL","MERGE_READY","DONE"]:
            machine.transition(state)
        self.assertEqual(machine.state, "DONE")

    def test_invalid_transition(self):
        with self.assertRaises(ValueError):
            StateMachine().transition("DONE")

if __name__ == "__main__":
    unittest.main()
