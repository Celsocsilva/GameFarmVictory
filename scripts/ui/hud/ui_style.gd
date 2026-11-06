extends RefCounted
class_name UiStyle
## Estilo de texto compartilhado pelo HUD (UI-004). Todos os números e títulos
## da interface são desenhados pela engine com estes Labels: os PNGs de
## assets/ui são apenas fundos e ícones, sem números embutidos.

## Marrom escuro dos textos sobre o creme (como na referência visual).
const TEXT_BROWN := Color(0.33, 0.19, 0.09)
const TEXT_CREAM := Color(1.0, 0.97, 0.9)
const OUTLINE_BROWN := Color(0.36, 0.2, 0.08)
const OUTLINE_RED := Color(0.55, 0.08, 0.08)
const OUTLINE_GREEN := Color(0.12, 0.35, 0.04)

static var _font: Font

## Fonte arredondada e encorpada do sistema; MSDF para ficar nítida em qualquer
## escala (os componentes são desenhados no tamanho do PNG e reduzidos no HUD).
static func font() -> Font:
    if _font == null:
        var system_font := SystemFont.new()
        system_font.font_names = PackedStringArray(["Nunito", "Baloo 2", "Fredoka", "Arial Rounded MT Bold", "Segoe UI", "Roboto", "sans-serif"])
        system_font.font_weight = 800
        system_font.multichannel_signed_distance_field = true
        system_font.msdf_pixel_range = 16
        _font = system_font
    return _font

static func style_label(label: Label, font_size: int, color: Color = TEXT_BROWN, outline_color: Color = Color(0, 0, 0, 0), outline_size: int = 0) -> void:
    label.add_theme_font_override("font", font())
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    if outline_size > 0:
        label.add_theme_color_override("font_outline_color", outline_color)
        label.add_theme_constant_override("outline_size", outline_size)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Reduz a fonte até o texto caber na largura do Label (ex.: "9.999.999" no
## contador de dinheiro). Nunca aumenta acima de `max_size`.
static func fit_font(label: Label, max_size: int, min_size: int = 10) -> void:
    var available := label.size.x - 4.0
    if available <= 0.0:
        return
    var current_font := label.get_theme_font("font")
    var font_size := max_size
    while font_size > min_size and current_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
        font_size -= 1
    label.add_theme_font_size_override("font_size", font_size)

## Largura do texto no tamanho atual (para testes de truncamento).
static func text_width(label: Label) -> float:
    var font_size := label.get_theme_font_size("font_size")
    return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

## Coloca um Label (ou qualquer Control) num retângulo em pixels do PNG de fundo.
static func place(control: Control, rect: Rect2) -> void:
    control.position = rect.position
    control.size = rect.size

## Números inteiros com separador de milhar brasileiro: 1250 -> "1.250".
static func format_int(value: int) -> String:
    var negative := value < 0
    var digits := str(absi(value))
    var out := ""
    while digits.length() > 3:
        out = "." + digits.substr(digits.length() - 3) + out
        digits = digits.substr(0, digits.length() - 3)
    out = digits + out
    return ("-" if negative else "") + out

## "18/56" (contadores com limite).
static func format_ratio(value: int, maximum: int) -> String:
    return "%s/%s" % [format_int(value), format_int(maximum)]

## Pulso curto quando um valor muda.
static func pulse(control: Control, strength: float = 0.12) -> void:
    if not control.is_inside_tree():
        return
    control.pivot_offset = control.size * 0.5
    var tween := control.create_tween()
    tween.tween_property(control, "scale", Vector2.ONE * (1.0 + strength), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(control, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
