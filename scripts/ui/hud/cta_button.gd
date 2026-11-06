extends TextureButton
class_name CtaButton
## Botão CTA (button_cta_green/orange/blue_large.png, v5). Os PNGs da v5 já vêm
## 30% mais largos: o botão só mantém a proporção do PNG (keep aspect), sem
## nenhum fator extra. O texto é um Label da engine.
## Estados: normal, hover, pressed, disabled e foco (anel amarelo, teclado/controle).

const TEXTURES := {
    "green": preload("res://assets/ui/components/button_cta_green_large.png"),
    "orange": preload("res://assets/ui/components/button_cta_orange_large.png"),
    "blue": preload("res://assets/ui/components/button_cta_blue_large.png"),
}
const OUTLINES := {
    "green": Color(0.12, 0.35, 0.04),
    "orange": Color(0.55, 0.22, 0.0),
    "blue": Color(0.03, 0.2, 0.45),
}
const HOVER_TINT := Color(1.22, 1.22, 1.18)
const HOVER_SCALE := 1.03
const PRESSED_TINT := Color(0.82, 0.82, 0.82)
const DISABLED_TINT := Color(0.6, 0.6, 0.6, 0.85)
const PRESSED_SCALE := 0.95
## Margem transparente de segurança dos PNGs CTA da v5 (10 px em 191 px de altura).
const SAFE_PAD_RATIO := 10.0 / 191.0

@export_enum("green", "orange", "blue") var color: String = "green":
    set(value):
        color = value
        _apply_style()
@export var text: String = "OK":
    set(value):
        text = value
        if is_node_ready():
            caption.text = value
            UiStyle.fit_font(caption, _caption_size())

@onready var caption: Label = $Caption
@onready var focus_ring: Panel = $FocusRing

var _ring_style := StyleBoxFlat.new()
var _hovered := false
var _pressed_down := false
var _forced_state := ""

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    ignore_texture_size = true
    stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    _ring_style.bg_color = Color(0, 0, 0, 0)
    _ring_style.border_color = Color(1.0, 0.86, 0.2)
    _ring_style.set_border_width_all(4)
    focus_ring.add_theme_stylebox_override("panel", _ring_style)
    focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_ring.set_anchors_preset(Control.PRESET_TOP_LEFT)
    caption.text = text
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    button_down.connect(_on_button_down)
    button_up.connect(_on_button_up)
    focus_entered.connect(_refresh_state)
    focus_exited.connect(_refresh_state)
    resized.connect(_layout)
    _apply_style()
    _layout()

func _apply_style() -> void:
    if not is_node_ready():
        return
    texture_normal = TEXTURES.get(color, TEXTURES["green"])
    UiStyle.style_label(caption, _caption_size(), Color.WHITE, OUTLINES.get(color, OUTLINES["green"]), maxi(2, int(size.y * 0.1)))
    caption.text = text
    UiStyle.fit_font(caption, _caption_size())

func _caption_size() -> int:
    return maxi(12, int(size.y * 0.46))

func _layout() -> void:
    pivot_offset = size * 0.5
    var pad := size.y * SAFE_PAD_RATIO
    focus_ring.position = Vector2(pad, pad) - Vector2(3, 3)
    focus_ring.size = size - Vector2(pad, pad) * 2.0 + Vector2(6, 6)
    _ring_style.set_corner_radius_all(int(focus_ring.size.y * 0.5))
    caption.position = Vector2(pad * 2.0, 0.0)
    caption.size = Vector2(size.x - pad * 4.0, size.y - pad * 2.0)
    caption.position.y = pad * 0.5
    _apply_style()

## Ajusta a largura à proporção do PNG para uma altura (mesma escala em X e Y:
## nenhum fator extra de largura).
func fit_height(height: float) -> void:
    var tex := texture_normal
    var target := Vector2(height * float(tex.get_width()) / float(tex.get_height()), height)
    custom_minimum_size = target
    size = target

func set_enabled(value: bool) -> void:
    disabled = not value
    if not value:
        _pressed_down = false
    focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
    if not value and has_focus():
        release_focus()
    _refresh_state()

## Estado visual atual: "normal", "hover", "pressed", "disabled" (+ "+focus").
## Vem dos sinais reais do botão (mouse_entered/exited, button_down/up, foco).
func get_state_name() -> String:
    if not _forced_state.is_empty():
        return _forced_state
    var state := "normal"
    if disabled:
        state = "disabled"
    elif _pressed_down:
        state = "pressed"
    elif _hovered:
        state = "hover"
    if has_focus() and not disabled:
        state += "+focus"
    return state

## Só para a cena de QA: mostra um estado fixo ("" volta ao normal).
func preview_state(state: String) -> void:
    _forced_state = state
    _refresh_state()

func _on_mouse_entered() -> void:
    _hovered = true
    _refresh_state()

func _on_mouse_exited() -> void:
    _hovered = false
    _pressed_down = false
    _refresh_state()

func _on_button_down() -> void:
    _pressed_down = true
    _refresh_state()

func _on_button_up() -> void:
    _pressed_down = false
    _refresh_state()

func _refresh_state() -> void:
    var state := get_state_name()
    if state.begins_with("disabled"):
        self_modulate = DISABLED_TINT
        caption.modulate = Color(0.85, 0.85, 0.85)
        scale = Vector2.ONE
    elif state.begins_with("pressed"):
        self_modulate = PRESSED_TINT
        caption.modulate = Color(0.92, 0.92, 0.92)
        scale = Vector2.ONE * PRESSED_SCALE
    elif state.begins_with("hover"):
        self_modulate = HOVER_TINT
        caption.modulate = Color.WHITE
        scale = Vector2.ONE * HOVER_SCALE
    else:
        self_modulate = Color.WHITE
        caption.modulate = Color.WHITE
        scale = Vector2.ONE
    focus_ring.visible = state.ends_with("+focus")
