extends Node3D
class_name TomatoDepot
## Visual 3D do depósito de tomates, com descarga explícita da mochila.
## Adicione como filho direto de FarmWorld e chame place_at_map_foot(farm_size).
## Chame setup(inventory) e process_farmer_position(farmer.global_position).

signal deposited(units: int, stored_total: int)

const COLUMNS := 3
const ROWS_PER_LAYER := 2
const MAX_VISUAL_CRATES := 21
const CRATE_SIZE := Vector3(1.2, 0.48, 0.9)
const CRATE_SPACING := Vector3(1.35, 0.58, 1.05)

@export_range(0, 21, 1) var initial_displayed_crates: int = 0
## Recuada da cerca para caber a fila dupla de 7 clientes do lado +Z.
@export_range(1.0, 16.0, 0.1) var foot_inset: float = 11.5
@export_range(0.5, 5.0, 0.1) var deposit_radius: float = 2.8
@export_range(1, 64, 1) var units_per_crate: int = 8
@export var item_id: StringName = &"tomato"

var _crate_visuals: Array[Node3D] = []
var _displayed_crates := 0
var _stored_total := 0
var _inventory: HarvestInventory

func _ready() -> void:
    var wood := _material(Color(0.58, 0.32, 0.12))
    var tomato := _material(Color(0.82, 0.10, 0.055))
    var pallet := _material(Color(0.28, 0.17, 0.09))
    _add_box(self, "Pallet", Vector3(4.25, 0.16, 2.25), Vector3(0.0, 0.08, 0.0), pallet)
    _add_box(self, "DepotBack", Vector3(4.25, 1.1, 0.16), Vector3(0.0, 0.55, 1.18), pallet)
    for index in MAX_VISUAL_CRATES:
        _crate_visuals.append(_build_crate(index, wood, tomato))
    set_displayed_crates(initial_displayed_crates)

## O pé visível do mapa é a borda +Z. O inset mantém a pilha dentro da cerca.
## Requer que o depósito seja filho direto de FarmWorld, sem transform no pai.
func place_at_map_foot(farm_size: float) -> void:
    position = Vector3(0.0, 0.0, farm_size * 0.5 - foot_inset)

func setup(inventory: HarvestInventory) -> void:
    _inventory = inventory

## Chame por frame. Uma nova entrada só descarrega se houver tomates na mochila.
func process_farmer_position(world_pos: Vector3) -> void:
    if _inventory == null or not is_instance_valid(_inventory):
        return
    var distance := Vector2(world_pos.x, world_pos.z).distance_to(Vector2(global_position.x, global_position.z))
    if distance <= deposit_radius:
        deposit_from(_inventory)

## Remove todos os tomates carregados e retorna a quantidade efetivamente guardada.
func deposit_from(inventory: HarvestInventory) -> int:
    if inventory == null or not is_instance_valid(inventory):
        return 0
    var carried := inventory.get_amount(item_id)
    if carried <= 0:
        return 0
    var removed := inventory.remove(item_id, carried)
    _stored_total += removed
    _sync_display()
    if removed > 0:
        deposited.emit(removed, _stored_total)
    return removed

func get_stored_total() -> int:
    return _stored_total

## Restauração de save; não altera o inventário do fazendeiro.
func set_stored_total(total: int) -> void:
    _stored_total = maxi(total, 0)
    _sync_display()

func _sync_display() -> void:
    if _stored_total > 0:
        set_displayed_crates(mini(MAX_VISUAL_CRATES, int(ceil(float(_stored_total) / float(units_per_crate)))))
    else:
        set_displayed_crates(0)

func set_displayed_crates(count: int) -> void:
    _displayed_crates = clampi(count, 0, MAX_VISUAL_CRATES)
    for index in _crate_visuals.size():
        _crate_visuals[index].visible = index < _displayed_crates

func get_displayed_crates() -> int:
    return _displayed_crates

func _build_crate(index: int, wood: Material, tomato: Material) -> Node3D:
    var crate := Node3D.new()
    crate.name = "DepotCrate_%02d" % index
    var layer := index / (COLUMNS * ROWS_PER_LAYER)
    var row := (index / COLUMNS) % ROWS_PER_LAYER
    var column := index % COLUMNS
    crate.position = Vector3(
        (column - (COLUMNS - 1) * 0.5) * CRATE_SPACING.x,
        0.16 + layer * CRATE_SPACING.y,
        (row - (ROWS_PER_LAYER - 1) * 0.5) * CRATE_SPACING.z
    )
    add_child(crate)
    _add_box(crate, "Base", Vector3(CRATE_SIZE.x, 0.12, CRATE_SIZE.z), Vector3(0.0, 0.06, 0.0), wood)
    for side in [-1.0, 1.0]:
        _add_box(crate, "Side", Vector3(0.08, 0.42, CRATE_SIZE.z), Vector3(side * 0.56, 0.27, 0.0), wood)
        _add_box(crate, "End", Vector3(CRATE_SIZE.x, 0.42, 0.08), Vector3(0.0, 0.27, side * 0.41), wood)
    var fruit_mesh := SphereMesh.new()
    fruit_mesh.radius = 0.17
    fruit_mesh.height = 0.34
    for x in [-0.23, 0.23]:
        for z in [-0.18, 0.18]:
            var fruit := MeshInstance3D.new()
            fruit.name = "Tomato"
            fruit.mesh = fruit_mesh
            fruit.material_override = tomato
            fruit.position = Vector3(x, 0.43, z)
            crate.add_child(fruit)
    return crate

func _add_box(parent: Node3D, label: String, size: Vector3, offset: Vector3, material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var visual := MeshInstance3D.new()
    visual.name = label
    visual.mesh = mesh
    visual.material_override = material
    visual.position = offset
    parent.add_child(visual)

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85
    return material
