extends Control
class_name RewardPopup
## Popup de recompensa (panel_reward_popup.png). Aceita título, mensagem, ícone
## e valor por código, com animação de entrada e saída. Recompensas em dinheiro
## usam o maço oficial (assets/currency/cash_bundle_official.png).
##
## O PNG do pacote traz, acima do presente, duas peças soltas (uma aba creme e um
## círculo verde). O arquivo não é alterado: a cena mostra só o cartão por uma
## AtlasTexture (região CARD_REGION), sem perder nenhuma parte do cartão.

signal collected(amount: int)

const CASH_ICON := preload("res://assets/currency/cash_bundle_official.png")
## Região do cartão dentro do PNG 543 x 669 (raios do presente até a borda de baixo).
const CARD_REGION := Rect2(0, 184, 543, 485)
const TITLE_RECT := Rect2(92, 170, 359, 72)
const MESSAGE_RECT := Rect2(40, 262, 463, 56)
const PLATE_RECT := Rect2(96, 322, 351, 76)
const VALUE_ICON_RECT := Rect2(118, 327, 104, 70)
const VALUE_RECT := Rect2(226, 322, 206, 76)
const BUTTON_RECT := Rect2(126, 400, 291, 98)
const IN_TIME := 0.32
const OUT_TIME := 0.2

@onready var dim: ColorRect = $Dim
@onready var card: Control = $Card
@onready var title_label: Label = $Card/TitleLabel
@onready var message_label: Label = $Card/MessageLabel
@onready var value_plate: TextureRect = $Card/ValuePlate
@onready var value_icon: TextureRect = $Card/ValueIcon
@onready var value_label: Label = $Card/ValueLabel
@onready var collect_button: TextureButton = $Card/CollectButton
@onready var button_label: Label = $Card/CollectButton/ButtonLabel

var amount := 0
var is_open := false
var _card_scale := 1.0
var _tween: Tween

func _ready() -> void:
    UiStyle.style_label(title_label, 54, Color.WHITE, UiStyle.OUTLINE_RED, 12)
    UiStyle.place(title_label, TITLE_RECT)
    UiStyle.style_label(message_label, 38)
    UiStyle.place(message_label, MESSAGE_RECT)
    UiStyle.place(value_plate, PLATE_RECT)
    UiStyle.place(value_icon, VALUE_ICON_RECT)
    UiStyle.style_label(value_label, 56)
    UiStyle.place(value_label, VALUE_RECT)
    UiStyle.place(collect_button, BUTTON_RECT)
    UiStyle.style_label(button_label, 46, Color.WHITE, UiStyle.OUTLINE_GREEN, 10)
    button_label.position = Vector2.ZERO
    button_label.size = BUTTON_RECT.size - Vector2(0, 8)
    collect_button.pressed.connect(collect)
    card.size = CARD_REGION.size
    card.pivot_offset = CARD_REGION.size * 0.5
    resized.connect(_layout)
    visible = false
    _layout()

## Centraliza o cartão e o reduz para caber na tela (retrato ou paisagem).
func _layout() -> void:
    var fit := minf(size.x * 0.9 / CARD_REGION.size.x, size.y * 0.75 / CARD_REGION.size.y)
    _card_scale = clampf(fit, 0.4, 1.35 if size.y > size.x else 1.0)
    card.position = (size - CARD_REGION.size) * 0.5
    if not (_tween and _tween.is_running()):
        card.scale = Vector2.ONE * _card_scale

func get_card_scale() -> float:
    return _card_scale

func show_reward(title: String, message: String, value: int, icon: Texture2D = CASH_ICON, button_text: String = "Coletar") -> void:
    amount = value
    title_label.text = title
    message_label.text = message
    value_icon.texture = icon
    value_label.text = UiStyle.format_int(value)
    button_label.text = button_text
    is_open = true
    visible = true
    _kill_tween()
    _layout()
    card.scale = Vector2.ONE * _card_scale * 0.55
    card.modulate.a = 0.0
    dim.modulate.a = 0.0
    _tween = create_tween().set_parallel(true)
    _tween.tween_property(card, "scale", Vector2.ONE * _card_scale, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween.tween_property(card, "modulate:a", 1.0, IN_TIME * 0.6)
    _tween.tween_property(dim, "modulate:a", 1.0, IN_TIME)

## Botão "Coletar": animação de saída e depois emite `collected`.
func collect() -> void:
    if not is_open:
        return
    is_open = false
    var value := amount
    _kill_tween()
    _tween = create_tween().set_parallel(true)
    _tween.tween_property(card, "scale", Vector2.ONE * _card_scale * 0.7, OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    _tween.tween_property(card, "modulate:a", 0.0, OUT_TIME)
    _tween.tween_property(dim, "modulate:a", 0.0, OUT_TIME)
    _tween.chain().tween_callback(_hide_after_exit)
    collected.emit(value)

func _hide_after_exit() -> void:
    if not is_open:
        visible = false

func _kill_tween() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
