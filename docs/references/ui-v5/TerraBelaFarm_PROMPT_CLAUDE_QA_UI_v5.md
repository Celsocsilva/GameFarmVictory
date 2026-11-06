# TerraBela Farm — Prompt 2: Auditoria e correção final dos assets UI v5

**Destino:** Claude Code  
**Repositório:** https://github.com/Celsocsilva/GameTerraBelaFarm  
**Referência:** `TerraBelaFarm_UI_Refatorado_Claude_v5.zip`, especialmente `docs/ASSET_MAP.md` e `docs/QA_UI_v5.json`.

Atue como Technical Artist, QA Engineer e Release Engineer. Faça uma auditoria completa dos componentes UI v5 após integração no Godot. Identifique falhas e corrija-as sem alterar a lógica do jogo.

## Verificações de arte

- Inspecione cada PNG runtime separadamente, com visualização sobre fundos branco, preto e xadrez.
- Verifique limites completos e margem de transparência: nenhum objeto deve estar truncado no próprio PNG ou na aplicação Godot.
- Verifique se cada asset contém **um componente completo**, sem fragmentos de peças vizinhas.
- Verifique tratamento alfa, bordas, halos, serrilhamento excessivo e distorção ao redimensionar.
- Inspecione os oito componentes anteriormente problemáticos: três botões CTA, `pill_small_cream`, `pill_medium_cream`, `panel_tabbed_small`, `button_round_green` e `panel_reward_popup`.
- Meça a largura visível dos três CTAs em comparação à versão anterior, quando essa referência estiver disponível; a v5 já deve representar o aumento de 30% e **não pode receber mais 30%** na interface.
- Verifique que os números estão ausentes dos assets de contadores/painéis e que os `Label`s os renderizam em runtime.
- Confirme o uso de `res://assets/currency/cash_bundle_official.png` nos indicadores monetários. Não aceitar moedas douradas como substituição.

## Testes funcionais

1. Criar ou usar `UIAssetQA.tscn` para inspecionar cada PNG isolado, com nome do arquivo e fundo de contraste — os nomes devem ser `Label`s, não gravados nas imagens.
2. Abrir a HUD no gameplay e testar 0, 1, 999, 1.250 e 9.999.999 no dinheiro; 0/56, 18/56 e 56/56 nos tomates; 0/7, 3/7 e 7/7 nas caixas.
3. Abrir/fechar o popup de recompensa e conferir que o valor e descrição são componentes dinâmicos.
4. Testar CTAs nos estados normal, hover, pressed, disabled e foco de teclado, se aplicável.
5. Testar ancoragem nas resoluções 720×1280, 1080×1920 e desktop; confirmar que não cobre joystick nem pontos críticos da plantação.
6. Verificar se sinais atualizam a HUD apenas uma vez por alteração e não geram saldo fictício ou crédito duplicado.
7. Executar validações headless/importação existentes e os testes reais que o ambiente permitir.

## Evidências e relatório

Para cada defeito, registre: arquivo, reprodução, causa-raiz, correção e captura de antes/depois. Salve capturas reais das três resoluções, a tela de QA dos assets e a HUD com valores extremos. Informe o resultado objetivo de cada teste (aprovado, reprovado, não executado e motivo). Não declare que houve validação visual se não foi possível abrir o jogo.

## Regra de release

Bloqueie o PR enquanto houver componente visual cortado, valor fixo dentro de textura runtime, deformação de botão ou ícone de dinheiro diferente do oficial. Não realize merge automático na `main`.
