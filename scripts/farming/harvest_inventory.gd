extends Node
class_name HarvestInventory
## Carga transportada na mochila do fazendeiro (FV-HARVEST-001).
##
## A capacidade é medida em caixas: `max_crates * units_per_crate`. Toda coleta
## passa por uma reserva transacional: a capacidade é reservada antes do VFX,
## confirmada unidade a unidade na chegada e devolvida em cancelamento. Assim a
## animação nunca cria nem perde tomates.

signal amount_changed(item_id: StringName, amount: int)
signal crate_filled(crate_index: int)
signal backpack_full()

## Item único por enquanto; a mochila aceita só uma cultura por vez.
const DEFAULT_ITEM := &"tomato"

@export_range(1, 7, 1) var max_crates: int = 7
@export_range(1, 64, 1) var units_per_crate: int = 8

var _amounts: Dictionary = {}
var _reservations: Dictionary = {}
var _next_reservation_id := 1

## Reserva aberta. `amount` é o total reservado; `committed` o já confirmado.
class Reservation:
    extends RefCounted
    var id := 0
    var item_id: StringName = &""
    var amount := 0
    var committed := 0

    func pending() -> int:
        return amount - committed

    func is_valid() -> bool:
        return id > 0 and amount > 0

func get_capacity() -> int:
    return max_crates * units_per_crate

func get_amount(item_id: StringName = DEFAULT_ITEM) -> int:
    return int(_amounts.get(item_id, 0))

func get_total() -> int:
    var total := 0
    for value in _amounts.values():
        total += int(value)
    return total

func get_reserved_total() -> int:
    var total := 0
    for reservation in _reservations.values():
        total += (reservation as Reservation).pending()
    return total

## Espaço livre considerando o que já está voando para a mochila.
func get_free_capacity() -> int:
    return maxi(0, get_capacity() - get_total() - get_reserved_total())

func is_full() -> bool:
    return get_total() >= get_capacity()

func get_pending_reservation_count() -> int:
    return _reservations.size()

## Caixas visíveis: ceil(total / units_per_crate), limitado a max_crates.
func get_crate_count() -> int:
    return mini(max_crates, int(ceil(float(get_total()) / float(units_per_crate))))

func get_full_crate_count() -> int:
    return mini(max_crates, get_total() / units_per_crate)

## Reserva até `amount` unidades. Retorna uma reserva inválida (amount 0) se não
## houver espaço; nunca reserva além da capacidade livre.
func try_reserve(item_id: StringName, amount: int) -> Reservation:
    var reservation := Reservation.new()
    reservation.item_id = item_id
    reservation.amount = mini(maxi(amount, 0), get_free_capacity())
    if reservation.amount <= 0:
        reservation.amount = 0
        return reservation
    reservation.id = _next_reservation_id
    _next_reservation_id += 1
    _reservations[reservation.id] = reservation
    return reservation

## Confirma `amount` unidades de uma reserva aberta (limitado ao pendente).
## Retorna quantas unidades entraram de fato no inventário.
func commit(reservation: Reservation, amount: int = -1) -> int:
    if reservation == null or not _reservations.has(reservation.id):
        return 0
    var units := reservation.pending() if amount < 0 else mini(amount, reservation.pending())
    if units <= 0:
        return 0
    var crates_before := get_full_crate_count()
    reservation.committed += units
    _amounts[reservation.item_id] = get_amount(reservation.item_id) + units
    if reservation.pending() <= 0:
        _reservations.erase(reservation.id)
    amount_changed.emit(reservation.item_id, get_amount(reservation.item_id))
    for crate_index in range(crates_before, get_full_crate_count()):
        crate_filled.emit(crate_index)
    if is_full():
        backpack_full.emit()
    return units

## Devolve a parte ainda não confirmada. Retorna quantas unidades foram liberadas.
func cancel(reservation: Reservation) -> int:
    if reservation == null or not _reservations.has(reservation.id):
        return 0
    var released := reservation.pending()
    _reservations.erase(reservation.id)
    return released

## Retirada para a futura bancada. Nunca deixa estoque negativo.
func remove(item_id: StringName, amount: int) -> int:
    var removed := mini(maxi(amount, 0), get_amount(item_id))
    if removed > 0:
        _amounts[item_id] = get_amount(item_id) - removed
        amount_changed.emit(item_id, get_amount(item_id))
    return removed

## Estado definido diretamente (testes, carga de save). Ignora reservas abertas.
func set_amount(item_id: StringName, amount: int) -> void:
    _amounts[item_id] = clampi(amount, 0, get_capacity())
    amount_changed.emit(item_id, get_amount(item_id))

## Reservas pendentes não são persistidas: o fruto ainda está na planta.
func to_dict() -> Dictionary:
    var amounts := {}
    for key in _amounts:
        amounts[String(key)] = int(_amounts[key])
    return {"version": 1, "amounts": amounts}

func from_dict(data: Dictionary) -> void:
    _amounts.clear()
    _reservations.clear()
    var amounts: Dictionary = data.get("amounts", {})
    for key in amounts:
        _amounts[StringName(key)] = clampi(int(amounts[key]), 0, get_capacity())
    for key in _amounts:
        amount_changed.emit(key, get_amount(key))
