extends Node3D

const SEED_THROW_SCENE := preload("res://scenes/vfx/SeedThrow.tscn")
@export var origin := Vector3(-2.0, 1.5, 0.0)
@export var target := Vector3(2.0, 0.12, 0.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
        var seed_throw := SEED_THROW_SCENE.instantiate() as SeedThrow
        add_child(seed_throw)
        seed_throw.launch(origin, target)
