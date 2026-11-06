# TerraBela Farm

TerraBela Farm é um jogo casual mobile nativo de fazenda e gerenciamento, com câmera isométrica ou perspectiva elevada fixa, estética 2.5D e elementos 3D estilizados. O jogador cultiva, colhe, transporta e vende produtos enquanto expande sua propriedade.

Este repositório é a base de reconstrução do projeto na Godot Engine. A prioridade é Android, mantendo compatibilidade arquitetural com iOS desde o início. O produto não será desenvolvido como site, PWA, aplicação HTML5 ou WebView.

## Visão do produto

O primeiro ciclo jogável deverá permitir:

1. Percorrer uma propriedade rural com câmera acompanhando o personagem.
2. Plantar e colher tomates.
3. Transportar a produção em uma pilha visível de até sete caixas.
4. Descarregar os produtos em uma bancada física de madeira, sem cobertura, com pelo menos quatro posições.
5. Atender clientes que permanecem do lado externo da cerca.
6. Acumular pagamentos dentro da propriedade e recolher o dinheiro.
7. Salvar, fechar e retomar a partida sem perder o progresso.

O mapa deverá reservar espaço para expansão e futuras cadeias produtivas, incluindo trigo, milho, galinhas, ovos, vacas e leite. Conteúdo adicional será priorizado depois da validação do vertical slice.

## Diretrizes aprovadas

- **Plataforma:** smartphones Android e iOS, inicialmente em orientação horizontal.
- **Engine:** Godot Engine 4.7.2 Standard.
- **Linguagem:** GDScript, com tipagem estática sempre que apropriado.
- **Renderização:** Mobile como configuração inicial; Compatibility será avaliado por testes.
- **Controles:** touchscreen, joystick virtual e interações por proximidade/toque.
- **Cultivo no protótipo:** `EMPTY → SEEDED → RIPE → HARVESTING → HARVESTED`; a grade só retorna a `EMPTY` quando todas as células da safra estiverem colhidas. Os quatro estágios visuais intermediários são geridos por `CropPlant`.
- **Tomates:** maturação inicial de referência em 25 segundos, configurável por recurso de cultura.
- **Transporte:** limite inicial de sete caixas, separado do inventário lógico.
- **Bancada:** estrutura física junto à cerca, sem toldo, tecido ou telhado.
- **Clientes:** sempre fora da cerca; o fazendeiro abastece pelo lado interno.
- **Receita:** pagamentos pendentes acumulam-se dentro da fazenda e só entram no saldo após coleta.
- **Persistência:** arquivos versionados e seguros em `user://`; não usar armazenamento local de navegador.
- **Web:** a implementação legada em HTML/JavaScript/CSS serve apenas como referência de regras e comportamento.

## Estado atual

O projeto está na **Fase 1 — Fundação Godot Mobile**. A base executável da Godot, a configuração mobile, a documentação de arquitetura e a orquestração de agentes já estão organizadas. O vertical slice completo ainda precisa ser implementado e validado em dispositivo Android real.

O protótipo Godot já inclui uma área contínua de tomate com três tiras de solo de três sulcos cada e sete posições por sulco (63 células), quatro estágios visuais da planta rasteira, semeadura, colheita durante a caminhada, mochila de até sete caixas e depósito 3D de tomates no rodapé do mapa. Cada planta totalmente colhida desaparece. O plantio da próxima safra só é liberado depois que todas as 63 células forem colhidas. As imagens das caixas da mochila foram ampliadas para o dobro da largura anterior e a pilha foi ajustada para permanecer visível na câmera. O depósito descarrega os tomates por proximidade; seu estoque ainda não está ligado ao sistema de save.

O legado foi removido da árvore atual, mas permanece no histórico. Para recuperar um arquivo específico da versão anterior:

```powershell
git checkout 1a85c87 -- caminho/do/arquivo
```

Não apagar conteúdo legado, alterar regras econômicas ou substituir assets aprovados sem registrar a decisão correspondente.

## Arquitetura alvo

O projeto deverá separar estado, regras de negócio, apresentação visual e integrações de plataforma:

| Domínio | Responsabilidade |
| --- | --- |
| Core | Estado da aplicação, eventos e configuração |
| World | Mapa, câmera, terrenos e obstáculos |
| Player | Controle, movimentação e animações |
| Farming | Cultivo, crescimento e colheita |
| Inventory | Itens, lotes, caixas e capacidade |
| Commerce | Bancada, clientes, pedidos e vendas |
| Economy | Saldo, pagamentos, custos e upgrades |
| Progression | Áreas, missões e desbloqueios |
| Animals | Animais e cadeias produtivas futuras |
| UI | HUD, menus e interação touchscreen |
| Persistence | Salvamento, carregamento e migração de dados |
| Platform | Android, iOS e ciclo de vida do aplicativo |

Cenas reutilizáveis, sinais e recursos configuráveis devem reduzir acoplamento. Economia não deve ficar embutida em scripts de animação ou componentes de interface. Regras independentes do motor devem possuir testes automatizados.

## Organização de agentes

O desenvolvimento assistido seguirá o fluxo:

`Demanda → Refinamento → Arquitetura → Tarefas → Implementação → QA → Review → PR → Build Mobile → Homologação`

Responsabilidades previstas:

- Game Director / Product Owner: escopo, prioridades e critérios de aceitação.
- Godot Solution Architect: cenas, recursos, contratos, sinais e padrões.
- Gameplay Engineer: movimentação, cultivo, inventário, comércio e economia.
- Technical Art & Animation: assets, materiais, câmera, animações e performance visual.
- Mobile UI/UX Engineer: joystick, HUD, menus e adaptação a telas.
- QA & Game Testing: testes unitários, integração, regressão e dispositivos reais.
- GitHub & Mobile DevOps: branches, CI/CD, exportações e releases.
- Engineering Reviewer: arquitetura, segurança, performance e efeitos colaterais.

