extends CanvasLayer
class_name FarmHUD
## HUD da fazenda (UI-004). Só exibe estados que já existem no jogo:
## - dinheiro: Wallet (saldo recolhido das pilhas da base de dinheiro);
## - tomates e caixas: HarvestInventory (mochila);
## - vendas: SalesController.sale_completed (aviso de venda);
## - nível e missão: PlayerLevel e MissionTracker.
## Todo número é um Label; os PNGs de assets/ui são só fundos e ícones.
## Os componentes são desenhados no tamanho dos PNGs e reduzidos por `scale`.
## O layout é refeito a cada mudança de tamanho (paisagem e retrato).

signal store_pressed()

const SALE_POPUP_SCENE := preload("res://scenes/ui/hud/components/SalePopup.tscn")
const MARGIN := 16.0
## Tamanho do SalePopup.tscn (field_input_wide.png v5).
const SALE_POPUP_SCENE_SIZE := Vector2(559, 139)
const GAP := 10.0
const LEVEL_SCALE := 0.42
const MISSION_SCALE := 0.46
const COUNTER_SCALE := 0.72
const BANNER_SCALE := 0.42
const STORE_SCALE := 0.42
const SALE_POPUP_SCALE := 0.5
## Em retrato (tela mais alta que larga) os componentes crescem para continuarem
## legíveis no celular em pé; os contadores encolhem se não couberem.
const PORTRAIT_BOOST := 1.35
const FULL_BACKPACK_MESSAGE := "Mochila cheia! Leve as caixas ao Balcão de vendas."

@onready var root_control: Control = $Root
@onready var level_panel: PlayerLevelPanel = $Root/PlayerLevelPanel
@onready var mission_panel: MissionPanel = $Root/MissionPanel
@onready var money_counter: HudCounter = $Root/Counters/MoneyCounter
@onready var tomato_counter: HudCounter = $Root/Counters/TomatoCounter
@onready var crate_counter: HudCounter = $Root/Counters/CrateCounter
@onready var counters: Control = $Root/Counters
@onready var info_banner: InfoBanner = $Root/InfoBanner
@onready var store_button: StoreButton = $Root/StoreButton
@onready var sale_popups: Control = $Root/SalePopups
@onready var reward_popup: RewardPopup = $Root/RewardPopup

var wallet: Wallet
var inventory: HarvestInventory
var player_level: PlayerLevel
var missions: MissionTracker
var _banner_timer: SceneTreeTimer
var _ui_scale := 1.0

func _ready() -> void:
    root_control.resized.connect(layout)
    store_button.pressed.connect(_on_store_pressed)
    reward_popup.collected.connect(_on_reward_collected)
    layout()

func setup(p_wallet: Wallet, p_inventory: HarvestInventory, sales: SalesController, level: PlayerLevel, tracker: MissionTracker) -> void:
    wallet = p_wallet
    inventory = p_inventory
    player_level = level
    missions = tracker
    wallet.balance_changed.connect(_on_balance_changed)
    inventory.amount_changed.connect(_on_inventory_changed)
    sales.sale_completed.connect(_on_sale_completed)
    level.changed.connect(_on_level_changed)
    tracker.mission_changed.connect(_on_mission_changed)
    tracker.progress_changed.connect(_on_mission_progress)
    tracker.mission_completed.connect(_on_mission_completed)
    refresh()

## Relê todos os estados (início de jogo ou depois de carregar um save).
func refresh() -> void:
    if wallet:
        money_counter.set_value(wallet.get_balance(), false)
    if inventory:
        _update_inventory(false)
    if player_level:
        level_panel.set_level(player_level.level, player_level.xp, player_level.xp_to_next())
    if missions:
        _on_mission_changed(missions.get_current())
        mission_panel.set_progress(missions.progress, missions.get_target())

## API direta (prompt UI v5). No jogo os valores chegam pelos sinais de Wallet
## e HarvestInventory; estes métodos servem para preview e testes.
func set_money(value: int) -> void:
    money_counter.set_value(value)

func set_tomatoes(current: int, maximum: int) -> void:
    tomato_counter.set_ratio(current, maximum)

func set_crates(current: int, maximum: int) -> void:
    crate_counter.set_ratio(current, maximum)

func set_mission(title: String, current: int, target: int) -> void:
    mission_panel.set_mission_progress(title, current, target)

func get_money_text() -> String:
    return money_counter.get_value_text()

func get_tomato_text() -> String:
    return tomato_counter.get_value_text()

func get_crate_text() -> String:
    return crate_counter.get_value_text()

func get_banner_message() -> String:
    return info_banner.get_message()

func get_active_sale_popups() -> Array[SalePopup]:
    var popups: Array[SalePopup] = []
    for child in sale_popups.get_children():
        if child is SalePopup and not child.is_queued_for_deletion():
            popups.append(child)
    return popups

## Layout responsivo: nível e missão à esquerda, contadores à direita, loja no
## canto inferior direito; o joystick (adicionado pelo FarmWorld) fica embaixo
## à esquerda. Os contadores encolhem se a largura não couber.
func layout() -> void:
    if is_node_ready():
        layout_for(root_control.size)

