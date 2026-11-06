extends Control
class_name InfoBanner
## Faixa de mensagens (floral_info_panel_bg.png), por exemplo "Mochila cheia!".

const TEXT_RECT := Rect2(162, 60, 771, 154)

@onready var message_label: Label = $MessageLabel

func _ready() -> void:
    UiStyle.style_label(message_label, 46, UiStyle.TEXT_CREAM, UiStyle.OUTLINE_GREEN, 10)
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    UiStyle.place(message_label, TEXT_RECT)
    visible = false

func show_message(text: String) -> void:
    message_label.text = text
    if not visible:
        visible = true
        modulate.a = 0.0
        create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

func hide_message() -> void:
    visible = false

func get_message() -> String:
    return message_label.text if visible else ""
