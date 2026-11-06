extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.planting_grid.cell_planted.disconnect(world._on_grid_cell_planted)
    # A amostra cobre as fileiras do fundo ao primeiro plano na câmera real.
    for cell in world.planting_grid.cells.values():
        if cell["column"] == 1 and int(cell["module_id"].right(2)) in [1, 2, 3, 4]:
            world.planting_grid.plant_cell(cell["id"])
            var crop := CropPlant.new()
            crop.position = cell["position"]
            crop.cell_width = cell["cell_width"]
            world.add_child(crop)
            crop.initialize(cell["id"], Time.get_ticks_msec() / 1000.0 - 31.0)
    for child in world.get_children():
        if child is CropPlant:
            child._update_stage(4)
    print("VISUAL_CROPS=", world.get_children().filter(func(child: Node) -> bool: return child is CropPlant).size())
    for frame in 55:
        await process_frame
    quit()
