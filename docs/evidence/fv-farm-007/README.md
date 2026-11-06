# FV-FARM-007 — ciclo 2x mais longo, área de plantio e dinheiro 1,7x

Godot 4.7.2, renderizador Mobile. Empilhado sobre FV-FARM-005.2 (PR #11).

## Pedido

"Todo o ciclo de desenvolvimento da planta deve ter o dobro do tempo atual. Aumente vezes 1.7 a área e os dinheiros."

Leitura adotada: área de plantio 1,7x (mantendo a proporção das tiras) e maços + base de dinheiro 1,7x. Valor das vendas não mudou.

## Mudanças

- **Ciclo**: `CropPlant.growth_duration` 30 s → 60 s; as 4 fases (broto, floração, fruto verde, pronto) ficam com o dobro do tempo cada.
- **Área**: 3 tiras com largura e comprimento × sqrt(1,7) ≈ 1,30 (5,0 × 13,7 m por tira; área 1,7x). Continua com 3 sulcos por tira; 9 fileiras (antes 7) mantêm ~1,5 m entre covas → 81 covas (antes 63).
- **Layout**: para caber a área maior, o início do canteiro foi de z = 3,3 para 2,3 e o balcão recuou 1 m (`foot_inset` 11,5 → 10,5), mantendo ≥ 4 m entre canteiro e balcão. A base de dinheiro agora é posicionada fora da largura da plantação.
- **Dinheiro**: `MoneyStack.MONEY_SCALE = 1.7` em posições, maços, camada, cantos e margem. A espessura da base de madeira continua fina.

## Validação

```
farm_smoke:          AREA_CYCLE_MONEY_OK area_ratio=1.7 cycle=60s · GRID_OK cells=81 · SEED_BAND_OK · FARM_SMOKE_OK
harvest_smoke:       HARVEST_SMOKE_OK
customer_smoke:      CUSTOMER_SMOKE_OK lanes=2x7
sales_counter_smoke: SALES_SMOKE_OK width=8.50 blocked=5 base=3x5
```

Capturas: `01..05` nesta pasta (balcão, clientes e dinheiro 1,7x) e `docs/evidence/fv-farm-005/01b`, `02b` (área 1,7x).

## Riscos

- Com 81 plantas e ciclo de 60 s, medir desempenho no Android.
- Área e espaço da fila de clientes ficaram 1 m mais curtos atrás do balcão (fila 2x7 ainda passa no teste).
