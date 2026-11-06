extends Node3D
class_name CustomerQueue
## Fila dupla de clientes atrás da bancada (lado +Z, voltado para a cerca).
## Adicione como filho direto de FarmWorld e chame setup(bancada, borda_z).
## Um cliente novo surge a cada min_interval..max_interval segundos (sorteado),
## até max_customers acumulados. Com a fila no limite o relógio para; quando
## um cliente sai, um novo intervalo completo é sorteado.

signal customer_spawned(customer: Customer, elapsed: float)
signal customer_released(customer: Customer)

const LANES := 2
const SLOTS_PER_LANE := 7

@export_range(1.0, 60.0, 0.5) var min_interval: float = 10.0
@export_range(1.0, 60.0, 0.5) var max_interval: float = 15.0
@export_range(1, 14, 1) var max_customers: int = 5
## Distância em X entre o centro das duas filas.
@export var lane_spacing: float = 2.0
## Distância em Z entre clientes da mesma fila.
@export var slot_spacing: float = 1.15
## Primeiro lugar, medido a partir do centro da bancada (+Z).
@export var first_slot_offset: float = 2.3
## Folga entre o ponto de surgimento e a cerca.
@export var spawn_edge_margin: float = 0.8

var rng := RandomNumberGenerator.new()
## Instantes (s desde o início) em que cada cliente surgiu.
var spawn_times: Array[float] = []
var _lanes: Array = []
var _elapsed := 0.0
var _time_to_next := 0.0
var _paused_full := false
var _spawn_local_z := 0.0
var _next_scheme := 0

func _ready() -> void:
    _lanes.clear()
    for lane in LANES:
        _lanes.append([])
    rng.randomize()
    _next_scheme = rng.randi_range(0, Customer.COLOR_SCHEMES.size() - 1)
    _schedule_next()

## Alinha a fila atrás da bancada; edge_z é a borda +Z do terreno (mundo).
func setup(depot: Node3D, edge_z: float) -> void:
    global_position = Vector3(depot.global_position.x, 0.0, depot.global_position.z)
    _spawn_local_z = minf(get_slot_position(0, SLOTS_PER_LANE - 1).z + 1.8, edge_z - spawn_edge_margin - global_position.z)

## Reinicia o sorteio com semente fixa (testes reprodutíveis).
func set_seed(value: int) -> void:
    rng.seed = value
    _next_scheme = rng.randi_range(0, Customer.COLOR_SCHEMES.size() - 1)
    _schedule_next()

func get_capacity() -> int:
    return LANES * SLOTS_PER_LANE

func get_customer_count() -> int:
    var total := 0
    for lane in _lanes:
        total += (lane as Array).size()
    return total

func get_lane_count(lane: int) -> int:
    return (_lanes[lane] as Array).size()

func get_customers() -> Array[Customer]:
    var result: Array[Customer] = []
    for lane in _lanes:
        for customer in lane:
            result.append(customer)
    return result

func get_elapsed() -> float:
    return _elapsed

func get_time_to_next() -> float:
    return _time_to_next

func is_paused_full() -> bool:
    return _paused_full

## Posição local de um lugar da fila; lugar 0 é o mais perto da bancada.
func get_slot_position(lane: int, slot: int) -> Vector3:
    var x := (lane - (LANES - 1) * 0.5) * lane_spacing
    return Vector3(x, 0.0, first_slot_offset + slot * slot_spacing)

func get_spawn_position(lane: int) -> Vector3:
    return Vector3(get_slot_position(lane, 0).x, 0.0, _spawn_local_z)

func _process(delta: float) -> void:
    tick(delta)

## Avança o relógio de chegada. Separado de _process para testes determinísticos.
func tick(delta: float) -> void:
    _elapsed += delta
    if get_customer_count() >= max_customers:
        _paused_full = true
        return
    if _paused_full:
        # Abriu vaga: conta um intervalo completo a partir de agora.
        _paused_full = false
        _schedule_next()
    _time_to_next -= delta
    if _time_to_next <= 0.0:
        spawn_customer()
        _schedule_next()

## Cria um cliente na fila mais curta. force ignora max_customers (pré-visualização),
## mas nunca passa da capacidade física de 2 x 7 lugares.
func spawn_customer(force: bool = false) -> Customer:
    if get_customer_count() >= get_capacity():
        return null
    if not force and get_customer_count() >= max_customers:
        return null
    var lane := 0 if get_lane_count(0) <= get_lane_count(1) else 1
    var customer := Customer.create(_next_scheme)
    _next_scheme = (_next_scheme + 1 + rng.randi_range(0, 1)) % Customer.COLOR_SCHEMES.size()
    customer.name = "Customer_%03d" % spawn_times.size()
    customer.lane = lane
    customer.slot = get_lane_count(lane)
    (_lanes[lane] as Array).append(customer)
    add_child(customer)
    customer.position = get_spawn_position(lane)
    customer.walk_to(get_slot_position(lane, customer.slot))
    spawn_times.append(_elapsed)
    customer_spawned.emit(customer, _elapsed)
    return customer

## Retira o primeiro cliente de uma fila (atendimento futuro). Os de trás andam um lugar.
func release_front(lane: int) -> Customer:
    var queue: Array = _lanes[lane]
    if queue.is_empty():
        return null
    var customer: Customer = queue.pop_front()
    for index in queue.size():
        var waiting: Customer = queue[index]
        waiting.slot = index
        waiting.walk_to(get_slot_position(lane, index))
    customer.is_leaving = true
    customer.walk_to(get_spawn_position(lane) + Vector3(signf(customer.position.x + 0.01) * 3.0, 0.0, 0.0))
    customer_released.emit(customer)
    return customer

func snap_all_to_targets() -> void:
    for customer in get_customers():
        customer.snap_to_target()

func _schedule_next() -> void:
    _time_to_next = rng.randf_range(min_interval, max_interval)
