extends Node3D
class_name FarmWorld

@export_category("World Scale")
@export var farm_size: float = 64.0
@export var camera_orthographic_size: float = 12.0
@export var camera_height: float = 14.0
@export var camera_distance: float = 14.0
@export var camera_follow_speed: float = 5.0
@export var camera_dead_zone: Vector2 = Vector2(3.5, 2.5)
@export var camera_limits: Vector2 = Vector2(26.0, 26.0)

const JOYSTICK_SCENE := preload("res://scenes/ui/virtual_joystick.tscn")
const SEED_THROW_SCENE := preload("res://scenes/vfx/SeedThrow.tscn")
const PLANTING_GRID_SCRIPT := preload("res://scripts/farming/planting_grid.gd")
const CROP_PLANT_SCRIPT := preload("res://scripts/farming/crop_plant.gd")
const SOIL_TEXTURE := preload("res://assets/textures/soil/plowed_soil_three_furrows.png")
const HARVEST_INVENTORY_SCRIPT := preload("res://scripts/farming/harvest_inventory.gd")
const HARVEST_CONTROLLER_SCRIPT := preload("res://scripts/farming/harvest_controller.gd")
const BACKPACK_CRATES_SCRIPT := preload("res://scripts/player/backpack_crates.gd")

## Mochila nas costas do fazendeiro (a frente do fazendeiro é -Z local).
const BACKPACK_OFFSET := Vector3(0.0, 1.1, 0.62)

const SEED_HAND_OFFSET := Vector3(0.45, 1.15, -0.25)

const PLANTING_PLOT_COUNT := 3
const PLANTING_COLUMNS := 3
const PLANTING_ROWS := 1
const PLANTING_PLOT_WIDTH := 3.8
# Proporção do PNG aprovado: 466 x 912. A altura é derivada da largura para
# preservar o comprimento original, sem esticar ou comprimir a textura.
const PLANTING_TEXTURE_ASPECT := 912.0 / 466.0
# Conteúdo opaco ocupa 443 dos 466 px de largura (margem transparente lateral).
const PLANTING_VISIBLE_WIDTH_RATIO := 443.0 / 466.0
# A câmera olha o chão a 45° (camera_height == camera_distance), o que encurta
# o eixo Z na tela por sin(45°). O comprimento é compensado por 1/sin(45°) para
# que a tira apareça na proporção da arte, sem aspecto "comprimido".
const PLANTING_VIEW_PITCH_DEGREES := 45.0
const PLANTING_LENGTH_STRETCH := 1.0 / sin(deg_to_rad(PLANTING_VIEW_PITCH_DEGREES))
const PLANTING_PLOT_SIZE := Vector2(
    PLANTING_PLOT_WIDTH,
    PLANTING_PLOT_WIDTH * PLANTING_TEXTURE_ASPECT * PLANTING_LENGTH_STRETCH
)
# Borda do canteiro mais próxima da casa/fazendeiro; o canteiro cresce para +Z.
const PLANTING_NEAR_EDGE_Z := 3.3
# Os módulos são contíguos nos dois eixos: uma área de cultivo é um agrupamento sem vãos.
# Sobreposição controlada para ocultar qualquer margem transparente residual do PNG.
const PLANTING_PLOT_SPACING := Vector2(PLANTING_PLOT_WIDTH - 0.35, PLANTING_PLOT_SIZE.y)

@onready var farmer: FarmerController = $Farmer
var camera: Camera3D
var camera_focus: Vector3
var planting_grid: PlantingGrid
var harvest_inventory: HarvestInventory
var harvest_controller: HarvestController
var backpack: BackpackCrates
## cell_id -> CropPlant, para a colheita localizar a planta de cada célula.
var crops: Dictionary = {}
var harvest_label: Label

func _ready() -> void:
    _build_environment()
    _build_ground()
    _build_planting_area()
    _build_planting_grid()
    _build_obstacles()
    _build_camera()
    _build_harvest()
    _build_hud()
    _prewarm_seed_throw()
    camera_focus = farmer.global_position

func _process(delta: float) -> void:
    if camera and farmer:
        _update_camera_focus(delta)
    if planting_grid and farmer:
        planting_grid.process_farmer_position(farmer.global_position, delta)

func _build_planting_grid() -> void:
    planting_grid = PLANTING_GRID_SCRIPT.new()
    planting_grid.name = "PlantingGrid"
    add_child(planting_grid)
    var modules: Array[Area3D] = []
    for child in $PlantingArea.get_children():
        if child is Area3D:
            modules.append(child)
    planting_grid.configure(modules)
    planting_grid.cell_planted.connect(_on_grid_cell_planted)

