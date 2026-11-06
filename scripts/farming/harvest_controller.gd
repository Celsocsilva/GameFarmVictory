extends Node
class_name HarvestController
## Colheita automática de tomates maduros enquanto o fazendeiro caminha (FV-HARVEST-001).
##
## Fluxo por planta: candidato RIPE no raio -> reserva atômica na mochila ->
## célula HARVESTING -> VFX de sucção -> confirmação por fruto que chega ->
## HARVESTED (ou RIPE, se sobrar fruto por falta de espaço/cancelamento).
## Reutiliza a PlantingGrid como fonte de verdade das células; não move plantas.

signal harvest_started(cell_id: String, reserved_units: int)
signal harvest_unit_confirmed(item_id: StringName, units: int, total: int)
signal crate_filled(crate_index: int)
signal backpack_full()
signal harvest_finished(cell_id: String, state: String)
signal harvest_cancelled(cell_id: String, released_units: int)

const PICKUP_FX_SCRIPT := preload("res://scripts/vfx/tomato_pickup_fx.gd")

@export var item_id: StringName = &"tomato"
## Raio de ativação = multiplicador × menor distância entre centros de células.
@export_range(0.5, 3.0, 0.05) var radius_multiplier: float = 1.25
## Intervalo mínimo entre duas novas reservas.
@export_range(0.0, 1.0, 0.01) var harvest_interval: float = 0.12
@export_range(1, 32, 1) var yield_per_crop: int = 6
@export_range(1, 8, 1) var min_visual_tomatoes: int = 3
@export_range(1, 8, 1) var max_visual_tomatoes: int = 5
@export_range(0.2, 1.0, 0.01) var flight_duration_min: float = 0.35
@export_range(0.2, 1.0, 0.01) var flight_duration_max: float = 0.60
## Altura do arco em frações da largura da célula (0.3–0.6).
@export_range(0.3, 0.6, 0.01) var arc_height_factor: float = 0.45
## Afastar-se mais que isso de uma planta em coleta cancela o voo e devolve a reserva.
@export_range(1.0, 20.0, 0.5) var cancel_distance: float = 7.0
@export var enabled: bool = true

var grid: PlantingGrid
var inventory: HarvestInventory
var farmer: Node3D
var intake: Node3D
## cell_id -> CropPlant (mantido pelo FarmWorld).
var crops: Dictionary = {}
var fx_parent: Node

var _cooldown := 0.0
var _jobs: Dictionary = {}
var _full_notified := false

func setup(new_grid: PlantingGrid, new_inventory: HarvestInventory, new_farmer: Node3D, new_intake: Node3D, crop_map: Dictionary, new_fx_parent: Node) -> void:
    grid = new_grid
    inventory = new_inventory
    farmer = new_farmer
    intake = new_intake
    crops = crop_map
    fx_parent = new_fx_parent
    inventory.crate_filled.connect(func(index: int) -> void: crate_filled.emit(index))
    inventory.backpack_full.connect(_on_backpack_full)
    inventory.amount_changed.connect(_on_amount_changed)

func get_harvest_radius() -> float:
    return radius_multiplier * (grid.get_cell_spacing() if grid else 1.0)

func get_active_job_count() -> int:
    return _jobs.size()

func is_backpack_full() -> bool:
    return inventory != null and inventory.is_full()

func _process(delta: float) -> void:
    if grid == null or inventory == null or farmer == null:
        return
    _check_cancellations()
    if not enabled:
        return
    _cooldown = maxf(0.0, _cooldown - delta)
    if _cooldown > 0.0 or inventory.get_free_capacity() <= 0:
        return
    var candidates := grid.get_ripe_cells_near(farmer.global_position, get_harvest_radius())
    if not candidates.is_empty() and request_collect(candidates[0]["id"]):
        _cooldown = harvest_interval

