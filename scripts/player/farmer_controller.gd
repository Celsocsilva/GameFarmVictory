extends CharacterBody3D
class_name FarmerController

@export var move_speed: float = 4.0
@export var acceleration: float = 18.0
@export var deceleration: float = 24.0
@export var joystick_path: NodePath = NodePath("../HUD/VirtualJoystick")

var _joystick: Control
var _camera: Camera3D

func _ready() -> void:
    _camera = get_viewport().get_camera_3d()
    _joystick = get_node_or_null(joystick_path)

func _physics_process(delta: float) -> void:
    if _joystick == null:
        _joystick = get_node_or_null("../HUD/VirtualJoystick")
    var input_vector := _read_input()
    var target := Vector3(input_vector.x, 0.0, input_vector.y) * move_speed
    var rate := acceleration if input_vector.length_squared() > 0.001 else deceleration
    velocity.x = move_toward(velocity.x, target.x, rate * delta)
    velocity.z = move_toward(velocity.z, target.z, rate * delta)
    velocity.y = 0.0
    if input_vector.length_squared() > 0.001:
        var facing := Vector3(input_vector.x, 0.0, input_vector.y)
        rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), min(1.0, delta * 12.0))
    move_and_slide()

func _read_input() -> Vector2:
    var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if keyboard.length_squared() > 0.001:
        return keyboard
    if _joystick and _joystick.has_method("get_output"):
        return _joystick.get_output()
    return Vector2.ZERO
