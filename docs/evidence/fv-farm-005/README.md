# FV-FARM-005 — novo solo, punhado de sementes e tomates maiores

Godot 4.7.2, renderizador Mobile, câmera da cena `farm_world.tscn`, 1280×720.

## Requisitos

1. Substituir o solo pela nova arte laranja com 3 sulcos (`plowed_soil_three_furrows.png`, 350×788).
2. Semeadura mais fluida: um punhado com sementes de vários tamanhos lançado de uma vez.
3. Tomates maiores em todos os estágios do ciclo.
4. Refatorar e validar com evidência.

## Mudanças

- **Solo**: textura nova, proporção 788/350 preservada no quad (sem distorção); 4 canteiros × 3 sulcos × 6 fileiras = 72 células.
- **Semeadura** (`scenes/vfx/SeedThrow.tscn`, `scripts/vfx/seed_throw.gd`):
  - 18 sementes por punhado, saindo de uma esfera de 0,14 m (a "mão"), com escalonamento de 12% do voo (`explosiveness` 0,88).
  - Tamanhos de 0,45× a 1,25× e quatro formatos sorteados do atlas 2×2 (`tomato_seed_atlas_2x2.png`).
  - Rotação inicial e giro aleatórios; curva de escala (cresce ao sair da mão, encolhe ao pousar) e fade final, sem "sumir de repente".
  - Velocidade resolvida para o centro do punhado acertar a célula (erro < 1e-7 m), ±18% de força para espalhar a queda.
  - Novo sinal `landed`: o broto nasce quando o punhado toca o sulco, não no arremesso.
  - Removido `fixed_fps = 60` das partículas: com ele o punhado ficava parado na mão nos primeiros quadros.
- **Tomates** (`scripts/farming/crop_plant.gd`):
  - Cada PNG é recortado ao conteúdo opaco (`region_rect`), e o tamanho é calculado pelo desenho real, não pelo quadro 1254×1254 com margens.
  - Altura por estágio (`stage_heights`) e largura máxima de 1,15× a célula. Ganho de altura em relação ao dimensionamento anterior: broto +109%, crescimento +34%, floração +90%, fruto verde +60%, maduro +59%.
  - Base da planta ancorada no sulco (o billboard gira em torno da base).
  - Recorte de alfa 0,5: remove o halo branco semitransparente do PNG `04_green_fruit` e dá escrita de profundidade entre plantas vizinhas.
  - "Pop" (TRANS_BACK, 0,28 s) ao brotar e a cada troca de estágio.
- **Projeto**: `docs/.gdignore` impede o Godot de importar as capturas de evidência.

## Validação

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/farm_smoke.gd
SOIL_OK texture=(350.0, 788.0) quad=(4.042553, 8.555429)
GRID_OK cells=72 unique=72 front=PlantingPlot_01_r05_c00 back=PlantingPlot_01_r00_c00
CROP_SIZES_OK SPROUT=1.18x0.80(+109%) GROWING=1.05x1.30(+34%) FLOWERING=1.28x1.40(+90%) GREEN_FRUIT=1.14x1.55(+60%) READY_TO_HARVEST=1.46x1.62(+59%)
SEED_THROW_OK amount=18 scale=0.45-1.25 landing_error=0.00000004
FARM_SMOKE_OK   (código de saída 0; qualquer falha sai com 1)
```

Capturas (`Godot_v4.7.2-stable_win64_console.exe --path . -s tools/farm_capture.gd`):

- `01-soil-empty.png`: solo novo vazio.
- `02-growth-stages.png`: um estágio por canteiro (broto, crescimento, floração, fruto verde) e maduros na frente.
- `03-ready-full-field.png`: 72 tomateiros maduros.
- `04/05/06-seed-handful-*.png`: o mesmo punhado em 0,12 s, 0,38 s e 0,66 s.

## Riscos e pendências

- Não foi testado em aparelho Android; desempenho com 72 plantas e vários punhados simultâneos precisa de medição no dispositivo.
- O halo do `04_green_fruit.png` foi escondido no render, não corrigido no arquivo. Uma versão limpa do PNG é recomendada.
- A câmera inicial corta a parte da frente do campo (comportamento anterior, fora do escopo).
- O plugin `addons/meshy-godot-plugin` está habilitado no `project.godot` mas não versionado; não foi incluído neste commit.
