# Contratos de domínio

## Inventory

Entrada: item, quantidade e origem. Saída: quantidade efetivamente adicionada/removida. Invariantes: nunca estoque negativo; capacidade validada antes de mutar estado.

## Farming

Estados: EMPTY, PLANTED, GROWING, READY, HARVESTED. A cultura fornece duração e produto; animações não definem regras.

## Commerce

A bancada mantém estoques independentes por produto. Venda só consome estoque da bancada, nunca carga ainda transportada.

## Economy

Separa receita gerada, pagamento pendente e saldo disponível. Cada pagamento tem identificador e só pode ser creditado uma vez.

## Persistence

Payload versionado, escrita temporária seguida de substituição segura e migração explícita por versão.
