# Progressão 6x mais lenta e novo ícone da loja

Validação local em 6 de novembro de 2026, Godot 4.7.2 Standard, renderizador Mobile.

## 1. Nível e missões 6x mais lentos

Todos os números de ritmo ficam em `scripts/progression/progression_config.gd` (`ProgressionConfig`). `DIFFICULTY_MULTIPLIER = 6` multiplica o XP pedido por nível e as metas das missões. Prêmios e XP ganhos continuam iguais, então avançar exige 6x mais jogo. Plantio, colheita, vendas, preços e o dinheiro das vendas não mudaram.

| Item | Antes | Agora |
|---|---|---|
| XP para sair do nível 1 | 40 | 240 |
| XP para sair do nível 2 | 60 | 360 |
| XP para sair do nível N | 40 + 20·(N−1) | (40 + 20·(N−1)) × 6 |
| Missão "Colher tomates" | 56 (1 mochila) | 336 (6 mochilas) |
| Missão "Vender caixas" | 7 | 42 |
| Missão "Recolher dinheiro" | 30 | 180 |
| Rodadas seguintes | meta × (rodada + 1) | igual, sobre a meta já multiplicada |

Para ajustar no futuro basta mudar `DIFFICULTY_MULTIPLIER` (ou os valores base) nesse arquivo.

## 2. Novo ícone da loja

- Asset: `assets/ui/icons/icon_store_shop.png` (o PNG enviado, 1536x1024, fundo transparente, sem edição). O ícone antigo com tomates (`icon_store.png`) foi removido do projeto e não há mais referência a ele.
- O botão mantém posição (canto inferior direito), tamanho funcional (282x245 no espaço de desenho, 118x103 px na tela 1280x720) e interação ("Loja em breve!").
- O PNG tem margem transparente larga dos lados. O botão exibe a região `Rect2(180, 0, 1172, 1024)` por `AtlasTexture`, e fora dela só há pixels transparentes (o teste confere).
- O nome é um `Label` sobre a faixa laranja, com a chave `STORE_LABEL` traduzida pelo sistema de localização da Godot: `localization/ui.csv` gera `ui.pt_BR.translation`, `ui.es.translation` e `ui.en.translation`, registrados em `project.godot` (fallback `pt_BR`). A fonte se ajusta à largura da faixa em cada idioma.

## Testes

Todos com código 0: `hud_smoke` (agora confere os valores 6x: meta 336 só concluída na 6ª mochila, 0/42 caixas, 240 e 360 XP, nível só sobe com 240; ícone novo, ausência do antigo, tamanho 282x245 e rótulo Loja/Tienda/Shop dentro da faixa), `farm_smoke`, `harvest_smoke`, `customer_smoke`, `sales_counter_smoke`, `angle_audit` e `ui_asset_audit`.

## Capturas (cena real, `ui-loja/`)

- Paisagem 1280x720: [pt_BR](ui-loja/loja-paisagem-pt_BR.png), [es](ui-loja/loja-paisagem-es.png), [en](ui-loja/loja-paisagem-en.png), [clique](ui-loja/loja-paisagem-clique.png); recortes ampliados [pt_BR](ui-loja/loja-paisagem-pt_BR-zoom.png), [es](ui-loja/loja-paisagem-es-zoom.png), [en](ui-loja/loja-paisagem-en-zoom.png)
- Retrato 720x1280: [pt_BR](ui-loja/loja-retrato-pt_BR.png), [es](ui-loja/loja-retrato-es.png), [en](ui-loja/loja-retrato-en.png), [clique](ui-loja/loja-retrato-clique.png)

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s tools/hud_capture.gd -- <pasta> store
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 720x1280 -s tools/hud_capture.gd -- <pasta> store
```
