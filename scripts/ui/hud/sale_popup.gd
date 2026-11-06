extends Control
class_name SalePopup
## Aviso rápido de venda no balcão (field_input_wide.png + maço oficial):
## "+6  2 caixas". Não bloqueia o jogo: entra com um pulo, sobe e some sozinho.

const CASH_ICON := preload("res://assets/currency/cash_bundle_official.png")
const ICON_RECT := Rect2(34, 24, 136, 92)
const AMOUNT_RECT := Rect2(172, 20, 190, 99)
const DETAIL_RECT := Rect2(357, 20, 172, 99)
const MONEY_GREEN := Color(0.2, 0.48, 0.05)
## Tempo total na tela.
@export var lifetime := 1.8
@export var rise := 46.0

@onready var icon_rect: TextureRect = $Icon
@onready var amount_label: Label = $AmountLabel
@onready var detail_label: Label = $DetailLabel

func _ready() -> void:
    icon_rect.texture = CASH_ICON
    UiStyle.place(icon_rect, ICON_RECT)
    UiStyle.style_label(amount_label, 58, MONEY_GREEN)
    UiStyle.place(amount_label, AMOUNT_RECT)
    UiStyle.style_label(detail_label, 34)
    UiStyle.place(detail_label, DETAIL_RECT)

func setup(money: int, crates: int) -> void:
    amount_label.text = "+" + UiStyle.format_int(money)
    UiStyle.fit_font(amount_label, 58)
    detail_label.text = "%d %s" % [crates, "caixa" if crates == 1 else "caixas"]

func get_text() -> String:
    return "%s %s" % [amount_label.text, detail_label.text]

## Entrada com "pop", subida suave e saída por transparência; libera o nó no fim.
func play(base_scale: float) -> void:
    pivot_offset = size * 0.5
    scale = Vector2.ONE * base_scale * 0.5
    modulate.a = 0.0
    var tween := create_tween().set_parallel(true)
    tween.tween_property(self, "scale", Vector2.ONE * base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.15)
    tween.tween_property(self, "position:y", position.y - rise, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    var fade := create_tween()
    fade.tween_interval(lifetime - 0.4)
    fade.tween_property(self, "modulate:a", 0.0, 0.4)
    fade.tween_callback(queue_free)
