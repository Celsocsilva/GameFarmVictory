extends Control
## Cena de inspeção UIAssetQA (prompt UI v5): cada PNG de runtime isolado numa
## célula, com o nome do arquivo num Label (não gravado na imagem) e fundo de
## contraste. `background_mode`: 0 = xadrez, 1 = branco, 2 = preto.
## `page`: 0 = os oito componentes corrigidos na v5 + estados dos CTAs,
## 1 = HUD e ícones, 2 = demais componentes e dinheiro oficial.
## Teclas: B troca o fundo, PageUp/PageDown trocam a página.

const FIXED_V5 := [
    "res://assets/ui/components/button_cta_green_large.png",
    "res://assets/ui/components/button_cta_orange_large.png",
    "res://assets/ui/components/button_cta_blue_large.png",
    "res://assets/ui/components/pill_small_cream.png",
    "res://assets/ui/components/pill_medium_cream.png",
    "res://assets/ui/components/panel_tabbed_small.png",
    "res://assets/ui/components/button_round_green.png",
    "res://assets/ui/components/panel_reward_popup.png",
]
const CTA_SCENE := preload("res://scenes/ui/hud/components/CtaButton.tscn")

@export_range(0, 2) var background_mode := 0
@export_range(0, 2) var page := 0

var _content: Control

func _ready() -> void:
    rebuild()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        match (event as InputEventKey).keycode:
            KEY_B:
                background_mode = (background_mode + 1) % 3
                rebuild()
            KEY_PAGEDOWN:
                page = (page + 1) % 3
                rebuild()
            KEY_PAGEUP:
                page = (page + 2) % 3
                rebuild()

static func runtime_pngs() -> Array[String]:
    var files: Array[String] = []
    for dir in ["res://assets/ui/hud", "res://assets/ui/icons", "res://assets/ui/components", "res://assets/currency"]:
        for file in DirAccess.get_files_at(dir):
            if file.ends_with(".png"):
                files.append(dir + "/" + file)
    return files

func get_page_files() -> Array[String]:
    var all := runtime_pngs()
    var files: Array[String] = []
    match page:
        0:
            for path in FIXED_V5:
                files.append(path)
        1:
            for path in all:
                if path.contains("/hud/") or path.contains("/icons/"):
                    files.append(path)
        _:
            for path in all:
                if (path.contains("/components/") or path.contains("/currency/")) and not FIXED_V5.has(path):
                    files.append(path)
    return files

func rebuild() -> void:
    if _content:
        _content.queue_free()
    _content = Control.new()
    _content.set_anchors_preset(Control.PRESET_FULL_RECT)
    _content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_content)
    var page_bg := ColorRect.new()
    page_bg.color = Color(0.93, 0.95, 0.9)
    page_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    _content.add_child(page_bg)
    var header := Label.new()
    header.text = "UIAssetQA — UI v5 — página %d/3 — fundo: %s   (B: fundo, PgUp/PgDn: página)" % [page + 1, ["xadrez", "branco", "preto"][background_mode]]
    header.position = Vector2(16, 6)
    header.add_theme_color_override("font_color", Color(0.1, 0.2, 0.1))
    _content.add_child(header)
    var files := get_page_files()
    var area := get_viewport_rect().size
    var columns := 4 if page == 0 else 6
    var cell := Vector2((area.x - 16.0) / columns, 0.0)
    var rows := int(ceil(float(files.size()) / columns))
    var reserved := 150.0 if page == 0 else 0.0
    cell.y = (area.y - 40.0 - reserved) / maxi(rows, 1)
    for i in files.size():
        var origin := Vector2(8.0 + (i % columns) * cell.x, 34.0 + (i / columns) * cell.y)
        _add_cell(files[i], Rect2(origin, cell - Vector2(8, 8)))
    if page == 0:
        _add_cta_states(Rect2(8, area.y - reserved, area.x - 16, reserved - 8))

func _add_cell(path: String, rect: Rect2) -> void:
    var frame := Control.new()
    frame.position = rect.position
    frame.size = rect.size
    frame.clip_contents = true
    _content.add_child(frame)
    _add_background(frame, Rect2(Vector2(0, 20), rect.size - Vector2(0, 20)))
    var name_label := Label.new()
    var texture := load(path) as Texture2D
    name_label.text = "%s  %dx%d" % [path.get_file(), texture.get_width(), texture.get_height()]
    name_label.add_theme_font_size_override("font_size", 13 if page == 0 else 10)
    name_label.add_theme_color_override("font_color", Color(0.1, 0.15, 0.1))
    frame.add_child(name_label)
    var image := TextureRect.new()
    image.name = "Image"
    image.texture = texture
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    image.position = Vector2(6, 26)
    image.size = rect.size - Vector2(12, 32)
    image.set_meta("asset_path", path)
    frame.add_child(image)
    # Contorno do PNG inteiro (inclui a margem transparente): o objeto tem de caber dentro.
    var outline := ReferenceRect.new()
    outline.border_color = Color(1.0, 0.0, 0.6)
    outline.editor_only = false
    var fit := minf(image.size.x / texture.get_width(), image.size.y / texture.get_height())
    var drawn := texture.get_size() * fit
    outline.position = image.position + (image.size - drawn) * 0.5
    outline.size = drawn
    outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(outline)

func _add_background(parent: Control, rect: Rect2) -> void:
    if background_mode == 0:
        var checker := ColorRect.new()
        checker.position = rect.position
        checker.size = rect.size
        var shader := Shader.new()
        shader.code = "shader_type canvas_item; void fragment(){ vec2 c = floor(FRAGCOORD.xy / 12.0); float k = mod(c.x + c.y, 2.0); COLOR = vec4(vec3(mix(0.78, 0.95, k)), 1.0); }"
        var material := ShaderMaterial.new()
        material.shader = shader
        checker.material = material
        parent.add_child(checker)
    else:
        var plain := ColorRect.new()
        plain.position = rect.position
        plain.size = rect.size
        plain.color = Color.WHITE if background_mode == 1 else Color.BLACK
        parent.add_child(plain)

## Os três CTAs v5 nos estados normal, hover, pressed, disabled e foco, com o
## texto do botão desenhado pela engine.
func _add_cta_states(rect: Rect2) -> void:
    var title := Label.new()
    title.text = "CTAs v5 (sem fator extra de largura): normal | hover | pressed | disabled | foco"
    title.position = rect.position
    title.add_theme_color_override("font_color", Color(0.1, 0.2, 0.1))
    _content.add_child(title)
    var states := ["normal", "hover", "pressed", "disabled", "normal+focus"]
    var colors := ["green", "orange", "blue"]
    var height := (rect.size.y - 24.0) / colors.size() - 6.0
    for row in colors.size():
        for col in states.size():
            var button := CTA_SCENE.instantiate() as CtaButton
            _content.add_child(button)
            button.color = colors[row]
            button.text = "Coletar"
            button.fit_height(height)
            button.position = Vector2(rect.position.x + col * rect.size.x / states.size(), rect.position.y + 24.0 + row * (height + 6.0))
            button.preview_state(states[col])
