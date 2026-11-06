# FV-FARM-006 — ciclo de tomate e depósito

Validação local em 6 de novembro de 2026, Godot 4.7.2 Standard, renderizador Mobile. Os quatro PNGs do pacote `TerraBelaFarm_Tomate_4_Estagios_Rasteiro_v2 (1).zip` substituem os cinco estágios visuais anteriores sem alteração das imagens fonte. A grade atual contém três tiras contíguas, três sulcos por tira e sete posições por sulco: 63 células com centros distintos e distância mínima medida de 0,917 unidade do mundo.

## Regras implementadas

- A célula semeada apresenta o broto, a floração, dois frutos verdes e três frutos vermelhos maduros, nessa ordem.
- Ao confirmar todos os frutos da célula, a planta desaparece. Em colheita parcial, os frutos restantes continuam disponíveis.
- Uma célula colhida continua indisponível para semear até todas as 63 células estarem `HARVESTED` e sem frutos; então a grade retorna a `EMPTY`.
- As imagens das caixas da mochila têm o dobro da largura anterior (2,0 unidades); a pilha usa duas colunas e distância vertical de 1,2 unidade entre fileiras para manter as sete caixas dentro da câmera. A capacidade lógica continua em 56 tomates.
- O fazendeiro descarrega por proximidade no depósito no pé do mapa (+Z). O total é apresentado em caixas e tomates 3D, deixando a mochila livre para nova colheita. O total persiste durante a sessão, mas ainda não está conectado ao save.

## Evidência de execução

Comandos executados no diretório do projeto com `godot` apontando para a instalação local de Godot 4.7.2:

```powershell
godot --headless --path . --import
godot --headless --path . --script res://tools/farm_smoke.gd
godot --headless --path . --script res://tools/harvest_smoke.gd
godot --headless --path . --script res://tools/depot_smoke.gd
```

O teste de fazenda terminou em `FARM_SMOKE_OK`: textura de solo 466×912, 63 células únicas, quatro estágios dimensionados, 25 partículas por rajada e sementes menores misturadas às maiores. O teste de colheita terminou em `HARVEST_SMOKE_OK`: alinhamento medido 0,917, coleta nas posições frontal, central e traseira, bloqueio de replantio, dez plantas durante o deslocamento, conservação de frutos, capacidade da mochila, cancelamento e restauração de estado. O teste de depósito terminou em `DEPOT_SMOKE_OK stored=16 crates=2 backpack=0`; a repetição sem carga não duplica tomates.

Capturas realizadas com a câmera real da cena e o renderizador Mobile:

- [Broto em 21 células](fv-farm-006/01-sprout.png)
- [Tomate maduro em 21 células](fv-farm-006/02-ripe.png)
- [Quatro caixas no depósito 3D](fv-farm-006/03-depot-4-crates.png)
- [Sete caixas ampliadas na mochila, todas visíveis](fv-farm-006/04-backpack-7-crates.png)

Os quatro PNGs do ZIP foram comparados por SHA-256 com os arquivos instalados; todos coincidem. A imagem do solo instalada também coincide por SHA-256 com o anexo local.

Os testes são locais no PC. O vertical slice completo, a persistência do depósito e a execução em Android real ainda exigem validação própria.