Cada agente deve operar dentro de seu escopo, documentar handoffs e solicitar aprovação humana para decisões de produto, publicação, credenciais ou mudanças irreversíveis.

## Roadmap

### Fase 0 — Auditoria e consolidação

Inventariar código, assets, regras e documentação legados, classificando cada item como confirmado, legado sujeito a revisão ou novo requisito mobile. Registrar conflitos e decisões.

### Fase 1 — Fundação Godot Mobile

Fixar a versão Godot 4.7.2, configurar renderizador, orientação, resolução, Input Map, câmera, ciclo de vida e uma cena mínima executável em Android.

### Fase 2 — Engenharia agêntica

Criar `AGENTS.md`, `CLAUDE.md`, instruções individuais, contratos de entrada e saída, critérios de conclusão e regras de coordenação.

### Fase 3 — GitHub e CI/CD

Preparar validação headless, testes, Git LFS para binários selecionados, exportação Android e a preparação condicionada para iOS. O workflow iOS só deve ser habilitado quando houver macOS, Xcode, certificados e provisioning.

### Fase 4 — Vertical slice

Implementar o ciclo completo de cultivo, colheita, caixas, bancada, clientes, pagamentos, coleta e persistência sem depender de mouse, teclado ou navegador.

### Fase 5 — Expansão do MVP

Adicionar culturas, expansão de terrenos, animais, economia, missões, melhorias visuais, otimização e preparação para publicação.

## Critérios do primeiro vertical slice

O slice só será considerado funcional quando, em um Android real:

- o personagem responder ao joystick touchscreen;
- câmera e colisões funcionarem;
- tomates puderem ser plantados e colhidos;
- sete caixas forem o limite efetivo de transporte;
- o descarregamento atualizar corretamente o inventário;
- a bancada tiver quatro posições independentes;
- clientes permanecerem fora da cerca;
- vendas consumirem apenas estoque disponível;
- pagamentos se acumularem e forem creditados uma única vez na coleta;
- a partida persistir após fechar e reabrir;
- a interface funcionar em diferentes proporções de tela;
- o build Android for reproduzível e os testes forem registrados.

## Informações oficiais

- Nome: TerraBela Farm
- Tipo: jogo mobile nativo de fazenda e gerenciamento
- Engine: Godot Engine 4.7.2 Standard
- Plataforma prioritária: Android, com compatibilidade arquitetural para iOS
- Diretório local: `C:\Users\Celso\OneDrive\Documentos\ChatGPT\GAME TERRABELA FARM`
- Repositório: [github.com/Celsocsilva/GameTerraBelaFarm](https://github.com/Celsocsilva/GameTerraBelaFarm)
- Website oficial: [https://terrabelafarm.com](https://terrabelafarm.com)

## Git e contribuição

O histórico existente deve ser preservado.

Branches recomendadas:

- `main`: versão estável.
- `feature/*`: novas funcionalidades.
- `fix/*`: correções.
- `refactor/*`: refatorações.
- `release/*`: preparação de publicação.

Alterações devem ser pequenas, rastreáveis a um requisito ou Issue e revisadas por Pull Request quando aplicável. Não fazer force push, publicar builds ou inserir segredos no repositório sem autorização.

## Desenvolvimento local

Pré-requisitos planejados:

- Godot Engine 4.7.2 Standard.
- Git.
- Export templates da Godot para Android, quando a exportação estiver habilitada.
- Android SDK/JDK compatíveis para builds locais.

Clone o repositório e confira o estado:

```powershell
git clone https://github.com/Celsocsilva/GameTerraBelaFarm.git
cd GameTerraBelaFarm
git status
```

Para validar os contratos e a orquestração localmente:

```powershell
python tools\validate_agents.py
python -m unittest discover -s orchestration/tests -v
```

Para validar o projeto na Godot em modo headless, com a Godot disponível no `PATH`:

```powershell
godot --headless --path . --editor --quit
```

Para verificar os sistemas atuais de cultivo, colheita e depósito:

```powershell
godot --headless --path . --import
godot --headless --path . --script res://tools/farm_smoke.gd
godot --headless --path . --script res://tools/harvest_smoke.gd
godot --headless --path . --script res://tools/depot_smoke.gd
```

Os arquivos do ciclo do tomate estão descritos em [assets/crops/tomato/README.md](assets/crops/tomato/README.md). Os resultados desta implementação estão em [docs/evidence/fv-farm-006.md](docs/evidence/fv-farm-006.md).

As exportações Android dependem dos templates de exportação, Android SDK e JDK compatíveis.

## Segurança e qualidade

Toda alteração deve preservar funcionalidades aprovadas, registrar mudanças econômicas, evitar segredos, manter rastreabilidade entre requisito, branch, PR, teste e release, e declarar somente testes realmente executados. Builds Android e iOS exigem credenciais e ambientes apropriados; o Windows não deve ser tratado como ambiente de build local para iOS.

## Orquestração agêntica

O repositório também contém uma implementação assistida em orchestration/, dividida em Governance, Specialized Agents e Execution & Evidence. Ela persiste demandas em orchestration/state/, controla transições, gera handoffs versionados e registra evidências.

Para executar a validação local:

    python tools/validate_agents.py
    python -m unittest discover -s orchestration/tests -v

O modo assistido não exige API de LLM: o CLI prepara o pacote e o operador encaminha-o à sessão apropriada de ChatGPT ou Claude. Adaptadores automáticos de LLM permanecem desativados por padrão.
