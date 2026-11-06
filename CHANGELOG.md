# Changelog

## Unreleased

- Criada a fundação Godot mobile, documentação arquitetural e estrutura de agentes.
- Adicionada validação inicial de arquivos e workflows condicionados para Android/iOS.
- FV-HARVEST-001: colheita automática de tomates maduros com sucção até a mochila e pilha dinâmica de até 7 caixas (8 tomates cada), com reservas transacionais, cancelamento e save.
- FV-SALES-001: bancada de descarga renomeada para Balcão de vendas, com largura dobrada (8,5 m), colisão e cercas laterais; clientes compram 1-3 caixas sorteadas a 3 dinheiros por caixa; dinheiro empilhado numa base 3 x 5 ao lado do balcão e saldo no HUD.
- UI-004: HUD da fazenda com os PNGs individuais do pacote UI v4 (contadores de dinheiro, tomates e caixas, painel de nível, missão, popup de recompensa, aviso de venda, botão da loja e faixa de mensagens); todos os números são Labels da engine, o dinheiro usa o maço oficial e os estados vêm da Wallet, da mochila e das vendas.
- UI v5: PNGs da v5 no lugar da v4 (margem transparente, CTAs 30% mais largos, popup de recompensa isolado), componente CtaButton com estados, cena UIAssetQA, auditoria tools/ui_asset_audit.gd e textos que se ajustam até 9.999.999.
