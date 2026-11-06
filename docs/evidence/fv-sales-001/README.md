# FV-SALES-001 — Balcão de vendas e base de dinheiro 3 × 5

Validação local em 6 de novembro de 2026, Godot 4.7.2 Standard, renderizador Mobile.
Empilhado sobre FV-CUSTOMERS-001 (PR #7), que por sua vez está sobre #4, #5 e #6.

## O que mudou

- **Balcão de vendas**: a antiga bancada de descarga/depósito (`TomatoDepot`) passou a se chamar Balcão de vendas (`SalesCounter`, `scripts/farming/sales_counter.gd`; nó `SalesCounter`; HUD "Leve as caixas ao Balcão de vendas"). O projeto não tem arquivos de tradução (EN/ES); só os textos em português foram atualizados.
- **Largura dobrada**: 4,25 m → 8,5 m (3 → 6 colunas de caixas, 2 fileiras, até 4 camadas = 48 caixas visíveis). O estoque não tem limite: toda a produção pode ser descarregada; acima de 48 caixas só a contagem cresce.
- **Descarga**: encostar em qualquer ponto do balcão (até 1,3 m da borda) descarrega a mochila inteira.
- **Fazendeiro não ultrapassa o balcão**: o balcão é sólido (StaticBody3D) e cercas baixas de madeira ligam as pontas do balcão às laterais do terreno. O fazendeiro fica sempre do lado da plantação; o lado da fila de clientes fica só para os clientes (que não têm física).
- **Base de dinheiro 3 × 5** (`scripts/economy/money_stack.gd`): ao lado do balcão, no lado do fazendeiro. 3 fileiras × 5 linhas = 15 posições. Cada maço (sprite enviado, recortado em `assets/sales/money_bundle.png`) vale 1 dinheiro; os maços preenchem as 15 posições e depois sobem em camadas (até 12 camadas = 180 maços visíveis). O saldo aparece no HUD ("Dinheiro: $ N").
- **Vendas** (`scripts/commerce/sales_controller.gd`): o primeiro cliente de cada fila, já parado no lugar, é atendido se houver tomates no balcão. Após 1,2 s ele compra de 1 a 3 caixas (sorteado, limitado ao estoque), paga **3 por caixa** (proporcional, arredondado para cima, numa última caixa incompleta), sai levando as caixas nas mãos e a fila anda. Em atendimento o cliente não desiste. Sem estoque, a paciência de 15–20 s da fila continua valendo (sai e volta depois).
- Câmera, joystick e terreno não foram alterados.

## Teste automático

```powershell
godot --headless --path . -s tools/sales_counter_smoke.gd
```

Saída:

```
COUNTER width=8.50 depth=2.25 z=20.50
DEPOSIT stored=224 crates=28
BLOCKED x=0.0 farmer_z=18.86 counter_front=19.38
BLOCKED x=3.5 farmer_z=18.86 counter_front=19.38
BLOCKED x=-6.3 farmer_z=19.90 counter_front=19.38
BLOCKED x=12.0 farmer_z=19.90 counter_front=19.38
BLOCKED x=-25.0 farmer_z=19.90 counter_front=19.38
SALES count=4 crates=[3, 2, 2, 3] money=30 time=50.5s
SALES_SMOKE_OK width=8.50 blocked=5 base=3x5 sales=5 money=33
```

O teste confere: nome e largura, descarga só encostado, 4 mochilas inteiras no balcão, o fazendeiro andando de verdade (`move_and_slide`, 150 quadros de física) contra o balcão e as cercas em 5 pontos sem passar, a base 3 × 5 no lado do fazendeiro, empilhamento em camadas, HUD, preços (8 → 3, 16 → 6, 24 → 9, 4 → 2), 10 caixas vendidas em compras sorteadas de 1–3 com o dinheiro certo na base, nenhuma venda sem estoque, clientes desistindo sem estoque e venda de novo após reabastecer. `farm_smoke`, `harvest_smoke` e `customer_smoke` continuam passando.

## Capturas

`godot --path . -s tools/sales_capture.gd -- <pasta>` (sem `--headless`):

- [Fazendeiro chegando com a mochila cheia](01-chegando-com-mochila-cheia.png)
- [Produção inteira (28 caixas) empilhada no balcão](02-producao-empilhada-no-balcao.png)
- [Cliente saindo com as caixas compradas](03-cliente-saindo-com-caixas.png)
- [$ 60 empilhados na base 3 × 5](04-dinheiro-na-base-3x5.png)
- [Visão ampliada: canteiro, balcão largo, cercas, fila e base de dinheiro](05-visao-geral-balcao-de-vendas.png)

## FV-SALES-001.1 — novo maço e base de madeira

- Sprite trocado pelo maço visto de frente enviado por Celso (`Gemini_Generated_Image_36npqq36npqq36np.jpg`). O fundo xadrez do JPG foi removido por preenchimento a partir das bordas (só pixels neutros e claros), preservando a faixa branca; resultado em `assets/sales/money_bundle.png` (512 × 276, PNG com transparência).
- Embaixo da pilha: bloco fino (8 cm) de madeira clara com cantos arredondados (raio 20 cm), com tampo um tom mais claro que a borda. Substitui a moldura escura e o feltro verde com as 15 casas.
- Camada de maços: 6 cm (espessura do maço na nova arte). `sales_counter_smoke` confere a base (8 cantos arredondados, altura ≤ 10 cm, cobre as 15 posições, cor de madeira clara) e a transparência do sprite.

O fazendeiro ainda não recolhe o dinheiro da base; o saldo já fica disponível em `MoneyStack.spend()` para a próxima etapa.

## FV-SALES-002 — base compacta, coleta do dinheiro e caixas pulando para o balcão

- **Base compacta**: cada posição da grade 3 × 5 tem exatamente o tamanho do maço no chão (1,26 × 0,96 m), sem vão entre pilhas; o bloco de madeira tem só 10 cm de borda (3,97 × 5,00 m).
- **Coleta**: ao tocar uma pilha (corpo do fazendeiro sobre ela, folga de 0,45 m), a pilha esvazia e o valor entra na carteira (`scripts/economy/wallet.gd`), que é o saldo mostrado no HUD ("Dinheiro: $ N"). Alguns maços sobem até o fazendeiro como efeito. A carteira tem `can_afford()`/`spend()` para as compras futuras (ferramentas, recursos, aceleração) e `set_balance()` para save. Novas vendas enchem primeiro as pilhas vazias.
- **Caixas do balcão**: mesma arte das caixas da mochila (`crate_full.png`; a última caixa incompleta usa `crate_empty.png`), viradas para a câmera como na mochila. Cada coluna tem 2 caixas, uma na frente da outra (fileiras a 1,0 m, dentro do tampo de 2,25 m), e as camadas sobem apoiadas na borda da caixa de baixo. O rebordo do lado dos clientes baixou para 35 cm para não esconder as caixas.
- **Descarga animada**: cada caixa nova pula das mãos do fazendeiro em arco (0,42 s, 1,6 m de altura, uma a cada 0,09 s), cresce até o tamanho da pilha e só aparece no balcão ao pousar, com um leve achatamento.

Saída do teste (`sales_counter_smoke`):

```
COUNTER_CRATES art=crate_full rows=2 back_z=21.00 front_z=22.00 depth=2.25
CRATE_JUMP crates=4 from_hands=(1.0, 1.1, 19.225) peak=2.26 above_ends=1.16 land_time=0.55s staggered=[1, 2, 3, 4]
MONEY_COMPACT cell=(1.258, 0.959036) gap=0.000 base=3.97x5.00 margin=0.10
MONEY_COLLECT slot7=2 all=30 wallet_after_spend=20 hud=Dinheiro: $ 20
SALES_SMOKE_OK width=8.50 blocked=5 base=3x5 sales=5 money=33
```

Capturas novas: [caixas pulando das mãos](01b-caixas-pulando-das-maos.png), [caixas pousadas](01c-caixas-pousadas-no-balcao.png), [fazendeiro recolhendo](06-fazendeiro-recolhendo-dinheiro.png), [pilhas recolhidas e saldo no HUD](07-pilhas-recolhidas-saldo-no-hud.png).