extends SceneTree
## Capturas da fila de clientes com a câmera real (renderizador Mobile).
## Uso (sem --headless): -s tools/customer_capture.gd -- <pasta_saida>

const STEP := 0.05

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var out_dir := args[0] if args.size() > 0 else "res://docs/evidence/fv-customers-001"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("res://") else out_dir)
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.set_process(false)
    world.harvest_controller.enabled = false
    var queue := world.customer_queue
    queue.set_process(false)
    queue.set_seed(20261106)
    # Paciência longa só até juntar os 5, para a captura do limite.
    queue.min_patience = 999.0
    queue.max_patience = 999.0
    var depot := world.tomato_depot

    # Bancada com algumas caixas e o fazendeiro chegando pelo lado da plantação.
    world.harvest_inventory.set_amount(&"tomato", 24)
    depot.deposit_from(world.harvest_inventory)
    world.harvest_inventory.set_amount(&"tomato", 32)
    world.farmer.global_position = depot.global_position + Vector3(-2.6, 0.0, -3.2)
    world.farmer.rotation.y = deg_to_rad(-140.0)

    # 1. Um cliente acabou de surgir e caminha até a fila (tempo simulado real).
    while queue.spawn_times.size() < 3:
        _advance(queue, STEP)
    for i in 22:
        _advance(queue, STEP)
    await _shot(world, depot.global_position + Vector3(0.0, 0.0, 4.5), out_dir, "01-cliente-chegando.png")

    # 2. Limite de 5 acumulados (3 + 2 nas duas filas).
    while queue.spawn_times.size() < 5:
        _advance(queue, STEP)
    queue.snap_all_to_targets()
    for i in 20:
        _advance(queue, STEP)
    print("CAPTURE_MAX count=", queue.get_customer_count(), " paused=", queue.is_paused_full(), " times=", queue.spawn_times)
    await _shot(world, depot.global_position + Vector3(0.0, 0.0, 4.5), out_dir, "02-cinco-clientes-limite.png")

    # Paciência real de 15-20 s a partir de agora.
    queue.min_patience = 15.0
    queue.max_patience = 20.0
    for customer in queue.get_customers():
        customer.patience_left = queue.rng.randf_range(15.0, 20.0)
        customer.set_meta("arrived_at", queue.get_elapsed())
    var leaves := queue.leave_log.size()
    while queue.leave_log.size() == leaves:
        _advance(queue, STEP)
    for i in 18:
        _advance(queue, STEP)
    var leaver: Customer = queue.leave_log[queue.leave_log.size() - 1]["customer"]
    print("CAPTURE_LEAVE waited=%.2f at=%.2f" % [queue.leave_log[queue.leave_log.size() - 1]["waited"], queue.get_elapsed()])
    await _shot(world, depot.global_position + Vector3(0.0, 0.0, 4.5), out_dir, "05-cliente-indo-embora.png")
    while not queue.return_log.any(func(e): return e["customer"] == leaver):
        _advance(queue, STEP)
    for i in 25:
        _advance(queue, STEP)
    var back: Dictionary = queue.return_log.filter(func(e): return e["customer"] == leaver)[0]
    print("CAPTURE_RETURN away=%.2f at=%.2f" % [back["away"], queue.get_elapsed()])
    await _shot(world, depot.global_position + Vector3(0.0, 0.0, 4.5), out_dir, "06-cliente-voltando.png")

    # 3. Pré-visualização do espaço: 2 filas x 7 lugares preenchidos à força.
    while queue.spawn_customer(true) != null:
        pass
    queue.snap_all_to_targets()
    print("CAPTURE_FULL count=", queue.get_customer_count())
    await _shot(world, depot.global_position + Vector3(0.0, 0.0, 4.5), out_dir, "03-espaco-fila-dupla-2x7.png")

    # 4. Visão de jogo: câmera no limite real, canteiro, bancada recuada e fila.
    await _shot(world, Vector3(0.0, 0.0, world.camera_limits.y - 6.0), out_dir, "04-visao-canteiro-bancada-fila.png", 20.0)
    quit()

func _advance(queue: CustomerQueue, delta: float) -> void:
    queue.tick(delta)
    for child in queue.get_children():
        if child is Customer and is_instance_valid(child):
            (child as Customer).step(delta)

func _shot(world: FarmWorld, focus: Vector3, out_dir: String, file: String, ortho_size: float = 0.0) -> void:
    var previous_size := world.camera.size
    if ortho_size > 0.0:
        world.camera.size = ortho_size
    world.camera.global_position = focus + Vector3(0.0, world.camera_height, world.camera_distance)
    world.camera.look_at(focus, Vector3.UP)
    for frame in 6:
        await process_frame
    var image := root.get_viewport().get_texture().get_image()
    var path := out_dir.path_join(file)
    image.save_png(path)
    print("CAPTURE ", path, " ", image.get_size())
    world.camera.size = previous_size
