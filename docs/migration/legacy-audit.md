# Auditoria do legado

O legado foi removido da árvore atual no commit 2b2db4c, mas permanece no histórico Git. Antes de migrar qualquer recurso, registrar origem, licença, estado visual, dependências e decisão.

Classificações: confirmado e preservado; legado sujeito a revisão; postergado; descartado com decisão explícita.

Recuperação controlada:

    git switch -c refactor/legacy-audit
    git checkout 1a85c87 -- caminho/do/arquivo

Não fazer force push nem substituir main durante a migração.
