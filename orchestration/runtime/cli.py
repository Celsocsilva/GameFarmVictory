from pathlib import Path
import argparse, json
from .orchestrator import Orchestrator

def main() -> int:
    parser = argparse.ArgumentParser(description="TerraBela Farm assisted orchestration runtime")
    parser.add_argument("--root", default=".")
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("create")
    create.add_argument("task_id")
    create.add_argument("objective")
    create.add_argument("--accept", action="append", required=True)
    create.add_argument("--domain", default="product")
    dispatch = sub.add_parser("dispatch")
    dispatch.add_argument("task_id")
    dispatch.add_argument("domain")
    args = parser.parse_args()
    runtime = Orchestrator(Path(args.root).resolve())
    if args.command == "create":
        path = runtime.create({"task_id": args.task_id, "objective": args.objective, "acceptance_criteria": args.accept})
        print(path)
    else:
        print(json.dumps(runtime.dispatch(args.task_id, args.domain), indent=2, ensure_ascii=False))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
