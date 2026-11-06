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

O fazendeiro ainda não recolhe o dinheiro da base; o saldo já fica disponível em `MoneyStack.spend()` para a próxima etapa.