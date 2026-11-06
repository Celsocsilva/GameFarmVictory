# FV-HARVEST-001 — colheita automática de tomates com sucção e mochila de 7 caixas

Godot 4.7.2 (Vulkan, renderizador Mobile), cena `farm_world.tscn`, câmera real do jogo, 1280×720.
Definição: [`docs/DEFINICAO_COLHEITA.md`](../../DEFINICAO_COLHEITA.md). Assets originais e prompt: `docs/references/fv-harvest-001/`.

Base: branch `claude/project-thread-rcc619` (PR #5, que já inclui o PR #4). Este trabalho não altera solo, câmera, joystick, movimento, grade ou semeadura.

## Como funciona

1. `CropPlant` emite `ready_for_harvest` no estágio final → `PlantingGrid.mark_ripe(cell, 6)` (célula `RIPE`, 6 frutos).
2. `HarvestController` (nó do `FarmWorld`) procura a cada quadro células `RIPE` no raio `1,25 × menor distância entre centros` (≈ 1,59 m), ordenadas por distância e id (determinístico), com intervalo mínimo de 0,12 s entre reservas.
3. Reserva atômica `min(frutos disponíveis, espaço livre)` em `HarvestInventory` **antes** de criar qualquer sprite; a célula passa a `HARVESTING` (sem segunda coleta simultânea).
4. `TomatoPickupFX` solta 3–5 tomates visuais da copa (`CropPlant.HarvestOriginMarker`/`get_harvest_origins`), cada um com duração 0,35–0,60 s, arco de 0,45 × largura da célula e trajetória lateral própria. O destino `HarvestIntakeMarker` é lido **a cada quadro**, então os frutos seguem o fazendeiro andando e virando. Rastro (`harvest_suction_trail.png`) discreto alinhado ao voo na tela e brilho (`harvest_pickup_spark.png`) uma vez por planta.
5. Cada fruto que chega confirma sua parte das unidades (ex.: 6 unidades em 4 frutos → 2, 2, 1, 1) e retira a mesma quantidade da planta (`PlantingGrid.consume_yield`). Planta + mochila sempre somam a produção original.
6. Sem frutos → `HARVESTED` (o pé volta ao visual de broto, sem tomates; replantio é de outro sistema). Com sobras (mochila lotou ou cancelamento) → volta a `RIPE`.
7. `BackpackCrates` (filho do fazendeiro, nas costas) monta a pilha repetindo `crate_empty.png`/`crate_full.png`: `ceil(total/8)` caixas, máximo 7. A caixa parcial mostra 1–7 mini tomates. A imagem de 7 caixas é só referência e não é usada no jogo.
8. Em 56 unidades: nenhuma nova reserva, frutos ficam nas plantas, HUD mostra “Mochila cheia (56/56)! Leve as caixas até a bancada para descarregar.” `HarvestInventory.remove()` já existe para a futura bancada.

Cancelamento: afastar-se mais de 7 m da planta em coleta, perder o marcador ou trocar de cena (`_exit_tree`) devolve a reserva pendente e mantém os frutos na planta. Save: `HarvestInventory.to_dict()` + `PlantingGrid.get_harvest_state()` (célula em voo é salva como `RIPE`).

## Parâmetros (exportados, sem constantes espalhadas)

| Campo | Valor | Onde |
| --- | --- | --- |
| `radius_multiplier` | 1,25 × espaçamento (≈ 1,59 m) | `HarvestController` |
| `harvest_interval` | 0,12 s | `HarvestController` |
| `flight_duration_min/max` | 0,35–0,60 s | `HarvestController` → `TomatoPickupFX` |
| `arc_height_factor` | 0,45 × largura da célula | `HarvestController` |
| `min/max_visual_tomatoes` | 3–5 | `HarvestController` |
| `yield_per_crop` | 6 | `HarvestController` |
| `units_per_crate` / `max_crates` | 8 / 7 → 56 | `HarvestInventory` (repassado a `BackpackCrates`) |
| `crate_width` / `crate_step` | 1,0 m / 0,5 m | `BackpackCrates` |

## Testes automáticos

`Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/harvest_smoke.gd` → `HARVEST_SMOKE_OK` (sai com 1 em falha).

| Teste | Resultado |
| --- | --- |
| Inventário 0/1/8/9/55/56 → caixas 0/1/1/2/7/7, cheias 0/0/1/1/6/7; reserva limitada; commit/cancel sem duplicar; save/load | OK |
| Mochila visual 0/1/8/9/55/56 (caixas visíveis, `crate_full`, mini tomates 0/1/0/1/7/0); caixas sem colisão; pilha fora do corpo | OK |
| Planta do fundo, meio e frente; 3–5 frutos nascendo na célula e acima do solo; fazendeiro andando + giro brusco no voo; erro de chegada ao marcador móvel 0,000 m; nenhum fruto abaixo do terreno; planta não sai da célula | OK |
| Caminhada contínua a 4 m/s com zigue-zague: 10 plantas em sequência, 7 efeitos simultâneos, nenhuma duplicação, conservação checada a cada quadro, fim com 56/56 | OK |
| Mochila em 55 + planta de 6: entra 1, planta fica `RIPE` com 5, `backpack_full` uma vez, novas reservas bloqueadas, HUD orienta; após descarregar, colheita volta | OK |
| Sair do campo no meio do voo: reserva revertida, planta mantém os 4 frutos não confirmados, frutos cancelados não chegam depois, recoleta fecha em 6 | OK |
| Troca de cena com voo pendente: reservas revertidas, célula volta a `RIPE`, nada confirmado | OK |
| Reload no meio do voo: inventário e frutos restantes restaurados, 378 unidades conservadas | OK |
| Aproximação por norte, sul, leste e oeste passando direto pela planta | OK |

Regressão: `tools/farm_smoke.gd` → `FARM_SMOKE_OK` (solo, grade, arremesso, tamanhos dos tomates, punhado de sementes inalterados).

## Capturas (janela real, `tools/harvest_capture.gd`)

O fazendeiro anda com `Input.action_press` (mesmo caminho do teclado/joystick). Comando:
`Godot_v4.7.2-stable_win64_console.exe --path . -s tools/harvest_capture.gd -- <saida> --frames`

| Arquivo | O que mostra |
| --- | --- |
| `01-before-first-harvest.png` | Campo maduro antes da primeira coleta |
| `02-flight-back-of-field.png` | Frutos voando da fileira do fundo |
| `03-flight-middle-of-field.png` | Frutos voando no meio do campo, rastro e pilha crescendo |
| `08-flight-front-of-field.png` | Frutos voando da fileira da frente |
| `04/05/06-backpack-*.png` | Mochila com 1, 4 e 7 caixas durante a caminhada |
| `07-backpack-full-fruit-left-on-plants.png` | 56/56, aviso de bancada, tomates ainda nas plantas |
| `backpack-00/01/08/09/55/56-units.png` | Estados exigidos da mochila (close na câmera do jogo) |
| `backpack-30-units-side.png` | Fazendeiro de lado: pilha nas costas sem atravessar o corpo |
| `harvest-walk.mp4` | ~14 s da caminhada real colhendo do fundo para a frente até lotar (≈ 20 fps de gravação) |

## Limitações conhecidas

- O pé colhido usa o PNG de broto (`01_sprout`) porque o estágio 02 tem tomates verdes; uma arte de “pé colhido” deixaria isso mais claro.
- Quando o fazendeiro anda em direção à câmera, a parte de baixo da pilha fica atrás do corpo (ordem 3D correta); as caixas de cima continuam visíveis.
- Teste em aparelho Android ainda não feito nesta etapa (só desktop Vulkan Mobile).
