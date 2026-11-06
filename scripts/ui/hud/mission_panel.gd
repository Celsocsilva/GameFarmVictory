extends Control
class_name MissionPanel
## Painel de missão (mission_panel_bg.png). Título, ícone, barra de progresso e
## prêmio são definidos por código: set_mission() e set_progress().
## A barra pintada no PNG fica coberta pela HudProgressBar (o progresso real).

const CASH_ICON := preload("res://assets/currency/cash_bundle_official.png")
const ICON_RECT := Rect2(62, 62, 130, 130)
const TITLE_RECT := Rect2(254, 52, 440, 60)
const BAR_RECT := Rect2(242, 131, 462, 57)
const REWARD_CAPTION_RECT := Rect2(234, 224, 170, 110)
const REWARD_ICON_RECT := Rect2(404, 236, 124, 84)
const REWARD_VALUE_RECT := Rect2(534, 224, 150, 110)

@onready var icon_rect: TextureRect = $Icon
@onready var title_label: Label = $TitleLabel
@onready var progress_bar: HudProgressBar = $ProgressBar
@onready var reward_caption: Label = $RewardCaption
@onready var reward_icon: TextureRect = $RewardIcon
@onready var reward_label: Label = $RewardLabel

func _ready() -> void:
    UiStyle.place(icon_rect, ICON_RECT)
    UiStyle.style_label(title_label, 40)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    UiStyle.place(title_label, TITLE_RECT)
    UiStyle.place(progress_bar, BAR_RECT)
    UiStyle.style_label(reward_caption, 36)
    reward_caption.text = "Prêmio"
    UiStyle.place(reward_caption, REWARD_CAPTION_RECT)
    reward_icon.texture = CASH_ICON
    UiStyle.place(reward_icon, REWARD_ICON_RECT)
    UiStyle.style_label(reward_label, 50)
    reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    UiStyle.place(reward_label, REWARD_VALUE_RECT)

func set_mission(title: String, icon: Texture2D, target: int, reward: int) -> void:
    title_label.text = title
    icon_rect.texture = icon
    reward_label.text = UiStyle.format_int(reward)
    UiStyle.fit_font(reward_label, 50)
    progress_bar.set_progress(0, target)

func set_progress(value: int, target: int) -> void:
    progress_bar.set_progress(value, target)

## Título + progresso de uma vez (API pedida no prompt UI v5).
func set_mission_progress(title: String, current: int, target: int) -> void:
    title_label.text = title
    progress_bar.set_progress(current, target)

func get_title() -> String:
    return title_label.text

func get_progress_text() -> String:
    return progress_bar.get_label_text()
