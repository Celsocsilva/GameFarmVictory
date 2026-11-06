extends Node3D
class_name SalesCounter
## Balcão de vendas: o fazendeiro descarrega toda a mochila de tomates aqui e
## os clientes compram do estoque do balcão (SalesController).
## Adicione como filho direto de FarmWorld e chame place_at_map_foot(farm_size).
## Chame setup(inventory) e process_farmer_position(farmer.global_position).
##
## O balcão é sólido (StaticBody3D) e, com build_side_barriers, cercas baixas
## ligam as pontas do balcão às laterais do terreno: o fazendeiro fica sempre
## do lado da plantação (-Z) e não passa para o lado dos clientes (+Z).

signal deposited(units: int, stored_total: int)
signal stock_taken(units: int, stored_total: int)

## Largura dobrada em relação ao antigo depósito (3 -> 6 colunas de caixas).
const COLUMNS := 6
const ROWS_PER_LAYER := 2
const LAYERS := 4
const MAX_VISUAL_CRATES := COLUMNS * ROWS_PER_LAYER * LAYERS
const CRATE_SIZE := Vector3(1.2, 0.48, 0.9)
const CRATE_SPACING := Vector3(1.35, 0.58, 1.05)
## Tampo/palete do balcão: 2 x 4,25 m de largura do antigo depósito.
const COUNTER_SIZE := Vector3(8.5, 0.16, 2.25)
const BACK_HEIGHT := 1.1
const BARRIER_HEIGHT := 0.7

@export_range(0, 48, 1) var initial_displayed_crates: int = 0
## Recuado da cerca para caber a fila dupla de 7 clientes do lado +Z.
@export_range(1.0, 16.0, 0.1) var foot_inset: float = 10.5
## Distância máxima entre o fazendeiro e a borda do balcão para descarregar.
@export_range(0.5, 5.0, 0.1) var deposit_reach: float = 1.3
@export_range(1, 64, 1) var units_per_crate: int = 8
@export var item_id: StringName = &"tomato"
## Cercas baixas das pontas do balcão até as laterais do terreno.
@export var build_side_barriers: bool = true

var _crate_visuals: Array[Node3D] = []
var _displayed_crates := 0
var _stored_total := 0
var _inventory: HarvestInventory
var _farm_size := 0.0
var _body: StaticBody3D

func _ready() -> void:
    var wood := _material(Color(0.58, 0.32, 0.12))
    var tomato := _material(Color(0.82, 0.10, 0.055))
    var pallet := _material(Color(0.28, 0.17, 0.09))
    _body = StaticBody3D.new()
    _body.name = "CounterBody"
    add_child(_body)
    _add_box(_body, "CounterTop", COUNTER_SIZE, Vector3(0.0, COUNTER_SIZE.y * 0.5, 0.0), pallet)
    _add_box(_body, "CounterBack", Vector3(COUNTER_SIZE.x, BACK_HEIGHT, 0.16), Vector3(0.0, BACK_HEIGHT * 0.5, COUNTER_SIZE.z * 0.5 + 0.055), pallet)
    var collision := CollisionShape3D.new()
    collision.name = "CounterCollision"
    var shape := BoxShape3D.new()
    shape.size = Vector3(COUNTER_SIZE.x, 1.6, COUNTER_SIZE.z + 0.27)
    collision.shape = shape
    collision.position = Vector3(0.0, 0.8, 0.07)
    _body.add_child(collision)
    for index in MAX_VISUAL_CRATES:
        _crate_visuals.append(_build_crate(index, wood, tomato))
    set_displayed_crates(initial_displayed_crates)

## O pé visível do mapa é a borda +Z. O inset mantém a pilha dentro da cerca.
## Requer que o balcão seja filho direto de FarmWorld, sem transform no pai.
func place_at_map_foot(farm_size: float) -> void:
    _farm_size = farm_size
    position = Vector3(0.0, 0.0, farm_size * 0.5 - foot_inset)
    if build_side_barriers and is_inside_tree():
        _build_barriers()

