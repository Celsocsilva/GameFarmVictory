# Regras e procedimentos do Farm Victory

Versão consolidada em 7 de outubro de 2026

Este documento orienta o funcionamento do jogo, o uso pelo jogador e a manutenção da implementação. O ciclo principal é caminhar pela fazenda, plantar ao tocar nos canteiros vazios, colher plantas maduras, descarregar produtos na banca, atender clientes, recolher pagamentos e ampliar os campos.

As regras mais recentes substituem os ajustes anteriores. O crescimento leva 25 segundos, a colheita de plantas com check é imediata e as animações de colheita rodam a 12 FPS. Não existe espera adicional para colher uma planta pronta.

## 1 Cenário e início da partida

O jogo funciona no navegador. A fazenda tem mapa de 2.800 por 1.800 unidades, câmera que acompanha o jogador, casa, celeiro, campo de tomate, galinheiro, banca e área de trigo inicialmente bloqueada.

O jogador escolhe entre seis personagens: Fazendeiro Azul, Fazendeira Amarela, Jardineira Verde, Fazendeiro Verde, Fazendeira Ruiva e Fazendeiro Sênior. As artes de ações especiais disponíveis mostram o fazendeiro azul; adaptar essas ações aos demais personagens ainda é uma extensão futura.

Uma nova partida começa com $280, 12 gemas, 28 de energia e limite de 30 de energia. A mochila e a banca começam sem produtos, há dois ovos prontos e o campo de tomate contém quatro plantas maduras, quatro em crescimento e oito canteiros vazios. O trigo começa bloqueado. Um salvamento existente substitui esses valores iniciais.

A grama deve formar uma superfície contínua, com encaixe e sobreposição das imagens. Não deve parecer um tabuleiro com blocos isolados. Os canteiros seguem uma grade isométrica; as plantas da frente sobrepõem as de trás, preservando a proporção dos assets e o alinhamento do solo.

A área comercial não contém os antigos blocos de rio nem a ponte. Barril de tomates, caixas, vaso e pequenos detalhes de vegetação enriquecem a cena sem bloquear os caminhos ou esconder as áreas de interação.

## 2 Movimento e colisões

O controle principal é o círculo de arraste ao lado do fazendeiro. O jogador toca ou clica nele, mantém pressionado e arrasta para indicar a direção. Ao soltar, o movimento comandado pelo círculo para. O controle usa joystick_base.png e joystick_knob.png e acompanha o personagem quando não está sendo arrastado.

Também é possível clicar no chão para escolher um destino. O personagem caminha até ele; ao encontrar a banca ou o galinheiro, procura um caminho ao redor. O arraste respeita as mesmas colisões, podendo deslizar pela borda do obstáculo.

O fazendeiro não atravessa a banca, o galinheiro nem a cerca dos compradores. O limite é calculado pela área ocupada no chão e pelos pés do personagem, sem tratar as partes altas das imagens como piso. Os clientes permanecem do lado externo da cerca; o fazendeiro, do lado interno.

Na caminhada lateral, os quadros 09 e 10 são usados para a esquerda; 11 e 12, para a direita. Não se alternam quadros voltados a lados opostos na mesma direção. A câmera acompanha o movimento suavemente e as animações de ações não devem travar a caminhada.

## 3 Plantio e crescimento

Tomate e trigo têm canteiros independentes e nunca compartilham imagens de cultura. O campo de tomate começa com quatro filas de quatro canteiros. O trigo, quando liberado, tem três filas de quatro canteiros.

Encostar na área do solo de um canteiro vazio inicia o plantio automaticamente. Não é necessário clicar em um botão nem atingir o centro exato da planta. A detecção considera a borda do quadrante e uma margem de contato do personagem.

O plantio muda imediatamente o estado para semente e registra o horário. Desconta até $2 e uma unidade de energia disponíveis, sem produzir saldo negativo. Na regra atual, falta de saldo ou de energia não bloqueia o plantio. Permanecer sobre o mesmo canteiro não repete a cobrança nem reinicia o crescimento.

| Etapa | Tempo desde o plantio | Comportamento |
| --- | --- | --- |
| Vazio | Antes de plantar | Exibe a base ou imagem de semente como representação do terreno disponível |
| Semente | De 0 até 10 segundos | Plantio realizado e crescimento iniciado |
| Crescendo | De 10 até 25 segundos | Desenvolvimento da planta durante mais 15 segundos |
| Maduro | A partir de 25 segundos | Exibe check e permite colher imediatamente |

