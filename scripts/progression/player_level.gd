extends Node
class_name PlayerLevel
## Nível e experiência do fazendeiro. Cada tomate vendido no balcão vale
## ProgressionConfig.XP_PER_TOMATO_SOLD XP; o XP pedido por nível vem de
## ProgressionConfig.xp_for_level() (com o multiplicador de dificuldade).

signal changed(level: int, xp: int, xp_to_next: int)
signal leveled_up(level: int)


var level := 1
var xp := 0

func xp_to_next(for_level: int = -1) -> int:
    var target_level := level if for_level < 1 else for_level
    return ProgressionConfig.xp_for_level(target_level)

func add_xp(amount: int) -> void:
    if amount <= 0:
        return
    xp += amount
    while xp >= xp_to_next():
        xp -= xp_to_next()
        level += 1
        leveled_up.emit(level)
    changed.emit(level, xp, xp_to_next())

func to_dict() -> Dictionary:
    return {"version": 1, "level": level, "xp": xp}

func from_dict(data: Dictionary) -> void:
    level = maxi(1, int(data.get("level", 1)))
    xp = clampi(int(data.get("xp", 0)), 0, xp_to_next() - 1)
    changed.emit(level, xp, xp_to_next())
