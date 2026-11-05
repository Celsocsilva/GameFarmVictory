extends Node3D
class_name FarmWorld

const FARM_SIZE := 24.0
const JOYSTICK_SCENE := preload("res://scenes/ui/virtual_joystick.tscn")

@onready var farmer: FarmerController = $Farmer
var camera: Camera3D

func _ready() -> void:
    _build_environment()
    _build_ground()
    _build_obstacles()
    _build_camera()
    _build_hud()

func _process(delta: float) -> void:
    if camera and farmer:
        var desired := farmer.global_position + Vector3(0.0, 13.0, 13.0)
        camera.global_position = camera.global_position.lerp(desired, min(1.0, delta * 5.0))
        camera.look_at(farmer.global_position, Vector3.UP)

func _build_environment() -> void:
    var environment := WorldEnvironment.new()
    var resource := Environment.new()
    resource.background_mode = Environment.BG_COLOR
    resource.background_color = Color(0.52, 0.73, 0.92)
    resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    resource.ambient_light_color = Color(0.72, 0.82, 1.0)
    resource.ambient_light_energy = 0.7
    environment.environment = resource
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    add_child(sun)

func _build_ground() -> void:
    var body := StaticBody3D.new()
    body.name = "Ground"
    var mesh := MeshInstance3D.new()
    var plane := BoxMesh.new()
    plane.size = Vector3(FARM_SIZE, 0.4, FARM_SIZE)
    mesh.mesh = plane
    mesh.material_override = _material(Color(0.20, 0.52, 0.18))
    mesh.position.y = -0.2
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(FARM_SIZE, 0.4, FARM_SIZE)
    collision.shape = shape
    collision.position.y = -0.2
    body.add_child(collision)
    add_child(body)
    _add_boundary(Vector3(FARM_SIZE, 2.0, 0.4), Vector3(0, 1, -FARM_SIZE * 0.5))
    _add_boundary(Vector3(FARM_SIZE, 2.0, 0.4), Vector3(0, 1, FARM_SIZE * 0.5))
    _add_boundary(Vector3(0.4, 2.0, FARM_SIZE), Vector3(-FARM_SIZE * 0.5, 1, 0))
    _add_boundary(Vector3(0.4, 2.0, FARM_SIZE), Vector3(FARM_SIZE * 0.5, 1, 0))

func _build_obstacles() -> void:
    _add_box_obstacle("Fence", Vector3(5.0, 1.2, 0.35), Vector3(-5, 0.6, -2), Color(0.65, 0.38, 0.16))
    _add_box_obstacle("Building", Vector3(3.2, 2.2, 3.0), Vector3(5, 1.1, -3), Color(0.72, 0.30, 0.18))
    _add_tree(Vector3(-5, 0, 4))

func _add_tree(position: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = "Tree"
    var trunk := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.28
    cylinder.bottom_radius = 0.38
    cylinder.height = 1.8
    trunk.mesh = cylinder
    trunk.material_override = _material(Color(0.32, 0.16, 0.07))
    trunk.position = position + Vector3(0, 0.9, 0)
    body.add_child(trunk)
    var crown := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.2
    sphere.height = 2.4
    crown.mesh = sphere
    crown.material_override = _material(Color(0.08, 0.38, 0.12))
    crown.position = position + Vector3(0, 2.3, 0)
    body.add_child(crown)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.65
    shape.height = 2.0
    collision.shape = shape
    collision.position = position + Vector3(0, 1.0, 0)
    body.add_child(collision)
    add_child(body)

func _add_box_obstacle(label: String, size: Vector3, position: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.name = label
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _material(color)
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    body.position = position
    add_child(body)

func _add_boundary(size: Vector3, position: Vector3) -> void:
    _add_box_obstacle("TerrainBoundary", size, position, Color(0.12, 0.30, 0.12))

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.name = "IsometricCamera"
    camera.position = farmer.global_position + Vector3(0, 13, 13)
    camera.current = true
    add_child(camera)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    var joystick := JOYSTICK_SCENE.instantiate()
    joystick.name = "VirtualJoystick"
    joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    joystick.position = Vector2(28, -250)
    layer.add_child(joystick)
    farmer.joystick_path = NodePath("../HUD/VirtualJoystick")
    var label := Label.new()
    label.text = "Farm Victory  |  Joystick touchscreen / setas para teste"
    label.position = Vector2(24, 22)
    layer.add_child(label)

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    return material