A contagem visual acompanha a etapa atual. Os tempos são determinados pelo horário registrado, não pelo número de quadros exibidos. Uma planta já madura não precisa esperar outra contagem ou o fim de uma animação.

O trigo deve usar wheat_seed.png, wheat_growing.png e wheat_mature.png. O tomate usa tomato_seed.png, tomato_growing.png e tomato_mature.png. A imagem exibida no terreno vazio não significa que ele já foi plantado: o estado interno permanece vazio até o contato.

## 4 Colheita e ações do personagem

O check indica que a planta está madura e pode ser colhida. Essa regra vale tanto para tomate quanto para trigo. Encostar em um canteiro maduro efetua a coleta imediatamente, inclusive com energia zerada ou outra animação em reprodução.

Cada canteiro colhido acrescenta uma unidade da cultura correta à mochila e volta ao estado vazio. A colheita desconta até uma unidade de energia disponível, sem bloquear a ação nem deixar energia negativa. O jogador não deve receber o mesmo produto duas vezes pela mesma colheita.

Após colher, o canteiro não replanta imediatamente na mesma passagem. Uma nova passagem pelo terreno vazio inicia o plantio. Se o jogador permanecer próximo de uma planta até ela amadurecer, o check libera a coleta mesmo que o local tenha sido atendido antes.

As animações são apresentação visual: não atrasam o crédito do produto, o movimento ou a próxima colheita. O personagem mantém sua escala e os pés alinhados ao chão durante a troca de imagens. Imagens são pré-carregadas, quadros só mudam quando necessário e atualizações da interface são agrupadas por quadro.

| Ação | Asset ou sequência | Reprodução atual |
| --- | --- | --- |
| Colher tomate | tomato_harvest_vacuum com seis quadros | 12 FPS e duração de 0,5 segundo |
| Colher trigo | wheat_harvest_sickle com doze quadros | 12 FPS e duração de 1 segundo |
| Plantar trigo | farmer_plant_wheat.png | Pose por aproximadamente 0,65 segundo |
| Plantar milho | farmer_plant_corn.png | Configurado para futura integração do milho |
| Plantar tomate | 14_action_harvest.png do personagem | Pose genérica atualmente usada |

O trigo apresenta a sequência de aproximação, preparação, levantamento da foice, corte, reunião, levantamento do feixe, transporte e saída. O tomate apresenta a coleta com aspirador. Os ajustes anteriores de cinco segundos por quadro não fazem parte da regra atual.

## 5 Galinheiro e produtos

O galinheiro produz um ovo a cada 12 segundos enquanto houver menos de seis ovos prontos. A nova partida começa com dois. Ao clicar no galinheiro ou no ninho, o fazendeiro caminha até o ponto de interação e recolhe os ovos prontos para a mochila.

A mochila registra tomate, ovos e trigo separadamente. Colher não abastece a banca automaticamente. Os produtos precisam ser levados até a área de entrega.

Mochila, estoque da banca e dinheiro pendente são recursos distintos. A mochila contém o que o fazendeiro carrega. A banca contém o que foi descarregado e pode atender os pedidos disponíveis. Dinheiro pendente corresponde a vendas já realizadas cujo pagamento ainda não foi recolhido.

As gemas aparecem no painel superior, mas ainda não têm uma compra ou aplicação implementada. A energia regenera uma unidade a cada oito segundos, até o máximo de 30.

## 6 Banca e compradores

A área de entrega é um círculo visível, usando interaction_ring.png, pouco à frente da pequena caixa de tomates da banca. Não deve ficar abaixo do poste, sob a cerca ou escondida por outra imagem.

Ao entrar no círculo, o fazendeiro descarrega todos os tomates, ovos e trigos da mochila para o estoque da banca. A transferência acontece uma única vez por quantidade carregada: o estoque aumenta e a mochila zera. Clicar no círculo ou na banca também comanda o deslocamento até a entrega.

Os clientes alternam entre três pontos de atendimento ao longo da cerca. Um ponto ocupado não recebe outro comprador esperando. Há no máximo três clientes ativos; novas chegadas são tentadas aproximadamente a cada oito segundos quando há espaço.

Cada comprador mostra o produto e a quantidade desejados. Quando chega ao ponto, aguarda brevemente e consulta o estoque da banca. Se não houver a quantidade completa, continua aguardando. Não retira produtos diretamente da mochila e não consome um pedido incompleto.

