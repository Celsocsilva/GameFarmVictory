# PROMPT PARA CODEX — FV-HARVEST-001

Atue como um time de 9 especialistas em Godot, gameplay, efeitos visuais, technical art, design de sistemas, inventário, QA, performance e release, coordenados por um líder técnico. Integre **a colheita automática de tomates maduros com sucção e mochila de até sete caixas empilhadas** ao TerraBela Farm. O repositório oficial é https://github.com/Celsocsilva/GameTerraBelaFarm (branch principal `main`). Inspecione a versão real do Godot, a estrutura de cenas, os scripts e os recursos disponíveis antes de modificar.

## Escopo inegociável
- Reutilize o `PlantingGrid`, as posições de cultivo e o `CropGrowthManager` existentes. A colheita inicia **somente** nas células com frutos maduros.
- O fazendeiro continua caminhando; ao se aproximar, tomates grandes e vermelhos destacam-se visualmente do pé e são atraídos, individualmente, até um marcador de sucção sobre a mochila.
- Use os PNGs RGBA entregues em `assets/`. Não transforme a imagem `crate_stack_7_reference.png` em um objeto que aparece inteiro ao colher um fruto. A pilha deve ser construída progressivamente usando sprites de caixas individuais.
- A pilha é de **no máximo sete caixas**; com a mochila cheia, a colheita pausa e o usuário deve ser orientado a descarregar na bancada, que será conectada em etapa posterior.
- Não alterar câmera, joystick, movimentação, topologia do terreno, distribuição das plantas ou regras da semeadura.

## Divisão coordenada do trabalho
1. **Tech Lead / Orchestrator:** diagnóstico, contratos entre módulos, plano e integração.
2. **World & Spatial Engineer:** identificar pontos de origem 3D corretos na planta e marcador de destino móvel na mochila; validar frente e fundo do campo.
3. **Gameplay Engineer:** detecção de proximidade, seleção determinística de células `RIPE`, cooldown e coleta contínua durante o movimento.
4. **VFX Engineer:** animação individual dos frutos em curva usando `Tween`/interpolação por frame, destino dinâmico, rastro discreto e efeito de chegada.
5. **Technical Artist:** recorte, transparência, escala, ancoragem e depth de `Sprite3D`/material; evitar imagens abaixo do terreno.
6. **Inventory Engineer:** contagem de tomates, reservas transacionais, confirmação e reversão em cancelamento; sete caixas com capacidade configurável.
7. **Backpack Animation Engineer:** pilha dinâmica presa ao fazendeiro, uma caixa parcial/cheia, incremento visual discreto e altura legível na câmera.
8. **QA Engineer:** testes automáticos e evidências visuais com cenários frente/meio/fundo e mochila 0/1/8/9/55/56.
9. **Integration / Release Engineer:** verificação da engine, testes de regressão e preparação de Pull Request, sem merge automático.

## Arquitetura recomendada
Preferir reuso da organização existente. Componentes possíveis:
- `HarvestController.gd` conectado ao fazendeiro, com `Area3D` de proximidade e consulta à grade.
- `TomatoPickupFX.tscn` + script que anima 3–5 sprites por planta, sem confundir quantidade visual com rendimento real.
- `HarvestInventory.gd` (ou inventário existente) com `max_crates=7`, `tomatoes_per_crate=8` (teste), sem usar constantes espalhadas.
- `BackpackCrates.tscn` com `BackpackStackRoot` e sprites individuais de caixa.
- `HarvestIntakeMarker` ancorado ao personagem, atualizado durante a caminhada.
- Sinais `harvest_started`, `harvest_unit_confirmed`, `crate_filled`, `backpack_full`, `harvest_finished`.

## Fluxo de coleta obrigatório
1. Detectar candidato por proximidade e posição de célula válida, independente do início da plantação na frente ou no fundo.
2. Verificar maturidade e disponibilidade real do fruto.
3. Reservar `min(quantidade disponível, capacidade livre)` de forma atômica e marcar que há coleta em andamento para não repetir a operação.
4. Animar 3–5 tomates visuais por planta em trajetórias ligeiramente diferentes, com 0,35–0,60s de duração e curva suave. Atualizar o destino até o marcador móvel da mochila a cada frame.
5. Ao terminar cada lote, confirmar somente as unidades reservadas; em cancelamento, devolver capacidade reservada e manter a planta com frutas disponíveis.
6. Atualizar a pilha incrementalmente: `ceil(total / tomates_per_crate)`, limitada a sete. Caixa incompleta usa `crate_empty.png` com preenchimento visual progressivo; caixa completa usa `crate_full.png`.
7. Se todas as unidades da planta tiverem sido colhidas, passar a `HARVESTED`; se houver sobras devido à lotação, manter a planta coletável (`RIPE`).
8. Com sete caixas completas, bloquear novas reservas e indicar que o descarregamento será necessário. Não descartar produção excedente.

## Parâmetros iniciais para teste
- `harvest_radius`: 1,25 × a distância real entre centros de células.
- `harvest_interval`: 0,12 s.
- `yield_per_crop`: 6 tomates ilustrativos, configuráveis.
- `tomatoes_per_crate`: 8; `max_crates`: 7 → total 56 no teste.
- `pickup_duration`: 0,35–0,60 s; `arc_height`: 0,3–0,6 × largura da célula.
- `max_visual_tomatoes_per_crop`: 5; efeitos suaves para manter boa legibilidade.
Ajustar visualmente na câmera real sem criar patches baseados em coordenadas fixas de tela.

## Condições de bloqueio/aceite
- Não declarar concluído sem executar a cena e documentar evidências.
- Capturas reais: antes da primeira coleta; fruto voando da frente do campo; fruto voando do fundo do campo; mochila com 1, 4 e 7 caixas; capacidade cheia, com tomates ainda nas plantas.
- Testes: coleta ao caminhar, giro brusco, aproximação por todos os lados, múltiplas plantas maduras, concorrência de efeitos, cancelamento de transições, capacidade parcial/total, cenário de reload.
- Zero duplicações, zero frutas perdidas por mochila cheia, zero plantas fora da grade, zero alterações no terreno, zero regressões em câmera/joystick.
- Preparar branch, Pull Request, relatório de QA e lista de arquivos alterados. Na ausência de ambiente gráfico ou suporte a execução, informar a limitação explicitamente; não simular evidência de testes.

Referência detalhada: `docs/DEFINICAO_COLHEITA.md`. O resultado esperado é colheita automática contínua, intuitiva e visualmente agradável, com caixas se acumulando de modo progressivo até sete.
