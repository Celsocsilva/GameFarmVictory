# FV-001 — prova inicial da orquestração

- Status: PASS para runtime assistido; BLOCKED para gameplay integral.
- Demanda: inventário e empilhamento visual de até sete caixas.
- Fluxo: AGENT-01 -> AGENT-02 -> AGENT-03 -> AGENT-04 -> AGENT-06 -> AGENT-08 -> AGENT-07 -> aprovação humana.
- Evidência executável: python -m unittest discover -s orchestration/tests.
- Limitação: não há gameplay suficiente nem Godot instalado para validar dispositivo real; isso não é declarado como teste do jogo.
