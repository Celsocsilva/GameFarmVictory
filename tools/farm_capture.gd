extends SceneTree
## Captura de evidências visuais (precisa de janela; não use --headless).
## Uso: Godot --path . -s tools/farm_capture.gd -- <pasta_saida>

var _out_dir := "res://docs/evidence/fv-farm-005"
var _seeds_only := false
var world: FarmWorld

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    for arg in args:
        if not arg.begins_with("--"):
            _out_dir = arg
    _seeds_only = args.has("--seeds-only")
    call_deferred("_run")

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
    if not _seeds_only:
        await _capture_fields()
    await _capture_seed_handful()
    print("CAPTURE_OK dir=", ProjectSettings.globalize_path(_out_dir))
    quit()

func _capture_fields() -> void:
    await _load_world()
    await _frames(20)
    _save("01-soil-empty")
    await _save_overview("01b-soil-overview")

    # Um estágio por canteiro + estágio final nas fileiras da frente: mostra o ciclo inteiro.
    _plant_stages()
    await _frames(30)
    _save("02-growth-stages")
    await _save_overview("02b-growth-stages-overview")

    await _load_world()
    _plant_all(CropPlant.STAGES.size() - 1)
    await _frames(30)
    _save("03-ready-full-field")

func _capture_seed_handful() -> void:
    await _load_world()
    # Espera o aquecimento de shaders do FarmWorld terminar, como na partida real.
    await _frames(90)
    var grid := world.planting_grid
    var target: Dictionary = grid.get_available_cells_near(world.farmer.global_position + Vector3(0, 0, 6.9), 3.0)[0]
    grid.plant_cell(target["id"])
    var shots := [[0.15, "04-seed-handful-release"], [0.42, "05-seed-handful-flight"], [0.78, "06-seed-handful-landing"], [1.0, "07-seed-ground-scatter"]]
    var start := Time.get_ticks_msec()
    for shot in shots:
        while (Time.get_ticks_msec() - start) / 1000.0 < shot[0]:
            await process_frame
        _save(shot[1])
    await _frames(10)
    # Close: segundo punhado com a câmera aproximada, para ver os tamanhos dos grãos.
    world.set_process(false)
    world.camera.size = 6.0
    world.camera.global_position += Vector3(0.0, 0.0, 1.5)
    var second: Dictionary = grid.get_available_cells_near(world.farmer.global_position + Vector3(1.2, 0, 5.0), 3.0)[0]
    grid.plant_cell(second["id"])
    start = Time.get_ticks_msec()
    for shot in [[0.4, "08-seed-sizes-closeup"], [1.0, "09-seed-ground-closeup"]]:
        while (Time.get_ticks_msec() - start) / 1000.0 < shot[0]:
            await process_frame
        _save(shot[1])

func _load_world() -> void:
    if world:
        world.queue_free()
        await process_frame
    world = (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame

func _plant_stages() -> void:
    for cell in world.planting_grid.cells.values():
        var module_index := int(String(cell["module_id"]).right(2)) - 1
        var stage := module_index if cell["row"] < 4 else CropPlant.STAGES.size() - 1
        _spawn_crop(cell, stage)

func _plant_all(stage: int) -> void:
    for cell in world.planting_grid.cells.values():
        _spawn_crop(cell, stage)

func _spawn_crop(cell: Dictionary, stage: int) -> void:
    world.planting_grid.cells[cell["id"]]["state"] = "SEEDED"
    var crop := CropPlant.new()
    crop.position = cell["position"]
    crop.cell_width = cell["cell_width"]
    world.add_child(crop)
    crop.initialize(cell["id"], 0.0)
    crop._update_stage(stage)

## Mesma câmera do jogo, com zoom aberto para mostrar o canteiro inteiro.
func _save_overview(name: String) -> void:
    var camera := world.camera
    var previous_size := camera.size
    camera.size = 26.0
    camera.global_position += Vector3(0.0, 0.0, 6.0)
    world.set_process(false)
    await _frames(5)
    _save(name)
    camera.size = previous_size
    world.set_process(true)
    await _frames(5)

func _frames(count: int) -> void:
    for i in count:
        await process_frame

func _save(name: String) -> void:
    var image := root.get_texture().get_image()
    var path := _out_dir.path_join(name + ".png")
    image.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
    print("CAPTURE ", path)
