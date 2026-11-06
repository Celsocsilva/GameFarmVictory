# FV-SALES-004 — novo maço de dinheiro nas pilhas e base ajustada

Validação local em 6 de novembro de 2026, Godot 4.7.2 Standard. Parte de `claude/project-thread-0tl0l6-difficulty-store`.

- **Sprite**: `assets/sales/money_bundle.png` trocado pelo maço horizontal enviado pelo Celso ("Ícone de maço de dinheiro verde com cifrão.png", 1774 × 887). O PNG original já tinha fundo transparente; foi recortado à área opaca (alfa ≥ 0,5) e reduzido para 512 × 263. Mesmo estilo do ícone oficial do HUD (`assets/currency/cash_bundle_official.png`), que não foi alterado.
- **Base e espaçamento**: `MoneyStack.ART_ASPECT` 276/512 → 263/512. Cada posição continua com o tamanho exato do maço no chão (1,258 × 0,914 m, vão 0), e o bloco de madeira encolheu junto: 3,97 × 4,77 m (antes 3,97 × 5,00 m), com a mesma borda de 10 cm e os cantos arredondados.
- **Altura das camadas**: 0,10 → 0,136 m, igual à espessura lateral desenhada no novo maço (~17% da altura), para a pilha parecer contínua.

## Testes

```
sales_counter_smoke -> MONEY_COMPACT cell=(1.258, 0.913864) gap=0.000 base=3.97x4.77 ... SALES_SMOKE_OK
angle_audit         -> Maço na base de dinheiro art_h/w=0.514 screen_h/w=0.514 diff=+0.0% ... ANGLE_AUDIT_OK elements=12
hud_smoke, customer_smoke, farm_smoke, harvest_smoke -> OK
```

## Capturas

- [Pilhas na base 3 × 5](04-dinheiro-na-base-3x5.png)
- [Pilhas recolhidas e saldo no HUD](07-pilhas-recolhidas-saldo-no-hud.png)
- [Prancha arte × jogo](09-auditoria-angulos-lado-a-lado.png)
- Demais capturas do balcão e da coleta nesta pasta.