func _on_grid_cell_planted(cell_id: String) -> void:
    var cell: Dictionary = planting_grid.cells[cell_id]
    var seed_throw := SEED_THROW_SCENE.instantiate() as SeedThrow
    add_child(seed_throw)
    # O broto nasce quando o punhado toca o sulco, não no momento do arremesso.
    seed_throw.landed.connect(_spawn_crop.bind(cell_id), CONNECT_ONE_SHOT)
    seed_throw.launch(farmer.global_position + SEED_HAND_OFFSET, cell["position"] + Vector3(0.0, 0.2, 0.0))

## Dispara um punhado invisível sob o terreno para compilar os shaders das
## partículas na carga da cena; sem isso o primeiro arremesso real engasga.
func _prewarm_seed_throw() -> void:
    var warmup := SEED_THROW_SCENE.instantiate() as SeedThrow
    warmup.name = "SeedThrowWarmup"
    warmup.ground_grain_count = 1
    add_child(warmup)
    warmup.launch(Vector3(0.0, -40.0, 0.0), Vector3(0.5, -40.0, 0.5))

func _spawn_crop(_landing: Vector3, cell_id: String) -> CropPlant:
    var cell: Dictionary = planting_grid.cells[cell_id]
    var crop := CROP_PLANT_SCRIPT.new() as CropPlant
    crop.name = "Crop_" + cell_id
    crop.position = cell["position"]
    crop.cell_width = cell["cell_width"]
    add_child(crop)
    crops[cell_id] = crop
    crop.ready_for_harvest.connect(_on_crop_ready)
    crop.initialize(cell_id, cell["planted_at"])
    return crop

## Planta já num estágio (ferramentas de teste/captura). Estágio final => RIPE.
func spawn_crop_at_stage(cell_id: String, stage: int) -> CropPlant:
    if planting_grid.cells[cell_id]["state"] == "EMPTY":
        planting_grid.cells[cell_id]["state"] = "SEEDED"
    var crop := _spawn_crop(Vector3.ZERO, cell_id)
    # planted_at = 0 congela o crescimento no estágio pedido.
    crop.planted_at = 0.0
    crop._update_stage(stage)
    return crop

func _on_crop_ready(cell_id: String) -> void:
    planting_grid.mark_ripe(cell_id, harvest_controller.yield_per_crop)

func _build_harvest() -> void:
    harvest_inventory = HARVEST_INVENTORY_SCRIPT.new() as HarvestInventory
    harvest_inventory.name = "HarvestInventory"
    add_child(harvest_inventory)
    backpack = BACKPACK_CRATES_SCRIPT.new() as BackpackCrates
    backpack.name = "BackpackCrates"
    backpack.max_crates = harvest_inventory.max_crates
    backpack.units_per_crate = harvest_inventory.units_per_crate
    backpack.position = BACKPACK_OFFSET
    farmer.add_child(backpack)
    harvest_inventory.amount_changed.connect(backpack.set_amount)
    harvest_controller = HARVEST_CONTROLLER_SCRIPT.new() as HarvestController
    harvest_controller.name = "HarvestController"
    add_child(harvest_controller)
    harvest_controller.setup(planting_grid, harvest_inventory, farmer, backpack.intake_marker, crops, self)
    planting_grid.cell_state_changed.connect(_on_cell_state_changed)

func _on_cell_state_changed(cell_id: String, state: String) -> void:
    if state == PlantingGrid.STATE_HARVESTED and crops.has(cell_id):
        (crops[cell_id] as CropPlant).set_harvested()

func _update_harvest_label(_item: StringName = &"", _amount: int = 0) -> void:
    if harvest_label == null:
        return
    var total := harvest_inventory.get_total()
    if harvest_inventory.is_full():
        harvest_label.text = "Mochila cheia (%d/%d)! Leve as caixas até a bancada para descarregar." % [total, harvest_inventory.get_capacity()]
        harvest_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
    else:
        harvest_label.text = "Tomates: %d/%d   Caixas: %d/%d" % [total, harvest_inventory.get_capacity(), harvest_inventory.get_crate_count(), harvest_inventory.max_crates]
        harvest_label.remove_theme_color_override("font_color")

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
    plane.size = Vector3(farm_size, 0.4, farm_size)
    mesh.mesh = plane
    mesh.material_override = _material(Color(0.20, 0.52, 0.18))
    mesh.position.y = -0.2
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(farm_size, 0.4, farm_size)
    collision.shape = shape
    collision.position.y = -0.2
    body.add_child(collision)
    add_child(body)
    _add_boundary(Vector3(farm_size, 2.0, 0.4), Vector3(0, 1, -farm_size * 0.5))
    _add_boundary(Vector3(farm_size, 2.0, 0.4), Vector3(0, 1, farm_size * 0.5))
    _add_boundary(Vector3(0.4, 2.0, farm_size), Vector3(-farm_size * 0.5, 1, 0))
    _add_boundary(Vector3(0.4, 2.0, farm_size), Vector3(farm_size * 0.5, 1, 0))

