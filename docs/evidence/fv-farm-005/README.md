# FV-FARM-005 — novo solo, punhado de sementes e tomates maiores

Godot 4.7.2, renderizador Mobile, câmera da cena `farm_world.tscn`, 1280×720.

## Requisitos

1. Substituir o solo pela nova arte laranja com 3 sulcos (`plowed_soil_three_furrows.png`, 466×912, enviada pelo Celso).
2. Semeadura mais fluida: um punhado com sementes de vários tamanhos lançado de uma vez.
3. Tomates maiores em todos os estágios do ciclo.
4. Refatorar e validar com evidência.

## Mudanças

- **Solo**: textura nova; 3 tiras (antes 4) × 3 sulcos × 7 fileiras = 63 células.
  - A câmera olha o chão a 45°, o que encurtava as tiras na tela para ~70% do comprimento da arte (aspecto "comprimido").
    O comprimento agora é compensado por 1/sin(45°) ≈ 1,41: cada tira tem 10,5 m (antes 7,4 m) e aparece na tela na proporção da arte (~2:1).
  - A borda próxima da casa fica fixa em z = 3,3; o canteiro cresce para longe do fazendeiro.
- **Semeadura** (`scenes/vfx/SeedThrow.tscn`, `scripts/vfx/seed_throw.gd`):
  - Faixa de semeadura: a cada passo o fazendeiro semeia, no sulco em que anda, da cova do pé até 3 plantas à frente (até 4 covas por passo, ~5,3 m). Substitui o arremesso fixo de 5,1 m (`PlantingGrid.seed_plants_ahead`, `seeds_per_step`).
  - 25 grãos por punhado em duas camadas: 7 no tamanho original (0,65×–1,45×) e 18 finos (0,12×–0,55×), mais abertos (30°) para pulverizar no ar. Faixa total de 12×.
  - Quatro formatos sorteados do atlas 2×2, giro aleatório, curva de escala e fade.
  - `billboard_keep_scale = true`: sem isso o Godot descartava a escala individual e todos os grãos saíam do mesmo tamanho.
  - Ao pousar, 11 grãos ficam deitados no sulco (raio 1,05 m, muitos pequenos e poucos grandes) e somem em ~1 s.
  - Sinal `landed`: o broto nasce quando o punhado toca o sulco.
  - Aquecimento das partículas ao carregar a cena, para o primeiro arremesso não engasgar. `fixed_fps` removido.
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
SOIL_OK texture=(466.0, 912.0) quad=(3.997291, 10.51738)
GRID_OK cells=63 unique=63 front=PlantingPlot_01_r06_c00 back=PlantingPlot_01_r00_c00
CROP_SIZES_OK SPROUT=1.18x0.80(+109%) GROWING=1.05x1.30(+34%) FLOWERING=1.28x1.40(+90%) GREEN_FRUIT=1.14x1.55(+60%) READY_TO_HARVEST=1.46x1.62(+59%)
SEED_BAND_OK rows=[1, 2, 3, 4] ahead=3 band=5.26m
SEED_THROW_OK amount=25 ground_grains=11 scale=0.12-1.45 landing_error=0.0000003
FARM_SMOKE_OK   (código de saída 0; qualquer falha sai com 1)
```

Capturas (`Godot_v4.7.2-stable_win64_console.exe --path . -s tools/farm_capture.gd`):

- `01-soil-empty.png`: solo novo vazio (câmera do jogo).
- `01b-soil-overview.png` / `02b-growth-stages-overview.png`: zoom aberto mostrando as 3 tiras inteiras.
- `02-growth-stages.png`: um estágio por canteiro (broto, crescimento, floração, fruto verde) e maduros na frente.
- `03-ready-full-field.png`: 63 tomateiros maduros.
- `04/05/06/07-seed-*.png`: o mesmo punhado em 0,15 s, 0,42 s, 0,78 s e 1,0 s (grãos no solo).
- `08-seed-sizes-closeup.png` / `09-seed-ground-closeup.png`: câmera aproximada mostrando a variação de tamanho no ar e no sulco.

## Riscos e pendências

- Não foi testado em aparelho Android; desempenho com 63 plantas e vários punhados simultâneos precisa de medição no dispositivo.
- O halo do `04_green_fruit.png` foi escondido no render, não corrigido no arquivo. Uma versão limpa do PNG é recomendada.
- A câmera inicial corta a parte da frente do campo (comportamento anterior, fora do escopo).
- O plugin `addons/meshy-godot-plugin` está habilitado no `project.godot` mas não versionado; não foi incluído neste commit.
