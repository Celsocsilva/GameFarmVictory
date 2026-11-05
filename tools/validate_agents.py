"""Validate operational agent instructions and repository contracts."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
AGENTS = ROOT / "agents"
REQUIRED = [
    "Identidade", "missão", "Objetivos", "Competências", "fontes de contexto",
    "Ferramentas", "permissões", "limites", "Contrato de entrada",
    "Workflow detalhado", "Critérios de decisão", "aprovação humana",
    "Contrato de saída", "colaboração", "Falhas", "indicadores", "conclusão",
]
EXPECTED = {
    "orchestrator.md", "game-director.md", "godot-architect.md",
    "gameplay-engineer.md", "technical-artist.md", "mobile-uiux.md",
    "qa-engineer.md", "mobile-devops.md", "engineering-reviewer.md",
}
files = sorted(AGENTS / name for name in EXPECTED)
errors = []
if len(files) != 9:
    errors.append(f"expected 9 agent files, found {len(files)}")
for path in files:
    text = path.read_text(encoding="utf-8").lower()
    for marker in REQUIRED:
        if marker.lower() not in text:
            errors.append(f"{path.name}: missing '{marker}'")
if not (ROOT / "project.godot").exists():
    errors.append("project.godot missing")
if not (ROOT / "docs" / "evidence" / "README.md").exists():
    errors.append("docs/evidence/README.md missing")
if not (AGENTS / "operational-standard.md").exists():
    errors.append("agents/operational-standard.md missing")
for canonical in [f"agent-{i:02d}" for i in range(1, 9)]:
    if not any(p.name.startswith(canonical) for p in AGENTS.glob("*.md")):
        errors.append(f"canonical contract missing: {canonical}")
if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"validated {len(files)} operational agent contracts")