func _build_planting_area() -> void:
    var planting_area := Node3D.new()
    planting_area.name = "PlantingArea"
    planting_area.set_meta("crop", "tomato")
    planting_area.set_meta("is_crop_group", true)
    planting_area.set_meta("plot_count", PLANTING_PLOT_COUNT)
    add_child(planting_area)

    var soil_material := StandardMaterial3D.new()
    soil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    soil_material.albedo_texture = SOIL_TEXTURE
    soil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    soil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    soil_material.render_priority = -1

    for index in PLANTING_PLOT_COUNT:
        var plot := Area3D.new()
        plot.name = "PlantingPlot_%02d" % (index + 1)
        var column := index % PLANTING_COLUMNS
        var row := int(index / PLANTING_COLUMNS)
        var centered_column := column - (PLANTING_COLUMNS - 1) * 0.5
        var centered_row := row - (PLANTING_ROWS - 1) * 0.5
        plot.position = Vector3(
            centered_column * PLANTING_PLOT_SPACING.x,
            0.025,
            PLANTING_NEAR_EDGE_Z + PLANTING_PLOT_SIZE.y * 0.5 + centered_row * PLANTING_PLOT_SPACING.y
        )
        plot.set_meta("plot_index", index)
        plot.set_meta("crop", "tomato")
        plot.add_to_group("planting_plot")

        var visual := MeshInstance3D.new()
        visual.name = "PlowedSoil"
        var quad := QuadMesh.new()
        quad.size = Vector2(
            PLANTING_PLOT_WIDTH / PLANTING_VISIBLE_WIDTH_RATIO,
            PLANTING_PLOT_SIZE.y
        )
        visual.mesh = quad
        visual.material_override = soil_material
        visual.rotation_degrees.x = -90.0
        plot.add_child(visual)

        var collision := CollisionShape3D.new()
        collision.name = "CollisionShape3D"
        var shape := BoxShape3D.new()
        shape.size = Vector3(PLANTING_PLOT_SIZE.x, 0.1, PLANTING_PLOT_SIZE.y)
        collision.shape = shape
        collision.position.y = -0.025
        plot.add_child(collision)
        planting_area.add_child(plot)

func _build_obstacles() -> void:
    _add_box_obstacle("Fence", Vector3(5.0, 1.2, 0.35), Vector3(-5, 0.6, -2), Color(0.65, 0.38, 0.16))
    _add_box_obstacle("Building", Vector3(3.2, 2.2, 3.0), Vector3(5, 1.1, -3), Color(0.72, 0.30, 0.18))
    # A árvore fica fora do agrupamento contínuo de cultivo de tomate.
    _add_tree(Vector3(-10, 0, 10))

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
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = camera_orthographic_size
    camera.position = farmer.global_position + Vector3(0, camera_height, camera_distance)
    camera.current = true
    add_child(camera)

func _update_camera_focus(delta: float) -> void:
    var offset := farmer.global_position - camera_focus
    var desired_focus := camera_focus
    if absf(offset.x) > camera_dead_zone.x:
        desired_focus.x = farmer.global_position.x - signf(offset.x) * camera_dead_zone.x
    if absf(offset.z) > camera_dead_zone.y:
        desired_focus.z = farmer.global_position.z - signf(offset.z) * camera_dead_zone.y
    desired_focus.x = clampf(desired_focus.x, -camera_limits.x, camera_limits.x)
    desired_focus.z = clampf(desired_focus.z, -camera_limits.y, camera_limits.y)
    camera_focus = camera_focus.lerp(desired_focus, minf(1.0, delta * camera_follow_speed))
    var desired_camera := camera_focus + Vector3(0.0, camera_height, camera_distance)
    camera.global_position = camera.global_position.lerp(desired_camera, minf(1.0, delta * camera_follow_speed))
    camera.look_at(camera_focus, Vector3.UP)

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
    label.text = "TerraBela Farm  |  Joystick touchscreen / setas para teste"
    label.position = Vector2(24, 22)
    layer.add_child(label)
    harvest_label = Label.new()
    harvest_label.name = "HarvestLabel"
    harvest_label.position = Vector2(24, 50)
    harvest_label.add_theme_font_size_override("font_size", 22)
    harvest_label.add_theme_constant_override("outline_size", 6)
    harvest_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
    layer.add_child(harvest_label)
    harvest_inventory.amount_changed.connect(_update_harvest_label)
    _update_harvest_label()

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    return material
