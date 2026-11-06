extends Node3D
class_name BackpackCrates
## Pilha dinâmica de caixas nas costas do fazendeiro (FV-HARVEST-001).
##
## Montada repetindo `crate_empty.png` (caixa parcial, com mini tomates
## sobrepostos) e `crate_full.png` (caixa completa). Nunca usa a imagem de
## referência de sete caixas. As caixas são visuais: não colidem com o jogador.
##
## Hierarquia criada em runtime:
##   BackpackCrates (filho do fazendeiro, nas costas)
##     BackpackStackRoot   — base da pilha
##       Crate_0..Crate_6  — top_level, sempre voltadas para a câmera
##     HarvestIntakeMarker — destino móvel dos frutos sugados (topo da pilha)

const CRATE_EMPTY_TEXTURE := preload("res://assets/harvest/crate_empty.png")
const CRATE_FULL_TEXTURE := preload("res://assets/harvest/crate_full.png")
const TOMATO_TEXTURE := preload("res://assets/harvest/tomato_ripe.png")

## Posições (px no PNG da caixa vazia, origem no canto superior esquerdo) dos
## mini tomates da caixa parcial, na ordem em que vão sendo preenchidos.
const PARTIAL_SLOTS := [
    Vector2(185, 172), Vector2(255, 155), Vector2(320, 138), Vector2(215, 132),
    Vector2(285, 116), Vector2(150, 140), Vector2(345, 160)
]

@export var item_id: StringName = &"tomato"
@export_range(1, 7, 1) var max_crates: int = 7
@export_range(1, 64, 1) var units_per_crate: int = 8
## Largura de cada caixa em unidades do mundo.
@export_range(0.3, 1.5, 0.01) var crate_width: float = 1.0
## Subida no eixo Y do mundo entre caixas empilhadas.
@export_range(0.1, 1.0, 0.01) var crate_step: float = 0.5
@export_range(0.05, 0.4, 0.01) var mini_tomato_size: float = 0.22

var stack_root: Node3D
var intake_marker: Marker3D
var _crates: Array[Node3D] = []
var _amount := 0
var _camera: Camera3D

func _ready() -> void:
    stack_root = Node3D.new()
    stack_root.name = "BackpackStackRoot"
    add_child(stack_root)
    intake_marker = Marker3D.new()
    intake_marker.name = "HarvestIntakeMarker"
    add_child(intake_marker)
    for index in max_crates:
        _crates.append(_build_crate(index))
    _refresh(false)

func _process(_delta: float) -> void:
    _orient_crates()

func get_amount() -> int:
    return _amount

func get_visible_crate_count() -> int:
    var count := 0
    for crate in _crates:
        if crate.visible:
            count += 1
    return count

func get_full_crate_count() -> int:
    var count := 0
    for crate in _crates:
        if crate.visible and crate.get_meta("full", false):
            count += 1
    return count

## Mini tomates visíveis na caixa parcial do topo (0 se não houver parcial).
func get_partial_fill() -> int:
    var remainder := _amount % units_per_crate
    return remainder if _amount < max_crates * units_per_crate else 0

## Contrato do FV-HARVEST-001. Atualiza a pilha de forma incremental.
func set_amount(new_item_id: StringName, amount: int) -> void:
    if new_item_id != item_id:
        return
    var previous := _amount
    _amount = clampi(amount, 0, max_crates * units_per_crate)
    _refresh(_amount != previous)

func _refresh(animate: bool) -> void:
    var crate_count := mini(max_crates, int(ceil(float(_amount) / float(units_per_crate))))
    var full_count := mini(max_crates, _amount / units_per_crate)
    for index in _crates.size():
        var crate := _crates[index]
        var was_visible := crate.visible
        var was_full: bool = crate.get_meta("full", false)
        var visible_now := index < crate_count
        var full_now := index < full_count
        crate.visible = visible_now
        crate.set_meta("full", full_now)
        var sprite := crate.get_node("CrateSprite") as Sprite3D
        sprite.texture = CRATE_FULL_TEXTURE if full_now else CRATE_EMPTY_TEXTURE
        sprite.pixel_size = crate_width / float(sprite.texture.get_width())
        sprite.offset = Vector2(-sprite.texture.get_width() * 0.5, 0.0)
        var fill := 0 if full_now or not visible_now else _amount - index * units_per_crate
        var minis := crate.get_node("PartialFill")
        for slot in minis.get_child_count():
            var mini_sprite := minis.get_child(slot) as Sprite3D
            var show := slot < fill
            if show and not mini_sprite.visible and animate:
                _pop(mini_sprite, 0.16)
            mini_sprite.visible = show
        if animate and visible_now and (not was_visible or full_now != was_full):
            _pop(sprite, 0.22)
    # Destino dos frutos: logo acima da caixa que está recebendo tomates.
    var receiving := mini(crate_count, max_crates - 1) if _amount % units_per_crate == 0 else crate_count - 1
    intake_marker.position = Vector3(0.0, maxi(receiving, 0) * crate_step + crate_width * 0.55, 0.0)
    _orient_crates()

