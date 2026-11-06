extends SceneTree
## Evidências visuais da colheita FV-HARVEST-001 (precisa de janela; não use --headless).
## Uso: Godot --path . -s tools/harvest_capture.gd -- [pasta_saida] [--frames]
##   --frames  também grava a sequência da caminhada em <saida>/frames para virar vídeo.
## O fazendeiro anda com Input.action_press (mesmo caminho do teclado/joystick).

var _out_dir := "res://docs/evidence/fv-harvest-001"
var _record_frames := false
var world: FarmWorld
var _frame_index := 0

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    for arg in args:
        if not arg.begins_with("--"):
            _out_dir = arg
    _record_frames = args.has("--frames")
    call_deferred("_run")

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(_abs(_out_dir))
    if _record_frames:
        DirAccess.make_dir_recursive_absolute(_abs(_out_dir.path_join("frames")))
    await _capture_backpack_states()
    await _capture_walk_harvest()
    print("CAPTURE_OK dir=", _abs(_out_dir))
    quit()

## Mochila com 0, 1, 8, 9, 55 e 56 unidades (close na câmera real, sem colheita).
func _capture_backpack_states() -> void:
    await _load_world(false)
    world.harvest_controller.enabled = false
    world.farmer.global_position = Vector3(-6.0, 0.0, -1.0)
    await _frames(40)
    world.set_process(false)
    var camera := world.camera
    camera.size = 6.5
    camera.global_position = world.farmer.global_position + Vector3(0.0, world.camera_height, world.camera_distance) + Vector3(0.0, 1.6, 0.0)
    camera.look_at(world.farmer.global_position + Vector3(0.0, 1.6, 0.0), Vector3.UP)
    for amount in [0, 1, 8, 9, 55, 56]:
        world.harvest_inventory.set_amount(&"tomato", amount)
        await _frames(20)
        _save("backpack-%02d-units" % amount)
    # Fazendeiro de lado: a pilha continua nas costas e não atravessa o corpo.
    world.farmer.rotation.y = deg_to_rad(90.0)
    world.harvest_inventory.set_amount(&"tomato", 30)
    await _frames(20)
    _save("backpack-30-units-side")
    world.farmer.rotation.y = 0.0

## Caminhada real pelo canteiro colhendo do fundo até a frente, com giro brusco.
func _capture_walk_harvest() -> void:
    await _load_world(true)
    world.harvest_controller.enabled = false
    world.farmer.global_position = Vector3(0.0, 0.0, 1.4)
    await _frames(60)
    _save("01-before-first-harvest")
    world.harvest_controller.enabled = true

    var shots := {}
    world.harvest_controller.harvest_started.connect(func(cell_id: String, _units: int) -> void:
        var row: int = world.planting_grid.cells[cell_id]["row"]
        if row == 0 and not shots.has("back"):
            shots["back"] = Time.get_ticks_msec() + 220
        elif row == 3 and not shots.has("middle"):
            shots["middle"] = Time.get_ticks_msec() + 220)
    var crate_shots := {1: "04-backpack-1-crate", 4: "05-backpack-4-crates", 7: "06-backpack-7-crates"}
    var taken := {}
    # Roteiro: desce pela tira do meio, giro brusco para a direita e volta.
    var route := [["ui_down", 1.6], ["ui_right", 0.35], ["ui_down", 0.6], ["ui_left", 0.7], ["ui_down", 0.8], ["ui_up", 1.4], ["ui_right", 0.9], ["ui_down", 1.2]]
    for leg in route:
        Input.action_press(leg[0])
        var end := Time.get_ticks_msec() + int(leg[1] * 1000.0)
        while Time.get_ticks_msec() < end:
            await process_frame
            _record()
            for key in shots.keys():
                if shots[key] > 0 and Time.get_ticks_msec() >= shots[key]:
                    _save("02-flight-back-of-field" if key == "back" else "03-flight-middle-of-field")
                    shots[key] = -1
            var crates := world.harvest_inventory.get_crate_count()
            if crate_shots.has(crates) and not taken.has(crates):
                taken[crates] = true
                _save(crate_shots[crates])
        Input.action_release(leg[0])
    for i in 40:
        await process_frame
        _record()
    _save("07-backpack-full-fruit-left-on-plants")
    # Frente do campo com a mochila vazia: zera a carga e colhe a última fileira.
    world.harvest_inventory.set_amount(&"tomato", 0)
    world.harvest_controller.enabled = false
    world.farmer.global_position = Vector3(3.45, 0.0, 15.2)
    for i in 90:
        await process_frame
    world.harvest_controller.enabled = true
    var front_shot := [false]
    world.harvest_controller.harvest_started.connect(func(_cell_id: String, _units: int) -> void:
        if not front_shot[0]:
            front_shot[0] = true
            _later_save("08-flight-front-of-field", 0.22), CONNECT_ONE_SHOT)
    Input.action_press("ui_up")
    for i in 50:
        await process_frame
        _record()
    Input.action_release("ui_up")
    for i in 50:
        await process_frame
        _record()
    print("HARVEST_CAPTURE total=", world.harvest_inventory.get_total(), " crates=", world.harvest_inventory.get_crate_count())

func _later_save(name: String, seconds: float) -> void:
    await create_timer(seconds).timeout
    _save(name)

func _load_world(all_ripe: bool) -> void:
    if world:
        world.queue_free()
        await process_frame
    world = (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    if all_ripe:
        for cell_id in world.planting_grid.cells:
            world.spawn_crop_at_stage(cell_id, CropPlant.STAGES.size() - 1)

func _frames(count: int) -> void:
    for i in count:
        await process_frame

func _record() -> void:
    if not _record_frames:
        return
    _frame_index += 1
    if _frame_index % 2 != 0:
        return
    var image := root.get_texture().get_image()
    image.save_jpg(_abs(_out_dir.path_join("frames/f%05d.jpg" % (_frame_index / 2))), 0.85)

func _save(name: String) -> void:
    var image := root.get_texture().get_image()
    var path := _out_dir.path_join(name + ".png")
    image.save_png(_abs(path))
    print("CAPTURE ", path)

func _abs(path: String) -> String:
    return ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