## Contrato FV-HARVEST-001. Retorna false se a célula não está madura, já está
## em coleta ou a mochila não tem espaço.
func request_collect(cell_id: String) -> bool:
    if grid == null or not grid.cells.has(cell_id) or _jobs.has(cell_id):
        return false
    if grid.cells[cell_id]["state"] != PlantingGrid.STATE_RIPE:
        return false
    var available := grid.get_remaining_yield(cell_id)
    if available <= 0:
        return false
    # Reserva antes de criar qualquer sprite de voo.
    var reservation := inventory.try_reserve(item_id, available)
    if not reservation.is_valid():
        return false
    if not grid.begin_harvest(cell_id):
        inventory.cancel(reservation)
        return false
    var cell: Dictionary = grid.cells[cell_id]
    var crop: CropPlant = crops.get(cell_id)
    var visual_count := mini(_visual_count_for(cell_id), reservation.amount)
    var camera := farmer.get_viewport().get_camera_3d()
    var origins: Array[Vector3] = []
    if crop and is_instance_valid(crop):
        origins = crop.get_harvest_origins(visual_count, camera)
        crop.play_harvest_shake()
    else:
        for i in visual_count:
            origins.append(cell["position"] + Vector3(0.0, 0.8, 0.0))
    var fx := PICKUP_FX_SCRIPT.new() as TomatoPickupFX
    fx.name = "TomatoPickupFX_" + cell_id
    fx.duration_min = flight_duration_min
    fx.duration_max = flight_duration_max
    fx.arc_height = float(cell["cell_width"]) * arc_height_factor
    var job := {
        "cell_id": cell_id,
        "reservation": reservation,
        "fx": fx,
        "units": _split_units(reservation.amount, visual_count),
        "origin": cell["position"]
    }
    _jobs[cell_id] = job
    fx.fruit_arrived.connect(_on_fruit_arrived.bind(cell_id))
    fx.finished.connect(_on_fx_finished.bind(cell_id))
    (fx_parent if fx_parent else get_parent()).add_child(fx)
    fx.launch(origins, intake)
    harvest_started.emit(cell_id, reservation.amount)
    return true

## Cancela uma coleta em andamento: devolve a capacidade não confirmada e deixa
## os frutos restantes na planta.
func cancel_collect(cell_id: String) -> void:
    if not _jobs.has(cell_id):
        return
    var job: Dictionary = _jobs[cell_id]
    _jobs.erase(cell_id)
    var fx: TomatoPickupFX = job["fx"]
    # Sem o job, chegadas tardias são ignoradas; o FX cancelado não emite mais nada.
    if is_instance_valid(fx):
        fx.cancel()
    var reservation: HarvestInventory.Reservation = job["reservation"]
    var released := inventory.cancel(reservation) if inventory else 0
    var state := grid.finish_harvest(cell_id) if grid else ""
    _update_crop_visual(cell_id, state)
    harvest_cancelled.emit(cell_id, released)

func cancel_all() -> void:
    for cell_id in _jobs.keys():
        cancel_collect(cell_id)

func _exit_tree() -> void:
    # Troca de cena: nenhuma reserva pendente pode sobreviver nem duplicar.
    cancel_all()

func _check_cancellations() -> void:
    if _jobs.is_empty():
        return
    var here := Vector2(farmer.global_position.x, farmer.global_position.z)
    for cell_id in _jobs.keys():
        var origin: Vector3 = _jobs[cell_id]["origin"]
        if here.distance_to(Vector2(origin.x, origin.z)) > cancel_distance or not is_instance_valid(intake):
            cancel_collect(cell_id)

func _on_fruit_arrived(index: int, cell_id: String) -> void:
    if not _jobs.has(cell_id):
        return
    var job: Dictionary = _jobs[cell_id]
    var units: Array = job["units"]
    var confirmed := inventory.commit(job["reservation"], int(units[index]) if index < units.size() else 0)
    grid.consume_yield(cell_id, confirmed)
    if confirmed > 0:
        harvest_unit_confirmed.emit(item_id, confirmed, inventory.get_amount(item_id))

func _on_fx_finished(cell_id: String) -> void:
    if not _jobs.has(cell_id):
        return
    var job: Dictionary = _jobs[cell_id]
    _jobs.erase(cell_id)
    var reservation: HarvestInventory.Reservation = job["reservation"]
    # Qualquer sobra de arredondamento é confirmada; nada fica pendurado.
    grid.consume_yield(cell_id, inventory.commit(reservation))
    var state := grid.finish_harvest(cell_id)
    _update_crop_visual(cell_id, state)
    harvest_finished.emit(cell_id, state)

func _update_crop_visual(cell_id: String, state: String) -> void:
    var crop: CropPlant = crops.get(cell_id)
    if crop and is_instance_valid(crop) and state == PlantingGrid.STATE_HARVESTED:
        crop.set_harvested()

func _on_backpack_full() -> void:
    if _full_notified:
        return
    _full_notified = true
    backpack_full.emit()

func _on_amount_changed(_item: StringName, _amount: int) -> void:
    if not inventory.is_full():
        _full_notified = false

## 3–5 frutos visuais, determinístico por célula.
func _visual_count_for(cell_id: String) -> int:
    var low := mini(min_visual_tomatoes, max_visual_tomatoes)
    var high := maxi(min_visual_tomatoes, max_visual_tomatoes)
    return low + int(absi(hash(cell_id)) % (high - low + 1))

## Divide as unidades reservadas entre os frutos visuais (ex.: 6 em 4 -> 2,2,1,1).
static func _split_units(total: int, parts: int) -> Array[int]:
    var result: Array[int] = []
    parts = maxi(1, parts)
    for i in parts:
        result.append(total / parts + (1 if i < total % parts else 0))
    return result
