extends Node3D
class_name MoneyStack
## Base de 3 fileiras x 5 linhas onde o dinheiro das vendas é empilhado.
## Cada maço visível vale 1 dinheiro. Cada venda põe os maços nas pilhas mais
## baixas (a de menor índice primeiro), então as 15 posições enchem por igual e
## uma pilha recolhida volta a ser a primeira a receber.
## As pilhas ficam encostadas umas nas outras (posição = tamanho do maço) e o
## bloco de madeira tem só uma borda fina em volta.
##
## O fazendeiro recolhe uma pilha ao tocá-la (collect_at): a pilha esvazia e o
## valor vai para a Wallet (saldo do HUD, para compras futuras).

signal balance_changed(balance: int, delta: int)
signal slot_collected(slot: int, amount: int)

const MONEY_TEXTURE := preload("res://assets/sales/money_bundle.png")
const COLUMNS := 3
const ROWS := 5
const SLOTS := COLUMNS * ROWS
## Maços 1,7x maiores que a primeira versão.
const MONEY_SCALE := 1.7
## Largura do maço no chão; a profundidade segue a proporção da arte.
const BUNDLE_WIDTH := 0.74 * MONEY_SCALE
## Proporção altura/largura de money_bundle.png (512 x 276).
const ART_ASPECT := 276.0 / 512.0
## A câmera olha o chão a 45°: o eixo Z aparece encurtado por sin(45°), então
## o maço deitado é esticado por 1/sin(45°) para manter a proporção da arte.
const VIEW_STRETCH := 1.0 / sin(deg_to_rad(45.0))
## Cada posição tem exatamente o tamanho do maço no chão: sem vão entre pilhas.
const CELL_SIZE := Vector2(BUNDLE_WIDTH, BUNDLE_WIDTH * ART_ASPECT * VIEW_STRETCH)
## Altura de cada camada: a espessura do maço desenhado na arte.
const LAYER_STEP := 0.06 * MONEY_SCALE
## Bloco de madeira: espessura, raio dos cantos e borda fina além das pilhas.
const BASE_HEIGHT := 0.08
const BASE_MARGIN := 0.1
const BASE_RADIUS := 0.16
## Folga para "tocar" uma pilha (raio do corpo do fazendeiro).
const TOUCH_REACH := 0.45

@export_range(1, 40, 1) var max_layers: int = 12

## Registro para testes: {"slot", "amount"} de cada pilha recolhida.
var collect_log: Array[Dictionary] = []
var _counts: Array[int] = []
var _bundles: Array = []
var _bundle_mesh: QuadMesh
var _bundle_material: StandardMaterial3D

func _ready() -> void:
    _counts.resize(SLOTS)
    _counts.fill(0)
    for slot in SLOTS:
        _bundles.append([])
    # Bloco fino de madeira clara com cantos arredondados: corpo um pouco mais
    # escuro (borda) e tampo claro levemente recuado, imitando um chanfro.
    var wood_edge := _material(Color(0.60, 0.40, 0.22))
    var wood_top := _material(Color(0.78, 0.57, 0.35))
    var base_size := get_base_size()
    _add_rounded_slab("WoodBase", Vector2(base_size.x, base_size.z), BASE_RADIUS, 0.0, BASE_HEIGHT - 0.015, wood_edge)
    _add_rounded_slab("WoodBaseTop", Vector2(base_size.x - 0.06, base_size.z - 0.06), BASE_RADIUS - 0.03, BASE_HEIGHT - 0.015, 0.015, wood_top)
    _bundle_mesh = QuadMesh.new()
    _bundle_mesh.size = CELL_SIZE
    _bundle_material = StandardMaterial3D.new()
    _bundle_material.albedo_texture = MONEY_TEXTURE
    _bundle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    _bundle_material.alpha_scissor_threshold = 0.5
    _bundle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _bundle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _bundle_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## Tamanho do bloco de madeira (X, altura, Z): as 15 pilhas + borda fina.
static func get_base_size() -> Vector3:
    return Vector3(COLUMNS * CELL_SIZE.x + BASE_MARGIN * 2.0, BASE_HEIGHT, ROWS * CELL_SIZE.y + BASE_MARGIN * 2.0)

func get_capacity_visual() -> int:
    return SLOTS * max_layers

## Dinheiro empilhado na base, ainda não recolhido.
func get_balance() -> int:
    var total := 0
    for count in _counts:
        total += count
    return total

func get_visible_bundles() -> int:
    var total := 0
    for slot in SLOTS:
        total += get_slot_height(slot)
    return total