func _orient_crates() -> void:
    if _camera == null or not is_instance_valid(_camera):
        _camera = get_viewport().get_camera_3d() if is_inside_tree() else null
    var basis := _crate_basis()
    for index in _crates.size():
        var crate := _crates[index]
        # Pilha vertical no mundo, ancorada nas costas. As caixas mais altas ficam
        # mais perto da câmera e cobrem o interior da caixa de baixo.
        crate.global_transform = Transform3D(basis, stack_root.global_position + Vector3.UP * index * crate_step)

## Plano vertical virado para a câmera (billboard só no eixo Y), para não cortar o
## corpo do fazendeiro. A altura é compensada pela inclinação da câmera, como
## na tira de solo, para a arte aparecer na proporção original.
func _crate_basis() -> Basis:
    if _camera == null:
        return Basis.IDENTITY
    var toward := _camera.global_basis.z
    toward.y = 0.0
    if toward.length() < 0.001:
        return _camera.global_basis
    toward = toward.normalized()
    var right := Vector3.UP.cross(toward).normalized()
    var stretch := 1.0 / maxf(0.3, _camera.global_basis.y.y)
    return Basis(right, Vector3.UP * stretch, toward)

func _build_crate(index: int) -> Node3D:
    var crate := Node3D.new()
    crate.name = "Crate_%d" % index
    crate.top_level = true
    crate.visible = false
    crate.set_meta("full", false)
    stack_root.add_child(crate)
    var sprite := _make_sprite(CRATE_EMPTY_TEXTURE, crate_width / float(CRATE_EMPTY_TEXTURE.get_width()))
    sprite.name = "CrateSprite"
    sprite.centered = false
    sprite.offset = Vector2(-CRATE_EMPTY_TEXTURE.get_width() * 0.5, 0.0)
    # Cada caixa um pouco acima na ordem de desenho que a de baixo.
    sprite.render_priority = index
    crate.add_child(sprite)
    var minis := Node3D.new()
    minis.name = "PartialFill"
    crate.add_child(minis)
    var crate_pixel := crate_width / float(CRATE_EMPTY_TEXTURE.get_width())
    var size := Vector2(CRATE_EMPTY_TEXTURE.get_size())
    for slot in mini(PARTIAL_SLOTS.size(), units_per_crate - 1):
        var mini_sprite := _make_sprite(TOMATO_TEXTURE, mini_tomato_size / float(TOMATO_TEXTURE.get_height()))
        mini_sprite.name = "MiniTomato_%d" % slot
        mini_sprite.render_priority = index
        var px: Vector2 = PARTIAL_SLOTS[slot]
        # PNG: y para baixo a partir do topo; sprite: base em y = 0, centro em x.
        mini_sprite.position = Vector3((px.x - size.x * 0.5) * crate_pixel, (size.y - px.y) * crate_pixel, 0.01 + slot * 0.001)
        mini_sprite.visible = false
        minis.add_child(mini_sprite)
    return crate

func _make_sprite(texture: Texture2D, pixel_size: float) -> Sprite3D:
    var sprite := Sprite3D.new()
    sprite.texture = texture
    sprite.pixel_size = pixel_size
    sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    sprite.shaded = false
    sprite.double_sided = true
    # Recorte com descarte (como as plantas): escreve profundidade de forma
    # estável entre caixas e mini tomates sobrepostos.
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    sprite.alpha_scissor_threshold = 0.5
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return sprite

func _pop(node: Node3D, duration: float) -> void:
    node.scale = Vector3.ONE * 0.6
    var tween := create_tween()
    tween.tween_property(node, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
