# FV-SALES-003 — Balcão 1,3x e auditoria de ângulos

Validação local em 6 de novembro de 2026, Godot 4.7.2 Standard, renderizador Mobile. Empilhado sobre FV-SALES-002 (PR #13).

## Balcão e caixas 1,3x

- `SalesCounter.COUNTER_SCALE = 1.3`: tampo 8,5 × 2,25 m → 11,05 × 2,925 m; caixas 1,3 m → 1,69 m de largura; espaçamento, altura do pulo e rebordo também × 1,3. Continuam 6 colunas × 2 fileiras (uma na frente da outra, a 1,3 m) × 4 camadas.
- Passagem entre o fim do canteiro (z = 16,01) e a frente do balcão (z = 20,04): 4,03 m. O fazendeiro segue bloqueado no balcão e nas cercas (5 pontos testados).
- A fila de clientes começa logo atrás do rebordo do balcão, qualquer que seja o fundo dele (`first_slot_offset` = meia profundidade + 0,85 m). Último lugar e surgimento continuam dentro da cerca.

## Auditoria de ângulos (time: arte técnica, gameplay e QA)

`tools/angle_audit.gd` usa a câmera real do jogo (ortográfica, 45°, sem giro, a mesma altura/distância/`look_at` do `FarmWorld`) e projeta na tela os cantos de cada elemento:

| Elemento | Como é desenhado | Proporção arte | Na tela | Resultado |
|---|---|---|---|---|
| Terreno de cultivo (solo) | quadro deitado, esticado 1/sin 45° | 1,957 | 1,860 → **1,957** | **corrigido** (estava 4,9% achatado) |
| Maço na base de dinheiro | quadro deitado, esticado 1/sin 45° | 0,539 | 0,539 | OK |
| Caixa no Balcão de vendas | quadro de pé virado para a câmera, altura × 1/cos 45° | 0,798 | 0,798 | OK |
| Caixa na mochila | igual ao balcão | 0,798 | 0,798 | OK |
| Planta de tomate | billboard completo | 0,766 | 0,766 | OK |

Também confere: fazendeiro e cliente em pé (inclinação 0°; o fazendeiro só gira em Y para andar), balcão, base de dinheiro e canteiro sem giro (0°), e bordas do balcão e da base horizontais na tela (0°).

**Defeito encontrado e corrigido**: o quad do solo era alargado para compensar a margem transparente do PNG (466 px, área opaca menor), mas o comprimento não acompanhava. Na tela a tira ficava 4,9% mais larga que a arte. Agora o quad usa a proporção do PNG inteiro × 1/sin 45° a partir do comprimento da tira; o comprimento (área de plantio 1,7x, 81 células) não mudou e as 3 tiras continuam encostadas, sem vão. O teste `farm_smoke` tinha a mesma conta errada embutida e foi corrigido junto.

Câmera e joystick não foram alterados.

## Testes

```
--headless -s tools/angle_audit.gd        -> ANGLE_AUDIT_OK elements=12 (sai 1 se algum elemento sair do ângulo)
--headless -s tools/sales_counter_smoke.gd -> SALES_SMOKE_OK width=11.05 blocked=5 base=3x5 sales=5 money=33
--headless -s tools/customer_smoke.gd      -> CUSTOMER_SMOKE_OK (LAYOUT first_slot_z=23.81 last_slot_z=30.71 spawn_z=31.20)
--headless -s tools/farm_smoke.gd          -> FARM_SMOKE_OK (SOIL_OK, GRID_OK cells=81)
--headless -s tools/harvest_smoke.gd       -> HARVEST_SMOKE_OK
```

## Capturas

- [Prancha lado a lado DEPOIS: arte × jogo, todos OK](09-auditoria-angulos-lado-a-lado.png)
- [Prancha ANTES: solo achatado 4,9%](09a-auditoria-ANTES-solo-achatado.png)
- [Cena auditada](08-cena-auditada.png) e [antes](08a-cena-ANTES.png)
- [Visão geral com o balcão 1,3x](05-visao-geral-balcao-de-vendas.png), [produção empilhada](02-producao-empilhada-no-balcao.png), [caixas pulando](01b-caixas-pulando-das-maos.png), [base de dinheiro](04-dinheiro-na-base-3x5.png)