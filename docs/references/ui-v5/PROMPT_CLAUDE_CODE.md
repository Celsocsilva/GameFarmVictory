# TerraBela Farm — UI Kit v5 (Claude Code)

## Correções obrigatórias sobre o pacote v4

Este pacote **substitui integralmente a v4**. Os oito arquivos sinalizados pelo usuário foram reconstruídos a partir de seus elementos completos na prancha original; não reutilizar os PNGs v4. `pill_small_cream`, `pill_medium_cream`, `panel_tabbed_small` e `button_round_green` foram anteriormente cortados de coordenadas incorretas. `panel_reward_popup` agora é isolado sem pedaços de componentes vizinhos.

Os botões `button_cta_green_large`, `button_cta_orange_large` e `button_cta_blue_large` tiveram a **largura visível ampliada em 30%**, preservando o formato das extremidades; não esticar mais 130% dentro da engine. O redimensionamento final para diferentes telas deve ser responsivo.

### Instruções ao Claude Code

1. Identifique primeiro as cenas de HUD atuais e preserve seus dados, sinais, navegação e estados.
2. Substitua as imagens antigas pelos PNGs homônimos em `assets/ui/components/`. Não usar recortes de folhas de sprites em runtime.
3. O maço verde de dinheiro com faixa branca continua sendo o ícone oficial: `assets/currency/cash_bundle_official.png`.
4. Todos os números, valores monetários, percentuais, texto dos botões, progresso de tomate e caixas, textos de missão e mensagens de recompensa devem ser renderizados pelo Godot (`Label`, `RichTextLabel`, `TextureProgressBar` etc.). **Jamais transformar valores do jogo em pixels do asset.**
5. Para botões, use `TextureButton`/`Button` com `TextureRect` e `Label` como nós filhos quando apropriado. Para painéis redimensionáveis, evite distorção: defina margens de 9-patch adequadas ao formato ou use composição Control para manter cantos intactos.
6. A imagem `panel_reward_popup.png` é um fundo decorativo inteiro e independente. Não deve conter botões ou abas vazando da prancha.
7. Faça o teste de abertura e fechamento do popup, hover/pressed/disabled dos CTAs e atualização dinâmica dos contadores.
8. Crie cena de inspeção `UIAssetQA.tscn` exibindo **todos os oito PNGs** isolados sobre fundo contrastante, sem cortes ou sobreposição. Inclua uma segunda cena com os valores injetados via engine.
9. Valide resoluções 720×1280, 1080×1920 e desktop da demo. Documente capturas reais do jogo (não usar a prévia do pacote como prova de execução).
10. Execute testes de importação e de runtime existentes, reportando resultados com evidências e sem declarar sucesso em testes não executados.

### Observações

Os PNGs v5 possuem canal alpha e uma borda transparente de segurança. As bordas visuais não devem ser aparadas manualmente. `docs/QA_UI_v5.json` traz dimensões reais e a checagem dos arquivos.

---

# TerraBela Farm — Prompt para Claude Code (UI Refatorada v4)

Atue como uma equipe formada por UI Engineer, Technical Artist, Godot Engineer e QA Engineer.

## Objetivo
Integrar os assets de interface do TerraBela Farm ao projeto Godot usando os PNGs individuais deste pacote. Todos os valores, títulos, contagens e progressos devem ser renderizados pela engine do jogo. **Não use imagens com números embutidos.**

## Definições obrigatórias
1. O dinheiro oficial do jogo é o asset `res://assets/currency/cash_bundle_official.png`.
2. Os contadores e painéis fornecidos neste pacote são fundos visuais. Os textos e números devem ser inseridos via Label/RichTextLabel pela UI do Godot.
3. Não recorte novamente os PNGs. Eles já foram exportados individualmente e não devem perder partes visuais.
4. Preserve o estilo cozy/casual do TerraBela Farm.

## Arquivos a utilizar
### HUD
- `res://assets/ui/hud/hud_counter_money_bg.png`
- `res://assets/ui/hud/hud_counter_tomato_bg.png`
- `res://assets/ui/hud/hud_counter_crate_bg.png`
- `res://assets/ui/hud/hud_counter_water_bg.png`
- `res://assets/ui/hud/hud_counter_coin_bg.png`
- `res://assets/ui/hud/hud_top_status_bar_bg.png`
- `res://assets/ui/hud/player_level_panel_bg.png`
- `res://assets/ui/hud/mission_panel_bg.png`
- `res://assets/ui/hud/floral_info_panel_bg.png`

### Ícones
- `res://assets/ui/icons/icon_cash_bundle.png`
- `res://assets/ui/icons/icon_tomato.png`
- `res://assets/ui/icons/icon_crate_full.png`
- `res://assets/ui/icons/icon_crate_empty.png`
- `res://assets/ui/icons/icon_water_drop.png`
- `res://assets/ui/icons/icon_coin.png`
- `res://assets/ui/icons/icon_seed_bag.png`
- `res://assets/ui/icons/icon_player_portrait.png`
- `res://assets/ui/icons/icon_store.png`
- `res://assets/ui/icons/icon_gift.png`
- `res://assets/ui/icons/ui_add_button.png`
- `res://assets/ui/icons/ui_alert_button.png`
- `res://assets/ui/icons/ui_close_button.png`
- `res://assets/ui/icons/badge_discount.png`
- `res://assets/ui/icons/floral_accent_small.png`

### Componentes
- `res://assets/ui/components/button_cta_green_large.png`
- `res://assets/ui/components/button_cta_orange_large.png`
- `res://assets/ui/components/button_cta_blue_large.png`
- `res://assets/ui/components/field_input_wide.png`
- `res://assets/ui/components/bar_progress_fill_green.png`
- `res://assets/ui/components/bar_progress_fill_blue.png`
- `res://assets/ui/components/pill_small_cream.png`
- `res://assets/ui/components/pill_medium_cream.png`
- `res://assets/ui/components/panel_tabbed_small.png`
- `res://assets/ui/components/button_round_green.png`
- `res://assets/ui/components/panel_shop_large.png`
- `res://assets/ui/components/panel_reward_popup.png`

## Implementação esperada
1. Criar `ui/FarmHUD.tscn` em `CanvasLayer`.
2. Criar componentes reutilizáveis:
   - `MoneyCounter.tscn`
   - `TomatoCounter.tscn`
   - `CrateCounter.tscn`
   - `WaterCounter.tscn`
   - `CoinCounter.tscn`
   - `MissionPanel.tscn`
   - `RewardPopup.tscn`
   - `StoreButton.tscn`
3. Usar `cash_bundle_official.png` como ícone do contador de dinheiro e em popups de recompensa monetária.
4. Renderizar valores dinamicamente usando Labels: exemplos `1250`, `18/56`, `3/7`, `30`.
5. O painel de missão deve aceitar título e barra de progresso programaticamente.
6. O popup de recompensa deve aceitar ícone, valor e animação de entrada/saída.
7. Validar layout em mobile retrato.

## Restrições
- Não use o arquivo `reference/ui_preview_example.png` como asset runtime. É apenas referência visual.
- Não use nenhum asset contendo números embutidos de versões antigas.
- Não cortar novamente os PNGs, para evitar imagens incompletas.

## QA obrigatório
- Confirmar que nenhum PNG fica cortado na UI.
- Confirmar que todos os campos numéricos são desenhados pela engine.
- Confirmar que o dinheiro usa o maço verde oficial.
- Gerar uma cena de preview demonstrando os componentes aplicados.