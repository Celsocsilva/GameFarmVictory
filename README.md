# GameFarmVictory

**Farm Victory** é um jogo casual de fazenda e gerenciamento (*Farm / Management*) desenvolvido com **prioridade para dispositivos móveis (Android e iOS)**, em perspectiva isométrica/2.5D e direção de arte com padrão comercial mobile premium.

## Direção do projeto

- **Plataforma principal:** mobile (Android e iOS), com controles por toque.
- **Engine:** Godot 4.x; versão específica a validar e fixar na configuração do projeto.
- **Linguagem preferencial:** GDScript, na edição padrão do Godot (sem .NET), salvo necessidade técnica justificada.
- **Experiência principal:** cultivar, colher, transportar produtos em pilhas de até 7 caixas, abastecer uma bancada de venda sem cobertura, atender clientes do lado externo da cerca, recolher receitas e expandir a fazenda.
- **Arquitetura:** projeto modular, preparado para desenvolvimento assistido por agentes, revisão de código, testes e CI.
- **Distribuição web:** não é o objetivo principal desta reconstrução.

## Estado do repositório

Projeto em reconstrução em uma nova stack.

A versão anterior (código em HTML/JS, sprites em `assets/` e regras do jogo em `docs/`) foi removida desta branch, mas continua disponível no histórico do Git, no commit `1a85c87`.

Para recuperar um arquivo da versão anterior:

```bash
git checkout 1a85c87 -- caminho/do/arquivo
```
