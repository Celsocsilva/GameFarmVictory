extends SceneTree
## Capturas do Balcão de vendas, da base de dinheiro 3 x 5 e das vendas.
## Uso (sem --headless): -s tools/sales_capture.gd -- <pasta_saida>

const STEP := 0.05

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var out_dir := args[0] if args.size() > 0 else "res://docs/evidence/fv-sales-001"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("res://") else out_dir)
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.set_process(false)
    world.harvest_controller.enabled = false
    world.customer_queue.set_process(false)
    world.sales_controller.set_process(false)
    world.farmer.set_physics_process(false)
    var counter := world.sales_counter
    var queue := world.customer_queue
    var sales := world.sales_controller
    queue.set_seed(20261106)
    sales.set_seed(7)
    var focus := counter.global_position + Vector3(1.5, 0.0, 0.5)

    # 1. Fazendeiro chegando ao balcão com a mochila cheia (7 caixas).
    world.harvest_inventory.set_amount(&"tomato", 56)
    world.farmer.global_position = counter.global_position + Vector3(-1.5, 0.0, -2.6)
    world.farmer.rotation.y = 0.0
    await _shot(world, focus, out_dir, "01-chegando-com-mochila-cheia.png")

    # 2. Toda a produção empilhada no balcão (4 mochilas = 28 caixas).
    for i in 4:
        world.harvest_inventory.set_amount(&"tomato", 56)
        counter.deposit_from(world.harvest_inventory)
    print("CAPTURE_STOCK units=%d crates=%d" % [counter.get_stored_total(), counter.get_displayed_crates()])
    await _shot(world, focus, out_dir, "02-producao-empilhada-no-balcao.png")

    # 3. Clientes chegam e compram; captura logo após uma venda.
    while sales.sales_log.size() < 2:
        _advance(world, STEP)
    for i in 14:
        _advance(world, STEP)
    var last: Dictionary = sales.sales_log[sales.sales_log.size() - 1]
    print("CAPTURE_SALE crates=%d money=%d balance=%d" % [last["crates"], last["money"], world.money_stack.get_balance()])
    await _shot(world, focus, out_dir, "03-cliente-saindo-com-caixas.png")

    # 4. Dinheiro empilhado na base 3 x 5 depois de várias vendas.
    while sales.sales_log.size() < 9 and counter.get_stored_total() > 0:
        _advance(world, STEP)
    for i in 10:
        _advance(world, STEP)
    print("CAPTURE_MONEY sales=%d balance=%d bundles=%d" % [sales.sales_log.size(), world.money_stack.get_balance(), world.money_stack.get_visible_bundles()])
    await _shot(world, world.money_stack.global_position + Vector3(0.0, 0.0, 0.3), out_dir, "04-dinheiro-na-base-3x5.png", 7.0)

    # 5. Visão de jogo: canteiro, balcão largo, cercas laterais, fila e base de dinheiro.
    await _shot(world, Vector3(0.0, 0.0, world.camera_limits.y - 6.0), out_dir, "05-visao-geral-balcao-de-vendas.png", 20.0)
    quit()

func _advance(world: FarmWorld, delta: float) -> void:
    world.customer_queue.tick(delta)
    for child in world.customer_queue.get_children():
        if child is Customer and is_instance_valid(child):
            (child as Customer).step(delta)
    world.sales_controller.tick(delta)

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
