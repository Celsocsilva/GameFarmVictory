extends SceneTree
## Capturas do HUD UI-004 no jogo real.
## Uso (sem --headless):
##   paisagem: --resolution 1280x720 -s tools/hud_capture.gd -- <pasta> landscape
##   retrato:  --resolution 720x1280 -s tools/hud_capture.gd -- <pasta> portrait
## Em retrato a captura usa stretch aspect "expand" (a área lógica vira
## 1280 x 2275) para mostrar o HUD ocupando a tela do celular em pé.

const STEP := 0.05

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var out_dir := args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://docs/evidence/ui-004")
    var mode := args[1] if args.size() > 1 else "landscape"
    DirAccess.make_dir_recursive_absolute(out_dir)
    if mode == "portrait":
        root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    await process_frame
    var prefix := "paisagem" if mode == "landscape" else "retrato"

    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.harvest_controller.enabled = false
    world.customer_queue.set_process(false)
    world.sales_controller.set_process(false)
    world.customer_queue.set_seed(20261106)
    world.sales_controller.set_seed(7)
    var hud := world.hud
    var counter := world.sales_counter
    var view := counter.global_position + Vector3(-1.5, 0.0, -counter.get_half_extents().y - 2.6)
    await create_timer(0.6).timeout

    # 1. Antes: tudo zerado (estado inicial do jogo).
    print("CAPTURE_BEFORE money=%s tomato=%s crate=%s" % [hud.get_money_text(), hud.get_tomato_text(), hud.get_crate_text()])
    await _shot(out_dir, "%s-01-hud-antes.png" % prefix)

    # 2. Depois: 18 tomates (3 caixas) na mochila e saldo de 1.250 na carteira.
    world.harvest_inventory.set_amount(&"tomato", 18)
    world.wallet.add(1250, &"capture")
    await create_timer(0.5).timeout
    print("CAPTURE_AFTER money=%s tomato=%s crate=%s mission=%s" % [hud.get_money_text(), hud.get_tomato_text(), hud.get_crate_text(), hud.mission_panel.get_progress_text()])
    await _shot(out_dir, "%s-02-hud-depois.png" % prefix)

    # 3. Mochila cheia: missão "Colher tomates" concluída -> popup de recompensa.
    world.harvest_inventory.set_amount(&"tomato", 56)
    await create_timer(0.6).timeout
    print("CAPTURE_REWARD open=%s value=%s banner=%s" % [hud.reward_popup.is_open, hud.reward_popup.value_label.text, hud.get_banner_message()])
    await _shot(out_dir, "%s-03-popup-recompensa.png" % prefix)
    hud.reward_popup.collect_button.pressed.emit()
    await create_timer(0.5).timeout

    # 4. Venda real no balcão: as caixas vão para o balcão, o cliente compra e o
    # aviso de venda aparece embaixo do contador de dinheiro.
    _place_farmer(world, view)
    counter.deposit_from(world.harvest_inventory, world.get_farmer_hands_position())
    while counter.get_flying_crate_count() > 0:
        await process_frame
    while world.sales_controller.sales_log.is_empty():
        _advance(world, STEP)
    for i in 6:
        _advance(world, STEP)
        await process_frame
    await create_timer(0.35).timeout
    var sale: Dictionary = world.sales_controller.sales_log[0]
    print("CAPTURE_SALE crates=%d money=%d popups=%d mission=%s xp=%s" % [sale["crates"], sale["money"], hud.get_active_sale_popups().size(), hud.mission_panel.get_progress_text(), hud.level_panel.xp_bar.get_label_text()])
    await _shot(out_dir, "%s-04-popup-venda.png" % prefix)

    # 5. Cena de preview com todos os componentes (só em paisagem).
    if mode == "landscape":
        world.queue_free()
        await process_frame
        var preview := (load("res://scenes/ui/hud/UiPreview.tscn") as PackedScene).instantiate()
        root.add_child(preview)
        await create_timer(0.6).timeout
        await _shot(out_dir, "%s-05-preview-componentes.png" % prefix)
    quit()

func _place_farmer(world: FarmWorld, at: Vector3) -> void:
    world.farmer.global_position = at
    world.farmer.rotation.y = PI
    world.camera_focus = at
    world.camera.global_position = at + Vector3(0.0, world.camera_height, world.camera_distance)
    world.camera.look_at(at, Vector3.UP)

func _advance(world: FarmWorld, delta: float) -> void:
    world.customer_queue.tick(delta)
    for child in world.customer_queue.get_children():
        if child is Customer and is_instance_valid(child):
            (child as Customer).step(delta)
    world.sales_controller.tick(delta)

func _shot(out_dir: String, file: String) -> void:
    for frame in 4:
        await process_frame
    var image := root.get_viewport().get_texture().get_image()
    var path := out_dir.path_join(file)
    image.save_png(path)
    print("CAPTURE ", path, " ", image.get_size())
