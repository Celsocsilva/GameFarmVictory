extends Node3D
class_name Customer
## Cliente da bancada: cópia visual do fazendeiro (mesmos meshes da cena
## farmer.tscn) com outro esquema de cores. Não tem script de controle nem
## colisão; só caminha até o lugar da fila definido pela CustomerQueue.

signal arrived(customer: Customer)

const FARMER_SCENE := preload("res://scenes/player/farmer.tscn")

## Esquemas alternativos: corpo (roupa) e detalhe frontal (chapéu/rosto).
## Nenhum repete o azul do fazendeiro.
const COLOR_SCHEMES: Array[Dictionary] = [
    {"name": "tomate", "body": Color(0.80, 0.22, 0.18), "accent": Color(0.96, 0.86, 0.62)},
    {"name": "horta", "body": Color(0.22, 0.60, 0.28), "accent": Color(0.98, 0.80, 0.25)},
    {"name": "uva", "body": Color(0.55, 0.30, 0.70), "accent": Color(0.98, 0.66, 0.76)},
    {"name": "abobora", "body": Color(0.95, 0.55, 0.15), "accent": Color(0.45, 0.28, 0.14)},
    {"name": "lago", "body": Color(0.13, 0.64, 0.66), "accent": Color(0.96, 0.96, 0.92)},
    {"name": "flor", "body": Color(0.90, 0.40, 0.62), "accent": Color(0.58, 0.80, 0.98)},
    {"name": "trigo", "body": Color(0.86, 0.74, 0.36), "accent": Color(0.36, 0.22, 0.12)},
]

@export var walk_speed: float = 2.6
## Distância em que o cliente considera ter chegado ao lugar.
const ARRIVE_EPSILON := 0.03

var color_scheme_index := 0
var lane := -1
var slot := -1
var is_leaving := false
## Saída por impaciência: some ao chegar à saída e depois volta (não é liberado).
var hide_on_exit := false
## Chegou ao lugar da fila ao menos uma vez desde que entrou nela.
var has_arrived := false
## Segundos de espera restantes na fila (contam após a primeira chegada ao lugar).
var patience_left := 0.0
## Segundos restantes até voltar, enquanto está fora.
var away_left := 0.0
var _path: Array[Vector3] = []
var _target := Vector3.ZERO
var _walking := false
var _walk_time := 0.0

## Monta o cliente copiando os MeshInstance3D do fazendeiro e recolorindo-os.
static func create(scheme_index: int) -> Customer:
    var customer := Customer.new()
    customer.color_scheme_index = posmod(scheme_index, COLOR_SCHEMES.size())
    var scheme: Dictionary = COLOR_SCHEMES[customer.color_scheme_index]
    var template := FARMER_SCENE.instantiate()
    for child in template.get_children():
        if child is MeshInstance3D:
            var copy := (child as MeshInstance3D).duplicate() as MeshInstance3D
            var color: Color = scheme["accent"] if child.name == "FrontMarker" else scheme["body"]
            var material := StandardMaterial3D.new()
            var source := (child as MeshInstance3D).material_override as StandardMaterial3D
            if source:
                material = source.duplicate() as StandardMaterial3D
            material.albedo_color = color
            copy.material_override = material
            customer.add_child(copy)
    template.free()
    return customer

## Caixas compradas no balcão, levadas à frente do corpo (frente é -Z local).
func carry_crates(count: int) -> void:
    var old := get_node_or_null("CarriedCrates")
    if old:
        old.free()
    if count <= 0:
        return
    var holder := Node3D.new()
    holder.name = "CarriedCrates"
    holder.position = Vector3(0.0, 0.9, -0.68)
    add_child(holder)
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.58, 0.32, 0.12)
    var tomato := StandardMaterial3D.new()
    tomato.albedo_color = Color(0.82, 0.10, 0.055)
    var box := BoxMesh.new()
    box.size = Vector3(0.62, 0.24, 0.46)
    var fruit := BoxMesh.new()
    fruit.size = Vector3(0.52, 0.06, 0.36)
    for index in count:
        var crate := MeshInstance3D.new()
        crate.name = "Crate_%d" % index
        crate.mesh = box
        crate.material_override = wood
        crate.position.y = index * 0.27
        holder.add_child(crate)
        var top := MeshInstance3D.new()
        top.mesh = fruit
        top.material_override = tomato
        top.position.y = 0.14
        crate.add_child(top)

func get_carried_crates() -> int:
    var holder := get_node_or_null("CarriedCrates")
    return holder.get_child_count() if holder else 0

func get_body_color() -> Color:
    return COLOR_SCHEMES[color_scheme_index]["body"]

func walk_to(target: Vector3) -> void:
    _path.clear()
    _target = target
    _walking = position.distance_to(_target) > ARRIVE_EPSILON
    if not _walking:
        _finish_walk()

## Caminha por pontos intermediários (sair da fila pela lateral sem atravessar ninguém).
func walk_path(points: Array[Vector3]) -> void:
    if points.is_empty():
        return
    var rest := points.duplicate()
    var first: Vector3 = rest.pop_front()
    walk_to(first)
    _path.assign(rest)

func is_away() -> bool:
    return is_leaving and hide_on_exit and not visible

func is_walking() -> bool:
    return _walking

func get_target() -> Vector3:
    return _target

## Coloca o cliente direto no lugar (capturas e testes).
func snap_to_target() -> void:
    if not _path.is_empty():
        _target = _path[_path.size() - 1]
        _path.clear()
    position = _target
    _finish_walk()

func _process(delta: float) -> void:
    step(delta)

func step(delta: float) -> void:
    if not _walking:
        return
    var to_target := _target - position
    to_target.y = 0.0
    var distance := to_target.length()
    var advance := walk_speed * delta
    if distance <= maxf(advance, ARRIVE_EPSILON):
        position = _target
        if not _path.is_empty():
            _target = _path.pop_front()
            return
        _finish_walk()
        return
    var direction := to_target / distance
    position += direction * advance
    # Frente do modelo é -Z local, igual ao fazendeiro.
    rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 10.0))
    _walk_time += delta
    position.y = _target.y + absf(sin(_walk_time * 9.0)) * 0.08

func _finish_walk() -> void:
    _walking = false
    position.y = _target.y
    if is_leaving:
        if hide_on_exit:
            visible = false
        else:
            queue_free()
        return
    has_arrived = true
    # Na fila, todos olham para a bancada (-Z do mundo).
    rotation.y = 0.0
    arrived.emit(self)
