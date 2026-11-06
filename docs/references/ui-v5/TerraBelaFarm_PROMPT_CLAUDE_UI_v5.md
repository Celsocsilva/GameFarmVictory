# TerraBela Farm — Prompt 1: Integração da interface UI Kit v5

**Destino:** Claude Code  
**Projeto:** https://github.com/Celsocsilva/GameTerraBelaFarm  
**Engine:** Godot 4.x — identificar a versão utilizada no repositório.  
**Pacote de entrada:** `TerraBelaFarm_UI_Refatorado_Claude_v5.zip` (assets já separados).

Atue como Tech Lead, UI/UX Game Designer, Godot UI Engineer, Technical Artist e QA. Integre a versão **v5** da interface do TerraBela Farm, preservando a funcionalidade atual. Não substituir o gameplay, a câmera, o joystick ou a lógica de cultivo e colheita.

## Contratos de arte obrigatórios

1. **A v5 substitui a v4**. Utilize exclusivamente os PNGs individuais do pacote em `assets/ui/` e `assets/currency/`; não use folhas de sprites nem recortes antigos em runtime.
2. **Dinheiro oficial:** `res://assets/currency/cash_bundle_official.png` — maço verde com faixa branca. Não substituir por moeda dourada, nota isolada ou ícone alternativo de dinheiro.
3. **Valores dinâmicos:** saldo monetário, tomates, caixas, nível, água, moeda premium, percentuais, títulos e mensagens devem ser produzidos por `Label` / `RichTextLabel` ou controles Godot equivalentes, **nunca embutidos nos PNGs**.
4. **Botões horizontais** `button_cta_green_large.png`, `button_cta_orange_large.png` e `button_cta_blue_large.png` já foram ampliados em **30% na largura**. Não aplicar novo fator de 1,3. Dimensionar responsivamente sem deformar cantos.
5. Os arquivos `pill_small_cream.png`, `pill_medium_cream.png`, `panel_tabbed_small.png`, `button_round_green.png` e `panel_reward_popup.png` foram corrigidos na v5. Proibido recuperar os recortes defeituosos da v4.
6. Preservar proporção, transparência alfa e contornos completos. Para ampliar elementos, usar `TextureButton`, `TextureRect`, `NinePatchRect` (quando as margens forem adequadas) ou composição de `Control`s — nunca esticar a textura de modo a deformar as extremidades.

## Fluxo de implementação

**A. Inventário:** localize HUD, sinais, fonte de dados e caminhos existentes. Compare com `docs/ASSET_MAP.md` e `docs/QA_UI_v5.json`. Faça backup ou branch antes de modificar cenas.

**B. Importação:** extraia o pacote para os caminhos previstos ou adapte as referências mantendo organização sem duplicidade. Valide PNGs como RGBA e não execute recorte adicional. Trate `reference/` apenas como referência, nunca como asset de runtime.

**C. Cena e componentes:** reutilize cenas existentes quando possível; caso não haja, implemente `FarmHUD.tscn` com `CanvasLayer` e controles reutilizáveis para dinheiro, tomates, caixas, nível, missões, recursos, botões, loja e recompensas. Evite criar uma segunda HUD ativa.

**D. Dados e sinais:** conecte os contadores às fontes reais já existentes. Ofereça métodos simples como `set_money(value)`, `set_tomatoes(current, maximum)`, `set_crates(current, maximum)` e `set_mission(title, current, target)`. Se algum backend ainda não existir, use um *preview* de teste isolado e rotulado; não invente saldo real.

**E. Layout:** dimensione elementos com `Container`s, anchors, margens e *safe areas* para mobile retrato e desktop. Garanta que a HUD não cubra controles nem zonas críticas de gameplay. As áreas de valor devem acomodar pelo menos `9.999.999` e `56/56` sem truncamento.

**F. Interações:** botões devem ser clicáveis, refletir `hover`, `pressed`, `focus` e `disabled` quando aplicável. Recompensas devem usar popup com entrada e saída suave, exibindo valor em texto dinâmico; não criar recompensa ou transação por simples abertura do popup.

## Critérios de aceite

- Todas as imagens usadas são componentes **individuais** da v5.
- Nenhum botão, painel, aba, toldo ou popup apresenta corte na borda ou pedaço de outro asset.
- Os três CTAs estão 30% mais largos no arquivo-fonte que na versão anterior, sem deformação adicional no runtime.
- Nenhum número ou texto de progresso está incorporado à textura de runtime.
- O contador de dinheiro usa o **maço verde oficial**.
- Valores se atualizam por código e eventos; não há contadores duplicados.
- A interface funciona em 720×1280, 1080×1920 e na resolução desktop usada na demo.
- Joystick, câmera, plantio, colheita e interação preservados.

## Evidência obrigatória

Execute o jogo e salve capturas **reais da engine**, uma por resolução alvo, além de um vídeo curto ou sequência de capturas demonstrando atualização de saldo, tomates, caixas e popup. Documente os caminhos das evidências, logs e testes executados. Se não houver execução gráfica disponível, declare explicitamente essa limitação; não apresente a imagem de referência como evidência de execução.

## Entrega

Implemente em branch isolada, registre arquivos alterados e motivo, apresente relatório de QA e prepare um Pull Request **sem merge automático**. A implementação só estará pronta se todos os critérios de aceite estiverem comprovados.
