extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.harvest_controller.enabled = false
    world.set_process(false)
    assert(world.backpack.crate_width == 2.0)
    assert(world.backpack.crate_step == 1.2)
    assert(world.tomato_depot.global_position.z > 0.0)
    assert(world.tomato_depot.get_stored_total() == 0)
    world.harvest_inventory.set_amount(&"tomato", 16)
    assert(world.backpack.get_visible_crate_count() == 2)
    world.tomato_depot.process_farmer_position(world.tomato_depot.global_position + Vector3(4.0, 0.0, 0.0))
    assert(world.harvest_inventory.get_total() == 16)
    world.tomato_depot.process_farmer_position(world.tomato_depot.global_position)
    assert(world.harvest_inventory.get_total() == 0)
    assert(world.backpack.get_visible_crate_count() == 0)
    assert(world.tomato_depot.get_stored_total() == 16)
    assert(world.tomato_depot.get_displayed_crates() == 2)
    assert(world.tomato_depot.deposit_from(world.harvest_inventory) == 0)
    print("DEPOT_SMOKE_OK stored=16 crates=2 backpack=0")
    quit()
