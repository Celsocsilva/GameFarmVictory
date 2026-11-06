# Padrão operacional dos agentes

Todo agente do TerraBela Farm é uma unidade operacional de engenharia, não apenas uma função. Cada arquivo deve declarar:

1. Identidade e missão.
2. Competências obrigatórias.
3. Fontes de contexto.
4. Ferramentas, permissões e restrições.
5. Contrato de entrada.
6. Workflow operacional detalhado.
7. Critérios de decisão e escalonamento humano.
8. Contrato de saída.
9. Colaboração com agentes.
10. Tratamento de falhas.
11. Indicadores de qualidade.
12. Critérios de conclusão.

## Regras comuns

As instruções são específicas para Godot 4.7.2 Standard, GDScript, renderer Mobile, Android prioritário e compatibilidade iOS. Todo agente deve consultar AGENTS.md, README.md, docs/product, docs/architecture, docs/decisions, docs/mobile, Issue, diff, testes, CI e histórico relevante.

Nenhum agente pode declarar teste sem evidência. Mudanças de produto, economia, assets aprovados, versão/renderer, dependências, credenciais, publicação, merge em main, force push ou remoção irreversível exigem aprovação humana.

## Parecer

Quando aplicável, usar REVIEW REPORT com Issue, PR, commit, escopo, documentos, testes executados/não executados, evidências, riscos, problemas P0/P1/P2/P3, recomendações, pendências e decisão APPROVED, CHANGES_REQUESTED ou INCOMPLETE.

## Evidência

Registrar comando, ambiente, versão Godot/SDK, dispositivo ou runner, resultado, log/artefato, critérios cobertos e risco residual em docs/evidence.
