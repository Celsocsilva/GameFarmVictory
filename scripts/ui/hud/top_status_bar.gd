extends Control
class_name TopStatusBar
## Barra superior (hud_top_status_bar_bg.png): estrela de nível + dinheiro,
## tomates e caixas. Os ícones fazem parte do PNG; os valores são Labels.

const LEVEL_RECT := Rect2(34, 50, 120, 96)
const MONEY_RECT := Rect2(324, 74, 180, 66)
const TOMATO_RECT := Rect2(694, 74, 202, 66)
const CRATE_RECT := Rect2(1099, 75, 203, 65)

@onready var level_label: Label = $LevelLabel
@onready var money_label: Label = $MoneyLabel
@onready var tomato_label: Label = $TomatoLabel
@onready var crate_label: Label = $CrateLabel

func _ready() -> void:
    UiStyle.style_label(level_label, 64, UiStyle.TEXT_BROWN, Color(1.0, 0.93, 0.6), 6)
    UiStyle.place(level_label, LEVEL_RECT)
    for pair in [[money_label, MONEY_RECT], [tomato_label, TOMATO_RECT], [crate_label, CRATE_RECT]]:
        UiStyle.style_label(pair[0], 48)
        UiStyle.place(pair[0], pair[1])

func set_level(level: int) -> void:
    level_label.text = str(level)

func set_money(value: int) -> void:
    money_label.text = UiStyle.format_int(value)
    UiStyle.fit_font(money_label, 48)

func set_tomatoes(value: int, maximum: int) -> void:
    tomato_label.text = UiStyle.format_ratio(value, maximum)
    UiStyle.fit_font(tomato_label, 48)

func set_crates(value: int, maximum: int) -> void:
    crate_label.text = UiStyle.format_ratio(value, maximum)
    UiStyle.fit_font(crate_label, 48)
