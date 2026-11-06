extends RefCounted
class_name ProgressionConfig
## Ritmo de progressão (nível e missões) num lugar só.
##
## DIFFICULTY_MULTIPLIER multiplica o XP pedido por nível e as metas das
## missões. Com 6, subir de nível e concluir uma missão exige 6x mais que na
## primeira versão do HUD (pedido do Celso em 6/11/2026). Prêmios e XP ganhos
## não mudam, então o avanço fica 6x mais lento. Plantio, colheita, vendas e
## preços não são afetados.

const DIFFICULTY_MULTIPLIER := 6

## XP para sair do nível 1 e acréscimo por nível (antes do multiplicador).
const BASE_XP_PER_LEVEL := 40
const XP_STEP_PER_LEVEL := 20

## XP ganho por tomate vendido no balcão.
const XP_PER_TOMATO_SOLD := 1

## Metas das missões antes do multiplicador.
const BASE_TARGET_HARVEST_TOMATOES := 56
const BASE_TARGET_SELL_CRATES := 7
const BASE_TARGET_COLLECT_MONEY := 30

static func xp_for_level(level: int) -> int:
    return (BASE_XP_PER_LEVEL + XP_STEP_PER_LEVEL * (maxi(level, 1) - 1)) * DIFFICULTY_MULTIPLIER

static func mission_target(base_target: int) -> int:
    return base_target * DIFFICULTY_MULTIPLIER