| Produto comprado atualmente | Quantidade por pedido | Valor por unidade |
| --- | --- | --- |
| Tomate | De 1 a 3 unidades | $24 |
| Ovo | 1 unidade | $18 |

Na sequência atual de compradores, cada quarto cliente pede ovo; os demais pedem tomate. O trigo pode ser descarregado e armazenado, mas clientes comprando trigo e seu preço de venda ainda não foram implementados. Não se deve considerar essa venda como funcional.

Quando o pedido é atendido, os produtos saem do estoque e o pagamento entra no dinheiro pendente. A receita acumulada é atualizada nessa hora, mas o saldo disponível do fazendeiro só aumenta após recolher o dinheiro. O cliente mostra o pagamento e deixa o local pelo lado externo da cerca.

## 7 Dinheiro e coleta automática

A área do dinheiro fica à frente da banca e recuada para dentro da cerca, sem se sobrepor à estrutura. O contorno é um quadrado com cantos arredondados, borda branca e fundo transparente, projetado na inclinação isométrica do mapa.

Os pagamentos são representados por cash_bundle_01.png em uma grade de seis por seis posições. Os maços se acumulam à medida que os clientes pagam. A representação usa aproximadamente um maço por $24 pendentes; o texto apresenta o valor exato.

Ao completar 36 posições, novos pagamentos continuam sendo contabilizados e a indicação mostra camadas adicionais. A quantidade visual de imagens é limitada, mas o valor acumulado nunca pode ser perdido por falta de espaço na grade.

Passar sobre a área recolhe automaticamente todo o dinheiro pendente. Também é possível clicar nela para caminhar até o ponto e recolher. Após a coleta, o saldo aumenta pelo valor exato, o dinheiro pendente zera e a pilha é atualizada.

A coleta mostra o valor positivo flutuando sobre o personagem, anima um maço de notas e destaca o saldo no painel. Permanecer no local não duplica o crédito. O contorno continua visível mesmo com a área vazia.

## 8 Expansão e desafios

O dinheiro recolhido pode ser usado para liberar o trigo e adicionar filas aos campos. Receita acumulada e pagamentos ainda no chão não contam como saldo disponível para essas compras.

| Expansão | Custo | Resultado e condição |
| --- | --- | --- |
| Liberar trigo | $500 | Abre a área com doze canteiros |
| Nova fila de tomate | $2.500 | Acrescenta quatro canteiros vazios e passa de 16 para 20 |
| Nova fila de trigo | $2.500 | Acrescenta quatro canteiros vazios e passa de 12 para 16 após liberar a área |

O botão Expandir abre a escolha de campo. Cada campo pode receber uma fila adicional nesta versão. A compra desconta o custo completo; com saldo insuficiente, informa quanto falta e não altera o campo. A mesma expansão não pode ser comprada duas vezes. Os novos canteiros seguem todas as regras de contato, plantio, crescimento e colheita.

A progressão atual é: plantar seis tomates; colher seis tomates; vender oito tomates; liberar o trigo; plantar quatro trigos; adicionar uma fila por $2.500; ampliar também o outro campo por $2.500.

Os desafios acompanham a progressão, mas não funcionam como autorização obrigatória para uma compra já disponível. O desafio de plantar quatro trigos usa atualmente a quantidade de canteiros de trigo que não estão vazios, e não um contador histórico de plantios.

## 9 Menus e salvamento

O painel superior mostra saldo, gemas e energia. Os botões inferiores abrem Loja, Inventário, Tarefas, Mapa e Expandir. A Loja informa o custo nominal das sementes; o plantio é feito por contato, sem compra manual de sementes.

O Inventário mostra mochila, produtos descarregados na banca e receita acumulada. Tarefas apresenta metas e progresso. Mapa descreve as áreas disponíveis. Configurações permite trocar personagem e reiniciar a demo.

O jogo salva automaticamente no armazenamento local do navegador, usando a chave farmVictoryDemoV4. Alterações relevantes são salvas e há salvamento periódico a cada três segundos. O registro inclui saldo, energia, estoque da mochila, banca, dinheiro pendente, campos, horários de plantio, área de trigo, personagem e progresso.

Recarregar a página deve preservar esse estado. Usar outro navegador, outro perfil ou outra origem pode abrir um salvamento diferente. A posição atual do fazendeiro e os clientes em trânsito não são persistidos; são reconstruídos ao iniciar a partida. Reiniciar a demo apaga o salvamento local e restaura os valores iniciais.

