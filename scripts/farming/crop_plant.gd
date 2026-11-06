extends Node3D
class_name CropPlant

signal stage_changed(cell_id: String, stage: String)
signal ready_for_harvest(cell_id: String)

@export var cell_id: String = ""
@export var accelerated_test_mode: bool = true
@export var growth_duration: float = 30.0
@export var cell_width: float = 1.15
@export var max_plant_height: float = 1.8

const STAGES := ["SPROUT", "GROWING", "FLOWERING", "GREEN_FRUIT", "READY_TO_HARVEST"]
const STAGE_ASSETS := [
    "res://assets/crops/tomato/stages/01_sprout.png",
    "res://assets/crops/tomato/stages/02_vegetative_growth.png",
    "res://assets/crops/tomato/stages/03_flowering_fruit_set.png",
    "res://assets/crops/tomato/stages/04_green_fruit.png",
    "res://assets/crops/tomato/stages/05_ready_to_harvest.png"
]
static var _visible_bottom_cache: Dictionary = {}

var stage_index := -1
var planted_at := 0.0
var sprite: Sprite3D

func initialize(new_cell_id: String, timestamp: float) -> void:
    cell_id = new_cell_id
    planted_at = timestamp
    var grid := get_parent().get_node_or_null("PlantingGrid")
    if grid != null:
        var cells: Dictionary = grid.get("cells")
        if cells.has(cell_id):
            var cell: Dictionary = cells[cell_id]
            cell_width = float(cell.get("cell_width", cell_width))
    sprite = Sprite3D.new()
    sprite.name = "TomatoPlantSprite"
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.shaded = false
    sprite.double_sided = true
    sprite.transparent = true
    sprite.render_priority = 1
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
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

func _update_stage(new_index: int) -> void:
    stage_index = new_index
    sprite.texture = load(STAGE_ASSETS[stage_index]) as Texture2D
    var texture_size := sprite.texture.get_size()
    var texture_width := maxf(1.0, texture_size.x)
    var texture_height := maxf(1.0, texture_size.y)
    sprite.pixel_size = minf(max_plant_height / texture_height, cell_width * 0.9 / texture_width)
    # Desconsiderar pixels quase transparentes nas margens do PNG.
    var visible_bottom: int
    if _visible_bottom_cache.has(stage_index):
        visible_bottom = _visible_bottom_cache[stage_index]
    else:
        visible_bottom = _visible_bottom(sprite.texture.get_image())
        _visible_bottom_cache[stage_index] = visible_bottom
    sprite.offset = Vector2.ZERO
    sprite.position.y = maxf(0.05, float(visible_bottom) * sprite.pixel_size * 0.5)
    stage_changed.emit(cell_id, STAGES[stage_index])
    if stage_index == STAGES.size() - 1:
        ready_for_harvest.emit(cell_id)

func _visible_bottom(image: Image) -> int:
    if image.is_compressed():
        image.decompress()
    image.convert(Image.FORMAT_RGBA8)
    var pixels := image.get_data()
    var width := image.get_width()
    var minimum_samples := maxi(2, int(width / 400.0))
    for y in range(image.get_height() - 1, -1, -1):
        var opaque_samples := 0
        for x in range(0, width, 4):
            if pixels[(y * width + x) * 4 + 3] >= 64:
                opaque_samples += 1
                if opaque_samples >= minimum_samples:
                    return y + 1
    return image.get_height()
