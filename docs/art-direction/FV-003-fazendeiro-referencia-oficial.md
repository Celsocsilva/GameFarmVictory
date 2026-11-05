# FV-003 — Referência visual oficial do fazendeiro

**Projeto:** Farm Victory  
**Decisão de direção de arte:** aprovada em 05/11/2026  
**Status:** identidade visual definida; modelo 3D jogável ainda não produzido.

## Referência de imagem aprovada

A imagem enviada pelo responsável do projeto em 05/11/2026 é a **referência visual oficial** do personagem principal. Ela substitui referências genéricas anteriores do fazendeiro.

- Arquivo original preservado na Biblioteca do ChatGPT, em `/GAME FARM VICTORY/Referencias/Personagens/Fazendeiro_Referencia_Oficial.png`.
- Nome esperado para cópia no repositório, antes da integração com Meshy: `assets/characters/farmer/reference/farmer_reference.png`.
- **Atenção:** a imagem foi preservada na Biblioteca; a cópia binária ainda não integra este repositório. Não considerar o caminho acima como um asset já versionado.
- Antes de gerar o 3D, o Codex deve obter a **imagem original**, não criar um personagem distinto a partir de texto apenas.

## Identidade visual obrigatória

Personagem masculino adulto, fazendeiro simpático, apresentado de corpo inteiro, com estética **3D estilizada, cartoon premium de jogo mobile**. Preservar:

1. Chapéu de palha largo, com trama visível.
2. Cabelo castanho com volume; sobrancelhas expressivas.
3. Olhos castanhos grandes e expressivos, rosto amigável.
4. Barba curta e bigode castanhos; sorriso discreto.
5. Camisa xadrez vermelha com mangas dobradas; camiseta branca por baixo.
6. Jardineira jeans azul com bolso frontal, alças e botões metálicos.
7. Botas de trabalho marrons, com cadarços.
8. Proporções levemente cartunizadas, silhueta reconhecível em câmera isométrica.

### Ajustes permitidos para o gameplay

- Mãos um pouco maiores, para leitura de manipulações de produtos e caixas.
- Cabeça discretamente ampliada, preservando o rosto e a identidade.
- Simplificação de microdetalhes de tecido e geometria para desempenho mobile.
- Abertura técnica de braços e pernas em A-pose/T-pose para rigging.

**Não alterar** o design do chapéu, a combinação vermelho/azul/marrom, a barba, o rosto ou o estilo geral sem aprovação expressa.

## Modelo e animações

Gerar **um único modelo 3D mestre** com uma malha/personagem consistente, materiais e esqueleto reutilizáveis. Cada estado é um clipe de animação do mesmo personagem; não gerar oito personagens independentes.

| Estado | Uso |
| --- | --- |
| `idle` | Parado, respiração e movimentos sutis |
| `walk` | Caminhar com orientação 360° |
| `run` | Deslocamento acelerado |
| `plant` | Preparar/plantar na área de cultivo |
| `harvest` | Abaixar e colher produtos |
| `carry` | Caminhar transportando caixas |
| `unload` | Depositar produtos na bancada de vendas |
| `celebrate` | Reação positiva a progresso/conquista |

**Produção inicial (validação):** modelo mestre + rigging + somente `idle` e `walk`. Os demais clipes entram após aprovação no Godot.

### Caixas transportadas

- As caixas são **objetos 3D independentes**, não parte permanente da malha do fazendeiro.
- O jogo deverá exibir de 0 a **7 caixas empilhadas progressivamente**, conforme a capacidade e a carga efetiva.
- Associar as caixas a pontos de ancoragem adequados no personagem (ex.: braços/carga), controlados por gameplay.
- As animações `carry`, `harvest` e `unload` deverão respeitar esses objetos e evitar atravessamentos visíveis.
- A bancada de vendas permanece **sem cobertura**, e o fazendeiro deposita os produtos pelo lado interno da cerca.

## Pipeline recomendado — Meshy MCP + Codex + Godot

1. Ler a imagem de referência original e validar a configuração do Meshy MCP e os créditos disponíveis.
2. Gerar 3D a partir da referência (image-to-3D); fazer avaliação visual e ajustar apenas quando necessário.
3. Preparar versão adequada para auto-rigging (topologia, membros separados, pose neutra).
4. Executar rigging do mesmo personagem; manter o esqueleto entre os estados.
5. Gerar/testar `idle` e `walk`.
6. Exportar preferencialmente `.glb` com malha, materiais, esqueleto e clipes.
7. Integrar na cena do personagem atual no Godot 4 usando `AnimationTree` ou solução equivalente.
8. Preservar a movimentação em `CharacterBody3D`, câmera, colisões e mapa existentes; **o personagem se desloca no mundo, não o terreno**.
9. Revisar aparência em câmera isométrica, escala, sombreamento, materiais, transições e desempenho em mobile.
10. Após aceite, produzir os outros estados usando **o mesmo modelo base e esqueleto**.

## Organização prevista

```text
assets/characters/farmer/
  reference/farmer_reference.png  # copiar da Biblioteca antes de gerar
  source/                         # arquivos de trabalho e versões aprovadas
  farmer_master.glb               # modelo 3D e rig aprovados
  animations/                     # clipes exportados, quando separados
```

Os caminhos representam **estrutura alvo**, não arquivos já implementados.

## Critérios de aceite da primeira etapa

- [ ] Identidade do personagem fiel à imagem aprovada, inclusive quando visto de trás e de lado.
- [ ] Um único modelo/rig utilizado em todos os estados.
- [ ] Importação em Godot 4 sem perda de materiais ou hierarquia.
- [ ] `idle` e `walk` funcionam e transitam corretamente.
- [ ] Movimentação e câmera existentes preservadas.
- [ ] O modelo permanece legível e proporcional na câmera isométrica mobile.
- [ ] Pipeline preparado para `run`, `plant`, `harvest`, `carry`, `unload` e `celebrate`.
- [ ] Nenhum crédito pago é consumido sem previsão de custo e aprovação prévia.

## Custo

A referência aprovada reduz tentativas estilísticas, mas o consumo exato varia conforme versão do modelo Meshy, método de geração, textura, rigging, animações e revisões. Confirmar a **tabela atual da Meshy API** e o saldo antes de cada operação; estimativas anteriores de conversa não são preço garantido.

## Regra de governança

Qualquer alteração de aparência, proporção marcante, vestuário, paleta ou identidade facial exige nova aprovação. Novos estados de animação devem reutilizar o personagem aprovado. Não substituir o modelo por outros designs gerados automaticamente.
