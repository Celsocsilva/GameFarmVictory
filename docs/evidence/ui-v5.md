# UI v5 — integração do HUD e auditoria de QA

Execução local em 6 de novembro de 2026, Windows, Godot 4.7.2 Standard, renderizador Mobile. Pacote de entrada: `TerraBelaFarm_UI_Refatorado_Claude_v5.zip` e os dois prompts (`TerraBelaFarm_PROMPT_CLAUDE_UI_v5.md`, `TerraBelaFarm_PROMPT_CLAUDE_QA_UI_v5.md`), guardados em `docs/references/ui-v5/` (a pasta `docs/` não é importada pela Godot, então nada de lá vira asset de runtime). A v5 substitui a v4 por completo: os 37 PNGs de `assets/ui/` e `assets/currency/` foram sobrescritos pelos da v5, sem nenhuma edição de pixel.

## Resultado

**Aprovado.** Nenhum componente cortado, nenhum número dentro de textura de runtime, nenhum botão deformado e o dinheiro usa o maço oficial em todos os indicadores. Ressalvas na seção "Pendências".

| # | Teste | Resultado | Evidência |
|---|---|---|---|
| 1 | Os 37 PNGs de runtime são os da v5: RGBA, cantos transparentes, nenhum pixel visível na borda (objeto inteiro), margem transparente de 10 a 16 px, tamanhos iguais ao `QA_UI_v5.json` | Aprovado | `tools/ui_asset_audit.gd` → `UI_ASSET_AUDIT_OK files=37` |
| 2 | Cada asset tem um componente só, sem pedaços de peças vizinhas | Aprovado | auditoria: 1 ilha opaca por PNG; `icon_gift` tem 3 (presente e raios, parte do desenho). Inspeção visual em `qa-01` a `qa-07` |
| 3 | CTAs v5 30% mais largos que na v4, sem mudança de altura | Aprovado | verde +30,2%, laranja +30,1%, azul +30,3%, altura +0,0% (largura visível medida por alfa contra os PNGs da v4) |
| 4 | Nenhum fator extra de 1,3 nos CTAs em runtime | Aprovado | `CtaButton` usa `STRETCH_KEEP_ASPECT_CENTERED` e `fit_height()` (mesma escala em X e Y); o teste confere proporção do botão igual à do PNG |
| 5 | Os oito componentes corrigidos (3 CTAs, `pill_small_cream`, `pill_medium_cream`, `panel_tabbed_small`, `button_round_green`, `panel_reward_popup`) sem corte e sem fragmentos | Aprovado | `qa-01` (xadrez), `qa-02` (branco), `qa-03` (preto), com contorno rosa do PNG inteiro |
| 6 | Halos e alfa nas bordas sobre fundo branco, preto e xadrez | Aprovado (inspeção visual) | `qa-01` a `qa-07`; sem halo claro visível no fundo preto |
| 7 | Números ausentes dos PNGs de contadores e painéis; valores desenhados por `Label` | Aprovado (inspeção visual) | não há OCR; conferido nas capturas da tela de QA. Todo valor no HUD é `Label` |
| 7b | Progresso pintado dentro de PNG de runtime | Aprovado com mitigação | `mission_panel_bg.png` traz uma barra verde parcial desenhada (cerca de 50%). No HUD ela fica totalmente coberta pela `HudProgressBar` (trilho + preenchimento reais), então o jogador só vê o progresso real (`qa-05` mostra o PNG cru). Recomendo corrigir o PNG para a barra vir vazia |
| 8 | Dinheiro: 0, 1, 999, 1.250, 9.999.999 sem truncar | Aprovado | `hud_smoke`: 9.999.999 cabe com a fonte reduzida de 40 para 23 (112 de 119 px). Capturas `*-05-valores-extremos.png` |
| 9 | Tomates 0/56, 18/56, 56/56 e caixas 0/7, 3/7, 7/7 vindos da mochila real | Aprovado | `hud_smoke` (`QA_BACKPACK`) e capturas `01`, `02`, `05` |
| 10 | Popup de recompensa abre e fecha com animação; título, mensagem e valor dinâmicos | Aprovado | `hud_smoke` e capturas `*-03-popup-recompensa.png` |
| 11 | Abrir o popup não cria dinheiro; coletar várias vezes credita uma vez | Aprovado | `hud_smoke` (`QA_SIGNALS reward_once=15`) |
| 12 | HUD atualiza uma vez por mudança e não atualiza sem mudança | Aprovado | `hud_smoke` (`update_count`) |
| 13 | CTAs: normal, hover, pressed, disabled e foco | Aprovado | `hud_smoke` (`QA_CTA`), linha de estados em `qa-01`. Hover e pressed foram testados pelos sinais `mouse_entered` e `button_down`, porque a janela headless não recebe ponteiro real |
| 14 | 720x1280 | Aprovado | capturas `720x1280-01` a `05` (janela real) |
| 15 | 1080x1920 | Aprovado, com observação | o monitor desta máquina tem 1080 px de altura e o Windows reduziu a janela para 1080x1570. A captura foi feita num `SubViewport` de 1080x1920 exatos com o mesmo stretch `expand` (área lógica 1280x2275), renderizado pela engine: `1080x1920-01` a `05` |
| 16 | Desktop 1280x720 | Aprovado | capturas `1280x720-01` a `06` |
| 17 | HUD não cobre o joystick nem o centro da tela (fazendeiro e canteiro) | Aprovado | `hud_smoke` testa as três áreas lógicas; avisos de venda também não cobrem a faixa de mensagens |
| 18 | Testes existentes | Aprovado | `farm_smoke`, `harvest_smoke`, `customer_smoke`, `sales_counter_smoke`, `angle_audit`: todos com código 0 |
| 19 | Vídeo curto | Não executado | entregue como sequência de capturas `01` a `05` por resolução (antes, depois, recompensa, venda, extremos) |
| 20 | Teste num celular Android real | Não executado | não há aparelho conectado nesta sessão |

