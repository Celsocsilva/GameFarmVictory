extends Node3D
class_name CustomerQueue
## Fila dupla de clientes atrás da bancada (lado +Z, voltado para a cerca).
## Adicione como filho direto de FarmWorld e chame setup(bancada, borda_z).
## Um cliente novo surge a cada min_interval..max_interval segundos (sorteado),
## até max_customers clientes diferentes (na fila + fora esperando para voltar).
## Com o limite atingido o relógio para; quando um cliente é atendido
## (release_front), um novo intervalo completo é sorteado.
## Cada cliente espera min_patience..max_patience s no lugar; sem atendimento,
## sai pela lateral, some e volta após min_away..max_away s para o fim da fila
## mais curta. Os de trás andam um lugar quando alguém sai.

signal customer_spawned(customer: Customer, elapsed: float)
signal customer_released(customer: Customer)
signal customer_left(customer: Customer, waited: float)
signal customer_returned(customer: Customer, away: float)

const LANES := 2
const SLOTS_PER_LANE := 7

@export_range(1.0, 60.0, 0.5) var min_interval: float = 10.0
@export_range(1.0, 60.0, 0.5) var max_interval: float = 15.0
@export_range(1, 14, 1) var max_customers: int = 5
@export_range(1.0, 60.0, 0.5) var min_patience: float = 15.0
@export_range(1.0, 60.0, 0.5) var max_patience: float = 20.0
@export_range(1.0, 60.0, 0.5) var min_away: float = 15.0
@export_range(1.0, 60.0, 0.5) var max_away: float = 20.0
## Passo lateral para sair da fila sem atravessar os de trás.
@export var exit_side_step: float = 1.4
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
## Registro para testes: {"customer", "at", "waited"} e {"customer", "at", "away"}.
var leave_log: Array[Dictionary] = []
var return_log: Array[Dictionary] = []
var _lanes: Array = []
var _away: Array[Customer] = []
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

## Clientes diferentes existentes: na fila + fora aguardando para voltar.
func get_total_customers() -> int:
    return get_customer_count() + _away.size()

func get_away_customers() -> Array[Customer]:
    return _away.duplicate()

func get_lane(lane: int) -> Array[Customer]:
    var result: Array[Customer] = []
    result.assign(_lanes[lane])
    return result

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

## Avança relógios de chegada, paciência e volta. Separado de _process para
## testes determinísticos (o movimento fica em Customer.step).
func tick(delta: float) -> void:
    _elapsed += delta
    _tick_patience(delta)
    _tick_away(delta)
    if get_total_customers() >= max_customers:
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

func _tick_patience(delta: float) -> void:
    for customer in get_customers():
        if not customer.has_arrived:
            continue
        if not customer.has_meta("arrived_at"):
            customer.set_meta("arrived_at", _elapsed - delta)
        customer.patience_left -= delta
        if customer.patience_left <= 0.0:
            _leave_impatient(customer)

func _tick_away(delta: float) -> void:
    for customer in _away.duplicate():
        customer.away_left -= delta
        if customer.away_left <= 0.0 and get_customer_count() < get_capacity():
            _return_customer(customer)

## Sem atendimento: sai pela lateral externa da fila, some e agenda a volta.
func _leave_impatient(customer: Customer) -> void:
    var waited := _elapsed - (customer.get_meta("arrived_at", _elapsed) as float)
    _remove_from_lane(customer)
    customer.is_leaving = true
    customer.hide_on_exit = true
    var outward := signf(get_slot_position(customer.lane, 0).x + 0.01)
    var side := Vector3(customer.position.x + outward * exit_side_step, 0.0, customer.position.z)
    var exit := Vector3(side.x, 0.0, _spawn_local_z)
    var path: Array[Vector3] = [side, exit]
    customer.walk_path(path)
    customer.away_left = rng.randf_range(min_away, max_away)
    customer.set_meta("left_at", _elapsed)
    _away.append(customer)
    leave_log.append({"customer": customer, "at": _elapsed, "waited": waited})
    customer_left.emit(customer, waited)

func _return_customer(customer: Customer) -> void:
    _away.erase(customer)
    var away := _elapsed - (customer.get_meta("left_at", _elapsed) as float)
    customer.is_leaving = false
    customer.hide_on_exit = false
    customer.visible = true
    _enqueue(customer)
    return_log.append({"customer": customer, "at": _elapsed, "away": away})
    customer_returned.emit(customer, away)

## Coloca o cliente no fim da fila mais curta, entrando pela cerca.
func _enqueue(customer: Customer) -> void:
    var lane := 0 if get_lane_count(0) <= get_lane_count(1) else 1
    customer.lane = lane
    customer.slot = get_lane_count(lane)
    customer.has_arrived = false
    customer.remove_meta("arrived_at")
    customer.patience_left = rng.randf_range(min_patience, max_patience)
    (_lanes[lane] as Array).append(customer)
    customer.position = get_spawn_position(lane)
    customer.rotation.y = 0.0
    customer.walk_to(get_slot_position(lane, customer.slot))

func _remove_from_lane(customer: Customer) -> void:
    var queue: Array = _lanes[customer.lane]
    queue.erase(customer)
    for index in queue.size():
        var waiting: Customer = queue[index]
        if waiting.slot != index:
            waiting.slot = index
            waiting.walk_to(get_slot_position(customer.lane, index))

## Cria um cliente na fila mais curta. force ignora max_customers (pré-visualização),
## mas nunca passa da capacidade física de 2 x 7 lugares.
func spawn_customer(force: bool = false) -> Customer:
    if get_customer_count() >= get_capacity():
        return null
    if not force and get_total_customers() >= max_customers:
        return null
    var customer := Customer.create(_next_scheme)
    _next_scheme = (_next_scheme + 1 + rng.randi_range(0, 1)) % Customer.COLOR_SCHEMES.size()
    customer.name = "Customer_%03d" % spawn_times.size()
    add_child(customer)
    _enqueue(customer)
    spawn_times.append(_elapsed)
    customer_spawned.emit(customer, _elapsed)
    return customer

## Retira o primeiro cliente de uma fila (atendimento futuro). Os de trás andam um lugar.
func release_front(lane: int) -> Customer:
    var queue: Array = _lanes[lane]
    if queue.is_empty():
        return null
    var customer: Customer = queue[0]
    _remove_from_lane(customer)
    customer.is_leaving = true
    var outward := signf(get_slot_position(lane, 0).x + 0.01)
    var side := Vector3(customer.position.x + outward * exit_side_step, 0.0, customer.position.z)
    var path: Array[Vector3] = [side, Vector3(side.x, 0.0, _spawn_local_z)]
    customer.walk_path(path)
    customer_released.emit(customer)
    return customer

func snap_all_to_targets() -> void:
    for customer in get_customers():
        customer.snap_to_target()

func _schedule_next() -> void:
    _time_to_next = rng.randf_range(min_interval, max_interval)
