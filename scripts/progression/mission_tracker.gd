extends Node
class_name MissionTracker
## Missões em sequência (UI-004). Lê os estados que já existem no jogo, sem
## duplicá-los: colheita (HarvestInventory), vendas (SalesController) e dinheiro
## recolhido (Wallet). Ao concluir, espera o jogador coletar o prêmio
## (claim_reward), que entra na mesma Wallet com a origem &"mission".
## Depois da última missão a lista recomeça com metas e prêmios maiores.

signal mission_changed(mission: Dictionary)
signal progress_changed(progress: int, target: int)
signal mission_completed(mission: Dictionary)
signal reward_claimed(mission: Dictionary, amount: int)

enum Kind { HARVEST_TOMATOES, SELL_CRATES, COLLECT_MONEY }

const ICON_TOMATO := preload("res://assets/ui/icons/icon_tomato.png")
const ICON_CRATE := preload("res://assets/ui/icons/icon_crate_full.png")
const ICON_CASH := preload("res://assets/currency/cash_bundle_official.png")

## Missões base. Metas: ProgressionConfig.mission_target() (multiplicador de
## dificuldade) vezes (rodada + 1). Prêmios: valor base vezes (rodada + 1).
const MISSIONS := [
    {"id": &"harvest_tomatoes", "title": "Colher tomates", "kind": Kind.HARVEST_TOMATOES, "target": ProgressionConfig.BASE_TARGET_HARVEST_TOMATOES, "reward": 10, "xp": 10},
    {"id": &"sell_crates", "title": "Vender caixas", "kind": Kind.SELL_CRATES, "target": ProgressionConfig.BASE_TARGET_SELL_CRATES, "reward": 15, "xp": 15},
    {"id": &"collect_money", "title": "Recolher dinheiro", "kind": Kind.COLLECT_MONEY, "target": ProgressionConfig.BASE_TARGET_COLLECT_MONEY, "reward": 20, "xp": 20},
]

var index := 0
var round_number := 0
var progress := 0
var completed := false

var _inventory: HarvestInventory
var _wallet: Wallet
var _level: PlayerLevel
var _last_harvest_amount := 0
var _granting := false

func setup(inventory: HarvestInventory, sales: SalesController, wallet: Wallet, level: PlayerLevel = null) -> void:
    _inventory = inventory
    _wallet = wallet
    _level = level
    _last_harvest_amount = inventory.get_amount(HarvestInventory.DEFAULT_ITEM)
    inventory.amount_changed.connect(_on_harvest_amount_changed)
    sales.sale_completed.connect(_on_sale_completed)
    wallet.balance_changed.connect(_on_wallet_changed)
    mission_changed.emit(get_current())

func get_current() -> Dictionary:
    var base: Dictionary = MISSIONS[index]
    var mission := base.duplicate()
    mission["target"] = ProgressionConfig.mission_target(int(base["target"])) * (round_number + 1)
    mission["reward"] = int(base["reward"]) * (round_number + 1)
    mission["xp"] = int(base["xp"]) * (round_number + 1)
    mission["icon"] = icon_for(base["kind"])
    return mission

func get_target() -> int:
    return int(get_current()["target"])

static func icon_for(kind: int) -> Texture2D:
    match kind:
        Kind.HARVEST_TOMATOES:
            return ICON_TOMATO
        Kind.SELL_CRATES:
            return ICON_CRATE
        _:
            return ICON_CASH

## Soma progresso à missão atual se ela for do tipo `kind`.
func add_progress(kind: int, amount: int) -> void:
    if completed or amount <= 0 or int(MISSIONS[index]["kind"]) != kind:
        return
    var target := get_target()
    progress = mini(progress + amount, target)
    progress_changed.emit(progress, target)
    if progress >= target:
        completed = true
        mission_completed.emit(get_current())

## Entrega o prêmio da missão concluída e passa para a próxima.
func claim_reward() -> int:
    if not completed:
        return 0
    var mission := get_current()
    var reward := int(mission["reward"])
    _granting = true
    _wallet.add(reward, &"mission")
    _granting = false
    if _level:
        _level.add_xp(int(mission["xp"]))
    reward_claimed.emit(mission, reward)
    _advance()
    return reward

func _advance() -> void:
    completed = false
    progress = 0
    index += 1
    if index >= MISSIONS.size():
        index = 0
        round_number += 1
    mission_changed.emit(get_current())
    progress_changed.emit(progress, get_target())

func _on_harvest_amount_changed(item_id: StringName, amount: int) -> void:
    if item_id != HarvestInventory.DEFAULT_ITEM:
        return
    var gained := amount - _last_harvest_amount
    _last_harvest_amount = amount
    add_progress(Kind.HARVEST_TOMATOES, gained)

func _on_sale_completed(_customer: Customer, crates: int, _units: int, _money: int) -> void:
    add_progress(Kind.SELL_CRATES, crates)

func _on_wallet_changed(_balance: int, delta: int) -> void:
    if not _granting:
        add_progress(Kind.COLLECT_MONEY, delta)

func to_dict() -> Dictionary:
    return {"version": 1, "index": index, "round": round_number, "progress": progress, "completed": completed}

func from_dict(data: Dictionary) -> void:
    index = clampi(int(data.get("index", 0)), 0, MISSIONS.size() - 1)
    round_number = maxi(0, int(data.get("round", 0)))
    progress = clampi(int(data.get("progress", 0)), 0, get_target())
    completed = bool(data.get("completed", false)) and progress >= get_target()
    mission_changed.emit(get_current())
    progress_changed.emit(progress, get_target())
