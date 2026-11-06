extends SceneTree
## Captura da câmera real com quatro caixas de tomates descarregadas no depósito.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.set_process(false)
    world.harvest_controller.enabled = false
    var show_backpack := OS.get_cmdline_user_args().has("--backpack")
    var focus: Vector3
    if show_backpack:
        world.harvest_inventory.set_amount(&"tomato", 56)
        assert(world.backpack.get_visible_crate_count() == 7)
        world.farmer.global_position = Vector3(0.0, 1.0, 7.0)
        focus = Vector3(0.0, 2.0, 8.0)
        print("BACKPACK_CAPTURE crates=", world.backpack.get_visible_crate_count())
    else:
        world.harvest_inventory.set_amount(&"tomato", 32)
        assert(world.backpack.get_visible_crate_count() == 4)
        world.tomato_depot.deposit_from(world.harvest_inventory)
        assert(world.tomato_depot.get_stored_total() == 32)
        assert(world.tomato_depot.get_displayed_crates() == 4)
        assert(world.backpack.get_visible_crate_count() == 0)
        world.farmer.global_position = world.tomato_depot.global_position + Vector3(0.0, 1.0, -4.0)
        focus = world.tomato_depot.global_position + Vector3(0.0, 0.0, -1.5)
        print("DEPOT_CAPTURE stored=", world.tomato_depot.get_stored_total(), " crates=", world.tomato_depot.get_displayed_crates())
    world.camera.global_position = focus + Vector3(0.0, world.camera_height, world.camera_distance)
    world.camera.look_at(focus, Vector3.UP)
    for frame in 6:
        await process_frame
    quit()
