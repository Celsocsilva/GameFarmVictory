extends Control
class_name HudProgressBar
## Barra de progresso do HUD: trilho marrom (StyleBox) + preenchimento com o PNG
## bar_progress_fill_green/blue em nine-patch + texto "18/56" desenhado pela engine.

const FILL_GREEN := preload("res://assets/ui/components/bar_progress_fill_green.png")
const FILL_BLUE := preload("res://assets/ui/components/bar_progress_fill_blue.png")
const FILL_PAD := 12.0

@export var use_blue := false
@export var label_font_size := 32
@export var track_color := Color("9a6744")
@export var track_border_color := Color("6b3f22")

var _track: Panel
var _track_style: StyleBoxFlat
var _fill: TextureProgressBar
var _label: Label
var _value := 0
var _maximum := 1

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _track = Panel.new()
    _track.name = "Track"
    _track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _track_style = StyleBoxFlat.new()
    _track_style.bg_color = track_color
    _track_style.border_color = track_border_color
    _track_style.set_border_width_all(3)
    _track.add_theme_stylebox_override("panel", _track_style)
    add_child(_track)
    _fill = TextureProgressBar.new()
    _fill.name = "Fill"
    _fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Os PNGs v5 têm 12 px de margem transparente de segurança; a barra usa só a
    # área visível (AtlasTexture), sem alterar o arquivo, para o preenchimento
    # ocupar a altura do trilho.
    var source: Texture2D = FILL_BLUE if use_blue else FILL_GREEN
    var visible_fill := AtlasTexture.new()
    visible_fill.atlas = source
    visible_fill.region = Rect2(Vector2(FILL_PAD, FILL_PAD), source.get_size() - Vector2(FILL_PAD, FILL_PAD) * 2.0)
    _fill.texture_progress = visible_fill
    _fill.nine_patch_stretch = true
    # Margens = metade da altura do PNG (cápsula), para as pontas não esticarem.
    var margin := int(_fill.texture_progress.get_height() * 0.5)
    _fill.stretch_margin_left = margin
    _fill.stretch_margin_right = margin
    _fill.stretch_margin_top = 0
    _fill.stretch_margin_bottom = 0
    _fill.min_value = 0.0
    _fill.step = 0.0
    add_child(_fill)
    _label = Label.new()
    _label.name = "ProgressLabel"
    UiStyle.style_label(_label, label_font_size, UiStyle.TEXT_CREAM, UiStyle.OUTLINE_BROWN, 8)
    add_child(_label)
    resized.connect(_layout)
    _layout()
    _refresh()

func _layout() -> void:
    if _track == null:
        return
    _track.position = Vector2.ZERO
    _track.size = size
    _track_style.set_corner_radius_all(int(size.y * 0.5))
    var inset := 3.0
    _fill.position = Vector2(inset, inset)
    _fill.size = size - Vector2(inset, inset) * 2.0
    _label.position = Vector2.ZERO
    _label.size = size
    _refresh()

func set_progress(value: int, maximum: int) -> void:
    _value = maxi(value, 0)
    _maximum = maxi(maximum, 1)
    _refresh()

func get_ratio() -> float:
    return clampf(float(_value) / float(_maximum), 0.0, 1.0)

func get_label_text() -> String:
    return _label.text if _label else ""

func _refresh() -> void:
    if _fill == null:
        return
    _fill.max_value = 1.0
    _fill.value = get_ratio()
    # Abaixo das pontas arredondadas o nine-patch ficaria deformado: esconde.
    _fill.visible = _fill.size.x * get_ratio() >= _fill.size.y * 0.9
    _label.text = UiStyle.format_ratio(mini(_value, _maximum), _maximum)
    UiStyle.fit_font(_label, label_font_size)