func setup(inventory: HarvestInventory) -> void:
    _inventory = inventory

## Meia largura (X) e meia profundidade (Z) da área sólida do balcão.
func get_half_extents() -> Vector2:
    return Vector2(COUNTER_SIZE.x * 0.5, COUNTER_SIZE.z * 0.5)

## Distância no plano XZ entre um ponto e a borda do balcão (0 se dentro).
func distance_to_counter(world_pos: Vector3) -> float:
    var local := world_pos - global_position
    var half := get_half_extents()
    var dx := maxf(absf(local.x) - half.x, 0.0)
    var dz := maxf(absf(local.z) - half.y, 0.0)
    return Vector2(dx, dz).length()

## Chame por frame. Encostar no balcão descarrega toda a mochila de tomates.
func process_farmer_position(world_pos: Vector3) -> void:
    if _inventory == null or not is_instance_valid(_inventory):
        return
    if distance_to_counter(world_pos) <= deposit_reach:
        deposit_from(_inventory)

## Remove todos os tomates carregados e retorna a quantidade efetivamente guardada.
## O balcão não tem limite de estoque: toda a produção cabe nele.
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

## Retira estoque para uma venda. Nunca deixa estoque negativo.
func take_units(units: int) -> int:
    var taken := clampi(units, 0, _stored_total)
    if taken <= 0:
        return 0
    _stored_total -= taken
    _sync_display()
    stock_taken.emit(taken, _stored_total)
    return taken

func get_stored_total() -> int:
    return _stored_total

## Caixas à venda (a última pode estar incompleta).
func get_stock_crates() -> int:
    return int(ceil(float(_stored_total) / float(units_per_crate)))

## Restauração de save; não altera o inventário do fazendeiro.
func set_stored_total(total: int) -> void:
    _stored_total = maxi(total, 0)
    _sync_display()

func _sync_display() -> void:
    set_displayed_crates(mini(MAX_VISUAL_CRATES, get_stock_crates()))

func set_displayed_crates(count: int) -> void:
    _displayed_crates = clampi(count, 0, MAX_VISUAL_CRATES)
    for index in _crate_visuals.size():
        _crate_visuals[index].visible = index < _displayed_crates

func get_displayed_crates() -> int:
    return _displayed_crates

## Cercas baixas (sólidas) das pontas do balcão até as laterais do terreno, na
## linha da frente do balcão. Os clientes não têm física e não são afetados.
func _build_barriers() -> void:
    var half := get_half_extents()
    var span := _farm_size * 0.5 - half.x
    if span <= 0.05:
        return
    var wood := _material(Color(0.62, 0.40, 0.18))
    for side in [-1.0, 1.0]:
        var barrier := StaticBody3D.new()
        barrier.name = "CounterBarrier_%s" % ("L" if side < 0.0 else "R")
        barrier.position = Vector3(side * (half.x + span * 0.5), 0.0, 0.0)
        add_child(barrier)
        _add_box(barrier, "Rail", Vector3(span, 0.12, 0.12), Vector3(0.0, BARRIER_HEIGHT - 0.06, 0.0), wood)
        _add_box(barrier, "RailLow", Vector3(span, 0.1, 0.1), Vector3(0.0, BARRIER_HEIGHT * 0.45, 0.0), wood)
        var posts := int(ceil(span / 2.0))
        for post in posts + 1:
            var x := -span * 0.5 + span * float(post) / float(posts)
            _add_box(barrier, "Post", Vector3(0.16, BARRIER_HEIGHT, 0.16), Vector3(x, BARRIER_HEIGHT * 0.5, 0.0), wood)
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(span, 1.6, 0.3)
        collision.shape = shape
        collision.position.y = 0.8
        barrier.add_child(collision)

func _build_crate(index: int, wood: Material, tomato: Material) -> Node3D:
    var crate := Node3D.new()
    crate.name = "CounterCrate_%02d" % index
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
