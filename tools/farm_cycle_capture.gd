extends SceneTree
## Captura da câmera real com 21 plantas em um estágio escolhido: -- --stage=0..3

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.set_process(false)
    world.harvest_controller.enabled = false
    var stage := -1
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--stage="):
            stage = clampi(int(arg.trim_prefix("--stage=")), 0, CropPlant.STAGES.size() - 1)
    if stage >= 0:
        for cell in world.planting_grid.cells.values():
            if int(cell["column"]) == 1:
                world.spawn_crop_at_stage(cell["id"], stage)
    world.farmer.global_position = Vector3(0, 1, 7)
    var focus := Vector3(0, 0, 8)
    world.camera.global_position = focus + Vector3(0, world.camera_height, world.camera_distance)
    world.camera.look_at(focus, Vector3.UP)
    print("CYCLE_CAPTURE stage=", stage, " crops=", world.crops.size(), " cells=", world.planting_grid.cells.size())
    for frame in 6:
        await process_frame
    quit()
