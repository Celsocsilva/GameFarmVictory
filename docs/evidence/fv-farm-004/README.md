# FV-FARM-004 — evidências de revisão

Godot 4.7.2, renderizador Mobile, câmera da cena `farm_world.tscn`.

- `01-empty.png`: terreno inicial antes de semear.
- `02-before-depth.png`: tomateiros maduros ocultos pelo plano transparente do solo, antes da prioridade de desenho.
- `03-seed-bursts.png`: teste de estresse que disparou 20 punhados simultâneos. Mostra as sementes 3× maiores, mas não representa a cadência normal da caminhada.
- `04-mature-after.png`: mesmos tomateiros maduros com prioridade de desenho corrigida; visíveis em posições regulares.

O teste `tools/farm_smoke.gd` confirmou 60 células únicas, plantio possível na frente e no fundo, ausência de duplicação e cobertura lógica de 60/60. Ele não simula joystick manual nem comprova a fluidez durante uma partida completa. A captura de sementes indica que o efeito simultâneo em excesso ainda requer calibração visual em gameplay normal.

Mudanças: a grade passou de 4 colunas × 7 fileiras por módulo (112 posições) para 3 sulcos × 5 fileiras por módulo (60 posições). Os limites vêm da colisão de cada módulo. O material do solo recebe prioridade -1 e o sprite da planta prioridade +1, mantendo teste de profundidade ativo.

Pendências de aceite: percurso manual da frente e do fundo, capturas de estágios intermediários, desempenho com 60 plantas, trajetória de um único punhado e revisão em dispositivo Android. Nenhum Pull Request deve ser mesclado antes dessa verificação.
