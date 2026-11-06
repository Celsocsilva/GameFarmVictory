extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := load("res://scenes/world/farm_world.tscn") as PackedScene
    var world := scene.instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    var grid := world.planting_grid
    assert(grid.cells.size() == 60, "Expected 4 modules x 3 furrows x 5 rows")
    var front: Dictionary = {}
    var back: Dictionary = {}
    for cell in grid.cells.values():
        if front.is_empty() or cell["position"].z > front["position"].z:
            front = cell
        if back.is_empty() or cell["position"].z < back["position"].z:
            back = cell
    assert(front["id"] != back["id"])
    assert(grid.plant_cell(front["id"]))
    assert(not grid.plant_cell(front["id"]), "Duplicate planting")
    assert(grid.plant_cell(back["id"]), "Back row must be plantable")
    assert(grid.get_planting_progress()["planted"] == 2)
    assert(grid.get_cell_world_position(front["id"]) == front["position"])
    grid.cell_planted.disconnect(world._on_grid_cell_planted)
    var positions := {}
    for cell in grid.cells.values():
        var position: Vector3 = cell["position"]
        var key := Vector2i(roundi(position.x * 1000), roundi(position.z * 1000))
        assert(not positions.has(key), "Duplicate planting position")
        positions[key] = true
        grid.plant_cell(cell["id"])
    assert(grid.get_planting_progress()["remaining"] == 0)
    print("FARM_SMOKE_OK cells=60 unique=60 planted=60 front=", front["id"], " back=", back["id"])
    quit()
