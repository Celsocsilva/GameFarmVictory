extends TextureButton
class_name StoreButton
## Botão da loja (icon_store.png) com o rótulo "Loja" desenhado pela engine.

const LABEL_RECT := Rect2(32, 180, 218, 56)

@onready var caption: Label = $Caption

func _ready() -> void:
    UiStyle.style_label(caption, 44, UiStyle.TEXT_CREAM, UiStyle.OUTLINE_BROWN, 12)
    UiStyle.place(caption, LABEL_RECT)
    button_down.connect(_on_down)
    button_up.connect(_on_up)

func _on_down() -> void:
    modulate = Color(0.85, 0.85, 0.85)

func _on_up() -> void:
    modulate = Color.WHITE