## Defeitos encontrados e corrigidos nesta rodada

| Arquivo | Reprodução | Causa | Correção |
|---|---|---|---|
| `scripts/ui/hud/*.gd`, cenas dos componentes | Textos fora das áreas creme depois da troca para a v5 | Os PNGs v5 ganharam margem transparente de 12 px (10 nos CTAs, 16 no popup) | Áreas de texto deslocadas pela margem; tamanhos das cenas iguais aos PNGs v5 |
| `RewardPopup` | Na v4 o popup usava recorte de exibição para esconder uma aba e um círculo soltos | Defeito do PNG v4, corrigido na v5 | Recorte removido: o popup usa o PNG v5 inteiro (577x546); novo layout de título, mensagem, valor e botão |
| `HudProgressBar` | Barra de progresso fina demais com o PNG v5 | Margem transparente de 12 px entrava no nine-patch | `AtlasTexture` com a área visível do PNG (sem alterar o arquivo); o teste confere que só pixels transparentes ficam fora da região |
| `HudCounter` | "9.999.999" estourava a área creme do contador | Fonte fixa de 40 px | `UiStyle.fit_font()` reduz a fonte até caber; vale para contadores, barras, popup e aviso de venda |
| `FarmHUD` (retrato) | Aviso de venda em cima da faixa "Mochila cheia" e saindo pela direita em 720x1280 | Mesma linha da faixa; escala em torno do centro sem compensação | Faixa vai para baixo do painel de missão em retrato; avisos alinhados à direita com compensação da escala; o teste mede o retângulo visível real |
| `CtaButton` (novo) | Botão "Coletar" era um `TextureButton` sem estados | Não havia componente de CTA | Componente com estados normal, hover, pressed, disabled e anel de foco, texto em `Label` |

## Novidades da integração v5