## 10 Procedimento para jogar

1. Abrir o jogo e escolher o personagem.
2. Segurar o círculo de arraste e caminhar até os canteiros.
3. Encostar nos canteiros vazios para plantar; observar a contagem de crescimento.
4. Tocar nos canteiros com check para colher imediatamente.
5. Recolher ovos no galinheiro quando disponíveis.
6. Entrar no círculo à frente da caixa de tomates para descarregar na banca.
7. Acompanhar os clientes nos pontos externos da cerca e os pagamentos acumulados.
8. Passar sobre o quadrado do dinheiro para transferir o valor ao saldo.
9. Usar Expandir para liberar o trigo e, ao reunir $2.500, escolher uma nova fila.
10. Repetir o ciclo e conferir os desafios no painel de tarefas.

## 11 Execução local e manutenção

O repositório é https://github.com/Celsocsilva/GameFarmVictory. A cópia local está em C:\Users\Celso\OneDrive\Documentos\ChatGPT\GAME FARM VICTORY\GameFarmVictory. O jogo usa index.html, style.css, game.js e a pasta assets, sem dependências de aplicação para iniciar a demo.

No PowerShell, entrar na pasta do projeto e executar python -m http.server 8080 --bind 127.0.0.1. Em seguida abrir http://localhost:8080 e manter o terminal do servidor aberto. Ctrl+C encerra o servidor. Para abrir a pasta no VS Code, executar code . no diretório do projeto.

Depois de alterar imagens, JavaScript ou CSS, atualizar o navegador com Ctrl+F5. O arquivo index.html também utiliza versões nas referências de JavaScript e CSS para reduzir problemas de cache. Uma aba antiga pode continuar exibindo regras anteriores até ser atualizada.

Antes de publicar, verificar a sintaxe com node --check game.js e os espaços do diff com git diff --check. Conferir git status, selecionar os arquivos desejados, criar o commit e executar git push origin main. A conta autenticada precisa ter permissão no repositório; a criação de um commit local não confirma o envio ao GitHub.

## 12 Critérios de aceitação

1. Caminhar em ambos os sentidos sem alternar involuntariamente a orientação do corpo.
2. Soltar o controle e confirmar que o personagem para; ações não congelam o movimento.
3. Tentar atravessar banca, galinheiro e cerca por clique e arraste; verificar que não atravessa e que destinos válidos continuam acessíveis.
4. Encostar na borda de canteiros vazios e confirmar plantio sem cobrança repetida, mesmo com recursos zerados.
5. Verificar semente até 10 segundos, crescimento até 25 segundos e check a partir daí.
6. Colher tomate e trigo com check, inclusive sem energia e durante uma animação. Confirmar a cultura correta na mochila.
7. Permanecer perto de uma planta até amadurecer e verificar a coleta. Confirmar que o canteiro recém-colhido não replanta imediatamente na mesma passagem.
8. Conferir 12 FPS nas duas colheitas, escala consistente, pés alinhados e ausência de imagens de tomate no ciclo do trigo.
9. Descarregar na área marcada e conferir a transferência exata entre mochila e banca.
10. Atender clientes somente com o estoque completo e confirmar que o pagamento não aumenta o saldo antes da coleta.
11. Recolher passando sobre o contorno do dinheiro e conferir crédito único, pilha atualizada e feedback visual.
12. Acumular mais de 36 posições visuais de pagamentos e confirmar que todo o valor permanece disponível.
13. Comprar cada expansão com saldo suficiente e confirmar custo, quatro novos canteiros e bloqueio de compra duplicada.
14. Recarregar a página e confirmar os campos, estoques, dinheiro pendente e expansões salvos.

## 13 Funcionalidades preparadas e limites atuais

O plantio de milho tem farmer_plant_corn.png configurado, mas o jogo ainda não possui campo de milho, ciclo de crescimento, inventário de milho, compradores de milho ou expansão correspondente.

A pasta assets/crops/wheat contém artes adicionais de etapas de corte e feixe. O ciclo de crescimento vigente continua utilizando os três assets wheat_seed.png, wheat_growing.png e wheat_mature.png. A sequência de colheita com foice está integrada separadamente como animação do personagem.

Venda de trigo, uso de gemas, outras construções e mais de uma fila adicional por campo precisam de regras específicas antes de serem considerados disponíveis. O documento não acrescenta custos, produtos ou funcionalidades além do estágio atual.
