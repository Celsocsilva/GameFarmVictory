extends TextureButton
class_name StoreButton
## Botão da loja (icon_store_shop.png: packs, aceleradores e recursos especiais).
## O nome da loja é um Label da engine na faixa laranja de baixo, traduzido
## pelo sistema de localização da Godot (chave STORE_LABEL em
## localization/ui.csv: Loja / Tienda / Shop). A imagem não tem texto.
##
## O PNG tem 1536 x 1024 com margem transparente larga nas laterais; a cena
## exibe a região Rect2(180, 0, 1172, 1024) por AtlasTexture (fora dela só há
## pixels transparentes), o que mantém o tamanho funcional do botão anterior
## (282 x 245 no espaço de desenho, proporção quase igual).

const TEXT_KEY := "STORE_LABEL"
## Faixa laranja, em pixels do botão (282 x 245).
const LABEL_RECT := Rect2(18, 175, 246, 52)
const LABEL_MAX_FONT := 40

@onready var caption: Label = $Caption

func _ready() -> void:
    UiStyle.style_label(caption, LABEL_MAX_FONT, UiStyle.TEXT_CREAM, UiStyle.OUTLINE_BROWN, 10)
    UiStyle.place(caption, LABEL_RECT)
    caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
    caption.text = TEXT_KEY
    _fit_caption()
    button_down.connect(_on_down)
    button_up.connect(_on_up)

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _fit_caption.call_deferred()

## Texto exibido no idioma atual ("Loja", "Tienda" ou "Shop").
func get_display_text() -> String:
    return caption.atr(caption.text)

## Ajusta a fonte ao texto traduzido para caber na faixa.
func _fit_caption() -> void:
    var shown := get_display_text()
    var font := caption.get_theme_font("font")
    var font_size := LABEL_MAX_FONT
    while font_size > 12 and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > LABEL_RECT.size.x - 6.0:
        font_size -= 1
    caption.add_theme_font_size_override("font_size", font_size)

func _on_down() -> void:
    modulate = Color(0.85, 0.85, 0.85)

func _on_up() -> void:
    modulate = Color.WHITE
