# Assets do ciclo do tomate

Conjunto rasteiro v2: quatro PNGs RGBA transparentes de 1254×1254 pixels, mantidos sem recorte ou alteração. A semente continua em `res://assets/seeds/tomato_seed.png` e não é um estágio visual de `CropPlant`.

| Estágio | Asset | Conteúdo |
| --- | --- | --- |
| `SPROUT` | `stages/tomato_stage_01_sprout.png` | Broto inicial |
| `FLOWERING` | `stages/tomato_stage_02_flowering.png` | Planta rasteira com flores |
| `GREEN_FRUIT` | `stages/tomato_stage_03_green_2_fruits.png` | Dois tomates verdes |
| `READY_TO_HARVEST` | `stages/tomato_stage_04_ripe_3_fruits.png` | Três tomates vermelhos maduros |

`tomato_growth_cycle.json` registra a ordem e os caminhos Godot. `CropPlant` exibe os quatro estágios em intervalos iguais da duração de crescimento e emite `ready_for_harvest` ao entrar no último. Após a colheita total, a planta é removida da célula; o terreno fica vazio visualmente até a próxima safra.

Os sprites são recortados somente em tempo de execução pelo alfa visível, dimensionados pela largura da célula e pela altura de cada estágio, e ancorados pela base no sulco. Os arquivos PNG originais permanecem intactos. Ajustes de tempo, plantio e colheita pertencem aos sistemas de gameplay.
