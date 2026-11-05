extends Control
class_name VirtualJoystick

@export var dead_zone: float = 0.12
@export var radius: float = 82.0
var _touch_id: int = -1
var _output := Vector2.ZERO
var _knob := Vector2.ZERO

func _ready() -> void:
    custom_minimum_size = Vector2(220, 220)
    queue_redraw()

func get_output() -> Vector2:
    return _output

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and _touch_id == -1:
            _touch_id = event.index
            _update_from_position(event.position)
        elif not event.pressed and event.index == _touch_id:
            _release()
    elif event is InputEventScreenDrag and event.index == _touch_id:
        _update_from_position(event.position)

func _update_from_position(position: Vector2) -> void:
    var center := size * 0.5
    var offset := position - center
    var distance := min(offset.length(), radius)
    _knob = offset.normalized() * distance if distance > 0.001 else Vector2.ZERO
    var normalized := _knob / radius
    _output = Vector2.ZERO if normalized.length() < dead_zone else normalized
    queue_redraw()

func _release() -> void:
    _touch_id = -1
    _output = Vector2.ZERO
    _knob = Vector2.ZERO
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    draw_circle(center, radius, Color(0.08, 0.12, 0.18, 0.42))
    draw_circle(center + _knob, radius * 0.38, Color(0.35, 0.62, 0.95, 0.82))
