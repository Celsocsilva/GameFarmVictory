extends Node3D
class_name MoneyStack
## Base de 3 fileiras x 5 linhas onde o dinheiro das vendas é empilhado.
## Cada maço visível vale 1 dinheiro. Os maços preenchem as 15 posições da
## base (fileira a fileira) e depois sobem em camadas, até max_layers.
## O saldo (get_balance) não tem limite; acima da pilha máxima só o saldo cresce.

signal balance_changed(balance: int, delta: int)

const MONEY_TEXTURE := preload("res://assets/sales/money_bundle.png")
const COLUMNS := 3
const ROWS := 5
const SLOTS := COLUMNS * ROWS
## Tamanho de cada posição da base, no chão (X = fileira, Z = linha).
## Maços e base 1,7x maiores que a primeira versão (0,82 x 0,78 por posição).
const MONEY_SCALE := 1.7
const CELL_SIZE := Vector2(0.82, 0.78) * MONEY_SCALE
## Largura do maço no chão; a profundidade segue a proporção da arte.
const BUNDLE_WIDTH := 0.74 * MONEY_SCALE
## Altura de cada camada: a espessura do maço desenhado na arte.
const LAYER_STEP := 0.06 * MONEY_SCALE
## Bloco de madeira: espessura, raio dos cantos e folga além das 15 posições.
const BASE_HEIGHT := 0.08
const BASE_RADIUS := 0.2 * MONEY_SCALE
const BASE_MARGIN := 0.12 * MONEY_SCALE
## A câmera olha o chão a 45°: o eixo Z aparece encurtado por sin(45°), então
## o maço deitado é esticado por 1/sin(45°) para manter a proporção da arte.
const VIEW_STRETCH := 1.0 / sin(deg_to_rad(45.0))

@export_range(1, 40, 1) var max_layers: int = 12

var _balance := 0
var _bundles: Array[MeshInstance3D] = []
var _bundle_mesh: QuadMesh
var _bundle_material: StandardMaterial3D

func _ready() -> void:
    # Bloco fino de madeira clara com cantos arredondados: corpo um pouco mais
    # escuro (borda) e tampo claro levemente recuado, imitando um chanfro.
    var wood_edge := _material(Color(0.60, 0.40, 0.22))
    var wood_top := _material(Color(0.78, 0.57, 0.35))
    var base_size := get_base_size()
    _add_rounded_slab("WoodBase", Vector2(base_size.x, base_size.z), BASE_RADIUS, 0.0, BASE_HEIGHT - 0.015, wood_edge)
    _add_rounded_slab("WoodBaseTop", Vector2(base_size.x - 0.08, base_size.z - 0.08), BASE_RADIUS - 0.04, BASE_HEIGHT - 0.015, 0.015, wood_top)
    var texture_size := MONEY_TEXTURE.get_size()
    _bundle_mesh = QuadMesh.new()
    _bundle_mesh.size = Vector2(BUNDLE_WIDTH, BUNDLE_WIDTH * texture_size.y / texture_size.x * VIEW_STRETCH)
    _bundle_material = StandardMaterial3D.new()
    _bundle_material.albedo_texture = MONEY_TEXTURE
    _bundle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    _bundle_material.alpha_scissor_threshold = 0.5
    _bundle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _bundle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _bundle_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## Tamanho do bloco de madeira (X, altura, Z).
static func get_base_size() -> Vector3:
    return Vector3(COLUMNS * CELL_SIZE.x + BASE_MARGIN * 2.0, BASE_HEIGHT, ROWS * CELL_SIZE.y + BASE_MARGIN * 2.0)

func get_capacity_visual() -> int:
    return SLOTS * max_layers

func get_balance() -> int:
    return _balance

func get_visible_bundles() -> int:
    var count := 0
    for bundle in _bundles:
        if bundle.visible:
            count += 1
    return count

## Centro local de uma posição da base. Posição 0 = fileira 0, linha 0
## (canto -X, -Z); as fileiras correm em X e as linhas em Z.
func get_slot_position(slot: int) -> Vector3:
    var column := slot % COLUMNS
    var row := slot / COLUMNS
    return Vector3((column - (COLUMNS - 1) * 0.5) * CELL_SIZE.x, 0.0, (row - (ROWS - 1) * 0.5) * CELL_SIZE.y)

## Maços empilhados numa posição da base.
func get_slot_height(slot: int) -> int:
    var shown := mini(_balance, get_capacity_visual())
    if slot >= shown:
        return 0
    return (shown - 1 - slot) / SLOTS + 1

func add_money(amount: int) -> void:
    if amount <= 0:
        return
    _balance += amount
    _sync_display()
    balance_changed.emit(_balance, amount)

## Gasta saldo (compras futuras). Retorna false se não houver saldo.
func spend(amount: int) -> bool:
    if amount <= 0 or amount > _balance:
        return false
    _balance -= amount
    _sync_display()
    balance_changed.emit(_balance, -amount)
    return true

## Restauração de save.
func set_balance(value: int) -> void:
    var delta := maxi(value, 0) - _balance
    _balance = maxi(value, 0)
    _sync_display()
    if delta != 0:
        balance_changed.emit(_balance, delta)

func _sync_display() -> void:
    var shown := mini(_balance, get_capacity_visual())
    while _bundles.size() < shown:
        _bundles.append(_build_bundle(_bundles.size()))
    for index in _bundles.size():
        _bundles[index].visible = index < shown

func _build_bundle(index: int) -> MeshInstance3D:
    var slot := index % SLOTS
    var layer := index / SLOTS
    var bundle := MeshInstance3D.new()
    bundle.name = "Money_%03d" % index
    bundle.mesh = _bundle_mesh
    bundle.material_override = _bundle_material
    bundle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    bundle.rotation_degrees.x = -90.0
    var center := get_slot_position(slot)
    bundle.position = Vector3(center.x, BASE_HEIGHT + 0.02 + layer * LAYER_STEP, center.z)
    add_child(bundle)
    return bundle

## Retângulo de cantos arredondados extrudado: duas caixas em cruz + 4 cilindros.
func _add_rounded_slab(label: String, size: Vector2, radius: float, bottom: float, height: float, material: Material) -> void:
    var y := bottom + height * 0.5
    _add_box(label + "_X", Vector3(size.x - radius * 2.0, height, size.y), Vector3(0.0, y, 0.0), material)
    _add_box(label + "_Z", Vector3(size.x, height, size.y - radius * 2.0), Vector3(0.0, y, 0.0), material)
    var corner := CylinderMesh.new()
    corner.top_radius = radius
    corner.bottom_radius = radius
    corner.height = height
    corner.radial_segments = 24
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var visual := MeshInstance3D.new()
            visual.name = label + "_Corner"
            visual.mesh = corner
            visual.material_override = material
            visual.position = Vector3(sx * (size.x * 0.5 - radius), y, sz * (size.y * 0.5 - radius))
            add_child(visual)

func _add_box(label: String, size: Vector3, offset: Vector3, material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var visual := MeshInstance3D.new()
    visual.name = label
    visual.mesh = mesh
    visual.material_override = material
    visual.position = offset
    add_child(visual)

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    return material