- `scenes/ui/hud/components/CtaButton.tscn`: CTA verde, laranja ou azul (`color`), texto por `text`, `fit_height()`, `set_enabled()`, `get_state_name()`.
- `scenes/ui/hud/UIAssetQA.tscn`: inspeção de cada PNG isolado com o nome num `Label` e fundo xadrez, branco ou preto (tecla B), três páginas (PgUp/PgDn), e a linha de estados dos três CTAs.
- `FarmHUD`: `set_money(value)`, `set_tomatoes(current, maximum)`, `set_crates(current, maximum)`, `set_mission(title, current, target)` para preview e testes. No jogo os valores continuam chegando pelos sinais de `Wallet`, `HarvestInventory` e `SalesController`.
- `tools/ui_asset_audit.gd`: auditoria headless dos PNGs.

## Comandos

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/ui_asset_audit.gd -- "<pasta do pacote v4>"
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/hud_smoke.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/farm_smoke.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/harvest_smoke.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/customer_smoke.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/sales_counter_smoke.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/angle_audit.gd
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s tools/hud_capture.gd -- <pasta> 1280x720
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 720x1280 -s tools/hud_capture.gd -- <pasta> 720x1280
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 720x1280 -s tools/hud_capture.gd -- <pasta> 1080x1920
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s tools/hud_capture.gd -- <pasta> qa
```

## Capturas (engine real, pasta `ui-v5/`)

- 1280x720: [antes](ui-v5/1280x720-01-hud-antes.png), [depois](ui-v5/1280x720-02-hud-depois.png), [recompensa](ui-v5/1280x720-03-popup-recompensa.png), [venda](ui-v5/1280x720-04-popup-venda.png), [extremos](ui-v5/1280x720-05-valores-extremos.png), [preview](ui-v5/1280x720-06-preview-componentes.png)
- 720x1280: [antes](ui-v5/720x1280-01-hud-antes.png), [depois](ui-v5/720x1280-02-hud-depois.png), [recompensa](ui-v5/720x1280-03-popup-recompensa.png), [venda](ui-v5/720x1280-04-popup-venda.png), [extremos](ui-v5/720x1280-05-valores-extremos.png)
- 1080x1920: [antes](ui-v5/1080x1920-01-hud-antes.png), [depois](ui-v5/1080x1920-02-hud-depois.png), [recompensa](ui-v5/1080x1920-03-popup-recompensa.png), [venda](ui-v5/1080x1920-04-popup-venda.png), [extremos](ui-v5/1080x1920-05-valores-extremos.png)
- UIAssetQA: [v5 xadrez](ui-v5/qa-01-componentes-v5-xadrez.png), [v5 branco](ui-v5/qa-02-componentes-v5-branco.png), [v5 preto](ui-v5/qa-03-componentes-v5-preto.png), [HUD e ícones xadrez](ui-v5/qa-04-hud-e-icones-xadrez.png), [HUD e ícones preto](ui-v5/qa-05-hud-e-icones-preto.png), [demais xadrez](ui-v5/qa-06-demais-componentes-xadrez.png), [demais preto](ui-v5/qa-07-demais-componentes-preto.png)

A imagem `PREVIEW_COMPONENTES_CORRIGIDOS_v5.png` do pacote está só em `docs/references/ui-v5/` como referência e não é usada como evidência.

## Pendências

- **Retrato no celular:** o projeto usa stretch aspect `keep` com base 1280x720. Num celular em pé o jogo inteiro fica numa faixa 16:9 com barras pretas. As capturas em retrato usam `expand` só dentro do script de captura. O HUD já se adapta a `expand` (componentes 1,35x maiores em retrato), mas trocar o projeto para `expand` também muda o enquadramento da câmera 3D em pé, por isso fica para uma decisão separada.
- **9.999.999 no contador:** cabe sem truncar, mas com a fonte reduzida para 23 px de 40 dentro da área creme do PNG. Se for um valor comum no jogo, vale um PNG de contador com área de valor mais larga.
- **Fora do escopo do HUD:** nas capturas em retrato aparecem riscos horizontais finos nas caixas 3D da mochila quando elas se sobrepõem (sprites 3D, não a interface).
- Água, moedas e loja ainda não têm estado no jogo: os contadores existem e aparecem só na preview, e a loja mostra "Loja em breve!".
