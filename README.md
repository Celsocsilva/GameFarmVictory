# Farm Victory — Demo v4 Complete

Demo browser sem dependências externas, criado para validar o vertical slice do Farm Victory.

## O que funciona
- escolha entre 6 personagens
- movimentação contínua por clique com animação de caminhada
- câmera suave seguindo o personagem
- mapa 2800×1800 com corredores amplos de circulação
- campo inicial de tomate 4×4 (16 células)
- plantar, crescer e colher tomate
- consumo e regeneração de energia
- galinheiro com produção e coleta de ovos
- clientes caminhando até a banca
- clientes compram tomates/ovos quando há estoque
- dinheiro e receita atualizados
- pilha visual de dinheiro cresce com as vendas
- progressão de tarefas
- área de trigo bloqueada por expansão
- desbloqueio da área por $500
- campo de trigo funcional após expansão
- inventário, loja, tarefas, mapa e configurações
- save automático via localStorage

## Como executar
### VS Code + Live Server
Abra `index.html` com **Open with Live Server**.

### Ou Python
```bash
python -m http.server 8080
```
Depois abra `http://localhost:8080`.

## Observação
O objetivo desta versão é validar gameplay, circulação, progressão, clientes e composição antes de migrar a demo aprovada para Phaser 3/TypeScript.
