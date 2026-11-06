extends Control
class_name HudCounter
## Contador do HUD (dinheiro, tomates, caixas, água, moedas). O PNG de fundo já
## traz o ícone; o valor é um Label desenhado pela engine na área creme.
## O componente é desenhado no tamanho do PNG; o HUD o reduz com `scale`.

@export var background: Texture2D:
    set(value):
        background = value
        _apply()
## Área creme do PNG (em pixels do PNG) onde o valor é desenhado.
@export var value_rect := Rect2(130, 42, 118, 52):
    set(value):
        value_rect = value
        _apply()
@export var font_size := 40:
    set(value):
        font_size = value
        _apply()
@export var placeholder_text := "0"

## Emitido uma vez por mudança de texto (testes de atualização única).
signal value_changed(text: String)
var update_count := 0

@onready var _background: TextureRect = $Background
@onready var _value_label: Label = $ValueLabel

func _ready() -> void:
    _apply()
    if _value_label.text.is_empty():
        _value_label.text = placeholder_text

func _apply() -> void:
    if not is_node_ready():
        return
    if background:
        _background.texture = background
        custom_minimum_size = background.get_size()
        size = background.get_size()
    UiStyle.style_label(_value_label, font_size)
    UiStyle.place(_value_label, value_rect)

## Valor simples: 1250 -> "1.250".
func set_value(value: int, animate: bool = true) -> void:
    _set_text(UiStyle.format_int(value), animate)

## Valor com limite: 18, 56 -> "18/56".
func set_ratio(value: int, maximum: int, animate: bool = true) -> void:
    _set_text(UiStyle.format_ratio(value, maximum), animate)

func get_value_text() -> String:
    return _value_label.text

func get_value_label() -> Label:
    return _value_label

func _set_text(text: String, animate: bool) -> void:
    if _value_label.text == text:
        return
    _value_label.text = text
    UiStyle.fit_font(_value_label, font_size)
    update_count += 1
    value_changed.emit(text)
    if animate:
        UiStyle.pulse(_value_label)