## Centro local de uma posição da base. Posição 0 = fileira 0, linha 0
## (canto -X, -Z); as fileiras correm em X e as linhas em Z.
func get_slot_position(slot: int) -> Vector3:
    var column := slot % COLUMNS
    var row := slot / COLUMNS
    return Vector3((column - (COLUMNS - 1) * 0.5) * CELL_SIZE.x, 0.0, (row - (ROWS - 1) * 0.5) * CELL_SIZE.y)

## Maços visíveis numa posição da base.
func get_slot_height(slot: int) -> int:
    return mini(_counts[slot], max_layers)

## Valor guardado numa posição (pode passar da altura visível).
func get_slot_amount(slot: int) -> int:
    return _counts[slot]

func add_money(amount: int) -> void:
    if amount <= 0:
        return
    for unit in amount:
        var lowest := 0
        for slot in SLOTS:
            if _counts[slot] < _counts[lowest]:
                lowest = slot
        _counts[lowest] += 1
    _sync_display()
    balance_changed.emit(get_balance(), amount)

## Esvazia uma pilha e devolve o valor dela.
func collect_slot(slot: int) -> int:
    var amount := _counts[slot]
    if amount <= 0:
        return 0
    _counts[slot] = 0
    _sync_display()
    collect_log.append({"slot": slot, "amount": amount})
    slot_collected.emit(slot, amount)
    balance_changed.emit(get_balance(), -amount)
    return amount

## Pilha sob um ponto do mundo (com a folga do corpo), ou -1.
func get_slot_at(world_pos: Vector3, reach: float = 0.0) -> int:
    var local := to_local(world_pos)
    var best := -1
    var best_distance := INF
    for slot in SLOTS:
        var center := get_slot_position(slot)
        var dx := maxf(absf(local.x - center.x) - CELL_SIZE.x * 0.5, 0.0)
        var dz := maxf(absf(local.z - center.z) - CELL_SIZE.y * 0.5, 0.0)
        var distance := Vector2(dx, dz).length()
        if distance <= reach and distance < best_distance:
            best = slot
            best_distance = distance
    return best

## Chame por frame: recolhe a pilha que o fazendeiro está tocando (a mais
## próxima) e credita na carteira. Retorna o valor recolhido.
func collect_at(world_pos: Vector3, wallet: Wallet) -> int:
    var slot := get_slot_at(world_pos, TOUCH_REACH)
    if slot < 0 or _counts[slot] <= 0:
        return 0
    var from := to_global(get_slot_position(slot) + Vector3(0.0, BASE_HEIGHT + get_slot_height(slot) * LAYER_STEP, 0.0))
    var amount := collect_slot(slot)
    if wallet:
        wallet.add(amount, &"money_stack")
    _fly_to(from, world_pos + Vector3(0.0, 1.6, 0.0), mini(amount, 4))
    return amount

## Restauração de save: redistribui o valor pelas pilhas.
func set_balance(value: int) -> void:
    var before := get_balance()
    _counts.fill(0)
    _sync_display()
    if value > 0:
        add_money(value)
    elif before != 0:
        balance_changed.emit(0, -before)

func _sync_display() -> void:
    for slot in SLOTS:
        var stack: Array = _bundles[slot]
        var height := get_slot_height(slot)
        while stack.size() < height:
            stack.append(_build_bundle(slot, stack.size()))
        for layer in stack.size():
            (stack[layer] as MeshInstance3D).visible = layer < height

func _build_bundle(slot: int, layer: int) -> MeshInstance3D:
    var bundle := MeshInstance3D.new()
    bundle.name = "Money_%02d_%02d" % [slot, layer]
    bundle.mesh = _bundle_mesh
    bundle.material_override = _bundle_material
    bundle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    bundle.rotation_degrees.x = -90.0
    var center := get_slot_position(slot)
    bundle.position = Vector3(center.x, BASE_HEIGHT + 0.02 + layer * LAYER_STEP, center.z)
    add_child(bundle)
    return bundle

## Alguns maços sobem da pilha até o fazendeiro e somem (só visual).
func _fly_to(from: Vector3, to: Vector3, count: int) -> void:
    if not is_inside_tree():
        return
    for index in count:
        var bill := MeshInstance3D.new()
        bill.name = "CollectedMoney"
        bill.mesh = _bundle_mesh
        bill.material_override = _bundle_material
        bill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        bill.top_level = true
        add_child(bill)
        bill.global_position = from + Vector3(0.0, index * LAYER_STEP, 0.0)
        bill.rotation_degrees.x = -90.0
        var tween := create_tween()
        tween.tween_interval(index * 0.05)
        tween.tween_property(bill, "global_position", to, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.parallel().tween_property(bill, "scale", Vector3.ONE * 0.35, 0.3)
        tween.tween_callback(bill.queue_free)

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
