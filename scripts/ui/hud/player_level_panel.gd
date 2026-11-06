extends Control
class_name PlayerLevelPanel
## Painel do fazendeiro (player_level_panel_bg.png): nível na estrela, título e
## barra de experiência, tudo desenhado pela engine.

const LEVEL_RECT := Rect2(220, 172, 86, 76)
const TITLE_RECT := Rect2(312, 102, 282, 58)
const XP_RECT := Rect2(324, 164, 262, 46)

@onready var level_label: Label = $LevelLabel
@onready var title_label: Label = $TitleLabel
@onready var xp_bar: HudProgressBar = $XpBar

func _ready() -> void:
    UiStyle.style_label(level_label, 46, UiStyle.TEXT_BROWN, Color(1.0, 0.93, 0.6), 5)
    UiStyle.place(level_label, LEVEL_RECT)
    UiStyle.style_label(title_label, 42)
    UiStyle.place(title_label, TITLE_RECT)
    UiStyle.place(xp_bar, XP_RECT)

func set_level(level: int, xp: int, xp_to_next: int) -> void:
    level_label.text = str(level)
    title_label.text = "Nível %d" % level
    xp_bar.set_progress(xp, xp_to_next)
