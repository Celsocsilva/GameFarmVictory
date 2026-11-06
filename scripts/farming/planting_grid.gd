extends Node3D
class_name PlantingGrid

signal cell_planted(cell_id: String)

@export var planting_radius: float = 0.95
## Distância à frente do fazendeiro onde o punhado cai (arremesso, não plantio no pé).
@export_range(0.0, 4.0, 0.1) var throw_reach: float = 3.0
@export var columns: int = 3
@export var rows_per_module: int = 7
@export var row_spacing: float = 2.1
@export var test_mode: bool = true

var cells: Dictionary = {}
var _last_farmer_position := Vector3.ZERO
var _has_previous_position := false
var _plant_accumulator := 0.0
# Direção do último deslocamento; começa olhando para o canteiro (+Z).
var _facing := Vector3(0.0, 0.0, 1.0)

func configure(modules: Array[Area3D]) -> void:
    for module in modules:
        var shape := (module.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
        var module_width := shape.size.x
        var module_length := shape.size.z
        var cell_width := module_width / float(columns)
        var cell_length := module_length / float(rows_per_module)
        for row in rows_per_module:
            for column in columns:
                var cell_id := "%s_r%02d_c%02d" % [module.name, row, column]
                if cells.has(cell_id):
                    continue
                var local_offset := Vector3(
                    (column + 0.5) * cell_width - module_width * 0.5,
                    0.12,
                    (row + 0.5) * cell_length - module_length * 0.5
                )
                cells[cell_id] = {
                    "id": cell_id,
                    "module_id": module.name,
                    "row": row,
                    "column": column,
                    "crop_id": "tomato",
                    "cell_width": cell_width,
                    "position": module.to_global(local_offset),
                    "state": "EMPTY",
                    "planted_at": 0.0
                }

func process_farmer_position(world_position: Vector3, delta: float) -> void:
    if not _has_previous_position:
        _last_farmer_position = world_position
        _has_previous_position = true
    _plant_accumulator += delta
    if _plant_accumulator < 0.35:
        return
    _plant_accumulator = 0.0
    var travel := world_position - _last_farmer_position
    var flat_travel := Vector3(travel.x, 0.0, travel.z)
    if flat_travel.length() > 0.05:
        _facing = flat_travel.normalized()
    var reach := _facing * throw_reach
    var sample_count := maxi(1, int(ceil(travel.length() / 0.45)))
    for sample in sample_count + 1:
        var sample_position := _last_farmer_position.lerp(world_position, float(sample) / float(sample_count)) + reach
        var available := get_available_cells_near(sample_position, planting_radius)
        if not available.is_empty():
            plant_cell(available[0]["id"])
            break
    _last_farmer_position = world_position

func get_cell_at_world(world_pos: Vector3) -> Dictionary:
    var nearest: Dictionary = {}
    var nearest_distance := planting_radius
    for cell in cells.values():
        var distance := Vector2(cell["position"].x, cell["position"].z).distance_to(Vector2(world_pos.x, world_pos.z))
        if distance <= nearest_distance:
            nearest = cell
            nearest_distance = distance
    return nearest

func get_available_cells_near(world_pos: Vector3, radius: float) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for cell in cells.values():
        var distance := Vector2(cell["position"].x, cell["position"].z).distance_to(Vector2(world_pos.x, world_pos.z))
        if distance <= radius and cell["state"] == "EMPTY":
            result.append(cell)
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var da: Vector3 = a["position"]
        var db: Vector3 = b["position"]
        return Vector2(da.x, da.z).distance_to(Vector2(world_pos.x, world_pos.z)) < Vector2(db.x, db.z).distance_to(Vector2(world_pos.x, world_pos.z)))
    return result

func get_cell_world_position(cell_id: String) -> Vector3:
    return cells[cell_id]["position"] if cells.has(cell_id) else Vector3.ZERO

func get_next_unplanted_cell() -> Dictionary:
    for cell in cells.values():
        if cell["state"] == "EMPTY":
            return cell
    return {}

func get_planting_progress() -> Dictionary:
    var planted := 0
    for cell in cells.values():
        if cell["state"] != "EMPTY":
            planted += 1
    return {"total": cells.size(), "planted": planted, "remaining": cells.size() - planted}

func plant_cell(cell_id: String) -> bool:
    if not cells.has(cell_id) or cells[cell_id]["state"] != "EMPTY":
        return false
    cells[cell_id]["state"] = "SEEDED"
    cells[cell_id]["planted_at"] = Time.get_ticks_msec() / 1000.0
    cell_planted.emit(cell_id)
    return true