## Posiciona os componentes para uma área lógica (também usado nos testes).
func layout_for(area: Vector2) -> void:
    _ui_scale = PORTRAIT_BOOST if area.y > area.x else 1.0
    var k := _ui_scale
    level_panel.scale = Vector2.ONE * LEVEL_SCALE * k
    level_panel.position = Vector2(MARGIN, MARGIN)
    var level_size := level_panel.size * LEVEL_SCALE * k
    mission_panel.scale = Vector2.ONE * MISSION_SCALE * k
    mission_panel.position = Vector2(MARGIN, MARGIN + level_size.y + GAP)

    var row: Array[HudCounter] = [money_counter, tomato_counter, crate_counter]
    var row_width := 0.0
    for counter in row:
        row_width += counter.size.x
    row_width += GAP / (COUNTER_SCALE * k) * (row.size() - 1)
    var available := area.x - (MARGIN + level_size.x + GAP * 2.0) - MARGIN
    var counter_scale := minf(COUNTER_SCALE * k, available / row_width)
    var x := area.x - MARGIN - row_width * counter_scale
    counters.position = Vector2.ZERO
    for counter in row:
        counter.scale = Vector2.ONE * counter_scale
        counter.position = Vector2(x, MARGIN + (level_size.y - counter.size.y * counter_scale) * 0.5)
        x += counter.size.x * counter_scale + GAP
    var counters_bottom := money_counter.position.y + money_counter.size.y * counter_scale

    info_banner.scale = Vector2.ONE * BANNER_SCALE * k
    var banner_size := info_banner.size * BANNER_SCALE * k
    var banner_left := MARGIN + mission_panel.size.x * MISSION_SCALE * k + GAP
    if k > 1.0:
        # Retrato: faixa embaixo do painel de missão, à esquerda (há espaço vertical).
        info_banner.position = Vector2(MARGIN, mission_panel.position.y + mission_panel.size.y * MISSION_SCALE * k + GAP)
    else:
        var banner_x := clampf((area.x - banner_size.x) * 0.5, banner_left, maxf(banner_left, area.x - MARGIN - banner_size.x))
        info_banner.position = Vector2(banner_x, counters_bottom + GAP)

    store_button.scale = Vector2.ONE * STORE_SCALE * k
    var store_size := store_button.size * STORE_SCALE * k
    store_button.position = area - store_size - Vector2(MARGIN, MARGIN)

    # Avisos de venda alinhados à direita, embaixo dos contadores, fora da faixa.
    var popup_width := SALE_POPUP_SCENE_SIZE.x * SALE_POPUP_SCALE * k
    sale_popups.position = Vector2(area.x - MARGIN - popup_width, counters_bottom + GAP)

func _on_balance_changed(balance: int, _delta: int) -> void:
    money_counter.set_value(balance)

func _on_inventory_changed(_item: StringName, _amount: int) -> void:
    _update_inventory(true)

func _update_inventory(animate: bool) -> void:
    tomato_counter.set_ratio(inventory.get_total(), inventory.get_capacity(), animate)
    crate_counter.set_ratio(inventory.get_crate_count(), inventory.max_crates, animate)
    if inventory.is_full():
        info_banner.show_message(FULL_BACKPACK_MESSAGE)
    elif info_banner.message_label.text == FULL_BACKPACK_MESSAGE:
        info_banner.hide_message()

## Aviso de venda abaixo do contador de dinheiro; vários avisos se empilham.
func _on_sale_completed(_customer: Customer, crates: int, _units: int, money: int) -> void:
    show_sale_popup(money, crates)

func show_sale_popup(money: int, crates: int) -> SalePopup:
    var popup := SALE_POPUP_SCENE.instantiate() as SalePopup
    sale_popups.add_child(popup)
    popup.setup(money, crates)
    var stacked := get_active_sale_popups().size() - 1
    var popup_scale := SALE_POPUP_SCALE * _ui_scale
    # play() escala em torno do centro: compensa para a borda visível começar em (0, y).
    popup.position = Vector2(0.0, stacked * popup.size.y * popup_scale * 1.05) - popup.size * (1.0 - popup_scale) * 0.5
    popup.play(popup_scale)
    return popup

func _on_level_changed(level: int, xp: int, xp_to_next: int) -> void:
    level_panel.set_level(level, xp, xp_to_next)
    UiStyle.pulse(level_panel.level_label, 0.25)

func _on_mission_changed(mission: Dictionary) -> void:
    mission_panel.set_mission(String(mission["title"]), mission["icon"], int(mission["target"]), int(mission["reward"]))

func _on_mission_progress(progress: int, target: int) -> void:
    mission_panel.set_progress(progress, target)

func _on_mission_completed(mission: Dictionary) -> void:
    reward_popup.show_reward("Recompensa!", "Missão concluída!", int(mission["reward"]))

func _on_reward_collected(_amount: int) -> void:
    if missions:
        missions.claim_reward()

func _on_store_pressed() -> void:
    store_pressed.emit()
    show_banner("Loja em breve!", 1.6)

## Mensagem temporária na faixa floral.
func show_banner(text: String, seconds: float) -> void:
    info_banner.show_message(text)
    _banner_timer = get_tree().create_timer(seconds)
    var timer := _banner_timer
    timer.timeout.connect(func() -> void:
        if _banner_timer == timer and info_banner.message_label.text == text:
            info_banner.hide_message()
            if inventory and inventory.is_full():
                info_banner.show_message(FULL_BACKPACK_MESSAGE))
