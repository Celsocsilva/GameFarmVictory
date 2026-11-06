extends Node3D
class_name CropPlant

signal stage_changed(cell_id: String, stage: String)
signal ready_for_harvest(cell_id: String)

@export var cell_id: String = ""
@export var accelerated_test_mode: bool = true
@export var growth_duration: float = 30.0
@export var cell_width: float = 1.15
## Largura máxima visível da planta em relação à célula. Acima de 1.0 a copa
## invade levemente a célula vizinha, como em jogos de fazenda cozy.
@export_range(0.8, 1.6, 0.05) var max_width_fraction: float = 1.15
## Altura máxima visível (unidades do mundo) de cada estágio, na ordem de STAGES.
@export var stage_heights: PackedFloat32Array = PackedFloat32Array([0.8, 1.3, 1.4, 1.55, 1.7])
@export_range(0.0, 0.5, 0.01) var stage_pop_duration: float = 0.28

const STAGES := ["SPROUT", "GROWING", "FLOWERING", "GREEN_FRUIT", "READY_TO_HARVEST"]
const STAGE_ASSETS := [
    "res://assets/crops/tomato/stages/01_sprout.png",
    "res://assets/crops/tomato/stages/02_vegetative_growth.png",
    "res://assets/crops/tomato/stages/03_flowering_fruit_set.png",
    "res://assets/crops/tomato/stages/04_green_fruit.png",
    "res://assets/crops/tomato/stages/05_ready_to_harvest.png"
]
# Mesmo limiar do recorte de alfa: remove o halo semitransparente de alguns PNGs
# (ex.: 04_green_fruit) e permite escrita de profundidade entre plantas vizinhas.
const ALPHA_CUTOFF := 0.5
const ALPHA_THRESHOLD := int(ALPHA_CUTOFF * 255.0)

# Retângulo opaco de cada PNG, calculado uma vez por textura e compartilhado.
static var _visible_rect_cache: Dictionary = {}

var stage_index := -1
var planted_at := 0.0
var sprite: Sprite3D
var _pop_tween: Tween

func initialize(new_cell_id: String, timestamp: float) -> void:
    cell_id = new_cell_id
    planted_at = timestamp
    sprite = Sprite3D.new()
    sprite.name = "TomatoPlantSprite"
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.shaded = false
    sprite.double_sided = true
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    sprite.alpha_scissor_threshold = ALPHA_CUTOFF
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    # A base visível fica na origem do nó, sobre o sulco.
    sprite.centered = false
    sprite.region_enabled = true
    add_child(sprite)
    _update_stage(0)

func _process(_delta: float) -> void:
    if planted_at <= 0.0:
        return
    var elapsed := Time.get_ticks_msec() / 1000.0 - planted_at
    var duration := growth_duration if accelerated_test_mode else growth_duration * 10.0
    var next_index := mini(STAGES.size() - 1, int((elapsed / duration) * STAGES.size()))
    if next_index != stage_index:
        _update_stage(next_index)

## Tamanho visível da planta no mundo (largura, altura) no estágio atual.
func get_visible_world_size() -> Vector2:
    if sprite == null or sprite.texture == null:
        return Vector2.ZERO
    return sprite.region_rect.size * sprite.pixel_size

func _update_stage(new_index: int) -> void:
    var previous_index := stage_index
    stage_index = clampi(new_index, 0, STAGES.size() - 1)
    var texture := load(STAGE_ASSETS[stage_index]) as Texture2D
    var region := _visible_rect(STAGE_ASSETS[stage_index], texture)
    sprite.texture = texture
    sprite.region_rect = region
    # Escala pelo conteúdo opaco (não pelo PNG inteiro com margens), limitada
    # pela altura do estágio e pela largura da célula.
    var target_height := stage_heights[mini(stage_index, stage_heights.size() - 1)]
    var target_width := cell_width * max_width_fraction
    sprite.pixel_size = minf(target_height / region.size.y, target_width / region.size.x)
    # Com centered = false o Sprite3D cresce para cima a partir do canto inferior
    # esquerdo; desloca metade da largura para centralizar no sulco.
    sprite.offset = Vector2(-region.size.x * 0.5, 0.0)
    sprite.position = Vector3(0.0, 0.02, 0.0)
    if stage_pop_duration > 0.0 and is_inside_tree():
        _play_stage_pop(0.0 if previous_index < 0 else 0.82)
    stage_changed.emit(cell_id, STAGES[stage_index])
    if stage_index == STAGES.size() - 1:
        ready_for_harvest.emit(cell_id)

## Pequeno "pop" ao brotar (de 0) e ao trocar de estágio (de from_scale).
func _play_stage_pop(from_scale: float) -> void:
    if _pop_tween and _pop_tween.is_valid():
        _pop_tween.kill()
    sprite.scale = Vector3.ONE * maxf(from_scale, 0.01)
    _pop_tween = create_tween()
    _pop_tween.tween_property(sprite, "scale", Vector3.ONE, stage_pop_duration) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func _visible_rect(path: String, texture: Texture2D) -> Rect2:
    if _visible_rect_cache.has(path):
        return _visible_rect_cache[path]
    var rect := _compute_visible_rect(texture.get_image())
    _visible_rect_cache[path] = rect
    return rect

## Recorta as margens quase transparentes do PNG para que todos os estágios
## sejam dimensionados pelo desenho real.
static func _compute_visible_rect(image: Image) -> Rect2:
    if image == null:
        return Rect2(0, 0, 1, 1)
    if image.is_compressed():
        image.decompress()
    if image.get_format() != Image.FORMAT_RGBA8:
        image.convert(Image.FORMAT_RGBA8)
    var width := image.get_width()
    var height := image.get_height()
    var pixels := image.get_data()
    var step := 2
    var min_x := width
    var min_y := height
    var max_x := -1
    var max_y := -1
    for y in range(0, height, step):
        var row := y * width * 4
        for x in range(0, width, step):
            if pixels[row + x * 4 + 3] >= ALPHA_THRESHOLD:
                min_x = mini(min_x, x)
                max_x = maxi(max_x, x)
                min_y = mini(min_y, y)
                max_y = maxi(max_y, y)
    if max_x < 0:
        return Rect2(0, 0, width, height)
    var left := maxi(0, min_x - step)
    var top := maxi(0, min_y - step)
    var right := mini(width, max_x + step + 1)
    var bottom := mini(height, max_y + step + 1)
    return Rect2(left, top, right - left, bottom - top)
