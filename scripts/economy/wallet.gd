extends Node
class_name Wallet
## Saldo do fazendeiro: o dinheiro recolhido das pilhas da base de dinheiro.
## É o estado reutilizável da economia: ferramentas, recursos e aceleração
## (etapas futuras) gastam daqui com can_afford()/spend(). set_balance() serve
## para restaurar um save.

signal balance_changed(balance: int, delta: int)

var _balance := 0
## Registro para testes: {"amount", "source"} de cada entrada/saída.
var history: Array[Dictionary] = []

func get_balance() -> int:
    return _balance

func add(amount: int, source: StringName = &"") -> void:
    if amount <= 0:
        return
    _balance += amount
    history.append({"amount": amount, "source": source})
    balance_changed.emit(_balance, amount)

func can_afford(amount: int) -> bool:
    return amount >= 0 and amount <= _balance

## Gasta saldo (compras futuras). Retorna false, sem gastar, se não houver saldo.
func spend(amount: int, reason: StringName = &"") -> bool:
    if amount <= 0 or amount > _balance:
        return false
    _balance -= amount
    history.append({"amount": -amount, "source": reason})
    balance_changed.emit(_balance, -amount)
    return true

## Restauração de save.
func set_balance(value: int) -> void:
    var target := maxi(value, 0)
    var delta := target - _balance
    _balance = target
    if delta != 0:
        balance_changed.emit(_balance, delta)
