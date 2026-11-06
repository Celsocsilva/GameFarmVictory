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
const CELL_SIZE := Vector2(0.82, 0.78)
## Largura do maço no chão; a profundidade segue a proporção da arte.
const BUNDLE_WIDTH := 0.74
## Altura de cada camada: a espessura do maço desenhado na arte.
const LAYER_STEP := 0.1
const BASE_HEIGHT := 0.06
## A câmera olha o chão a 45°: o eixo Z aparece encurtado por sin(45°), então
## o maço deitado é esticado por 1/sin(45°) para manter a proporção da arte.
const VIEW_STRETCH := 1.0 / sin(deg_to_rad(45.0))

@export_range(1, 40, 1) var max_layers: int = 12

var _balance := 0
var _bundles: Array[MeshInstance3D] = []
var _bundle_mesh: QuadMesh
var _bundle_material: StandardMaterial3D

func _ready() -> void:
    var frame := _material(Color(0.42, 0.26, 0.12))
    var felt := _material(Color(0.16, 0.36, 0.16))
    var cell_felt := _material(Color(0.22, 0.46, 0.20))
    var base_size := Vector3(COLUMNS * CELL_SIZE.x + 0.24, BASE_HEIGHT, ROWS * CELL_SIZE.y + 0.24)
    _add_box("BaseFrame", base_size, Vector3(0.0, BASE_HEIGHT * 0.5, 0.0), frame)
    _add_box("BaseFelt", Vector3(base_size.x - 0.12, 0.02, base_size.z - 0.12), Vector3(0.0, BASE_HEIGHT + 0.01, 0.0), felt)
    for slot in SLOTS:
        var center := get_slot_position(slot)
        _add_box("Cell_%02d" % slot, Vector3(CELL_SIZE.x - 0.08, 0.01, CELL_SIZE.y - 0.08), Vector3(center.x, BASE_HEIGHT + 0.025, center.z), cell_felt)
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
    bundle.position = Vector3(center.x, BASE_HEIGHT + 0.04 + layer * LAYER_STEP, center.z)
    add_child(bundle)
    return bundle

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
