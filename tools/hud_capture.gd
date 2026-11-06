extends SceneTree
## Capturas do HUD (UI v5) no jogo real, com a janela no tamanho pedido.
## Uso (sem --headless):
##   --resolution 720x1280  -s tools/hud_capture.gd -- <pasta> 720x1280
##   --resolution 1080x1920 -s tools/hud_capture.gd -- <pasta> 1080x1920
##   --resolution 1280x720  -s tools/hud_capture.gd -- <pasta> 1280x720
##   --resolution 1280x720  -s tools/hud_capture.gd -- <pasta> qa   (UIAssetQA)
## Em janela retrato a captura usa stretch aspect "expand" (área lógica
## 1280 x 2275) para mostrar o HUD ocupando a tela do celular em pé.

const STEP := 0.05
const BASE_SIZE := Vector2(1280, 720)

## Viewport de onde sai a captura: a janela ou, quando o monitor não comporta a
## resolução pedida (ex.: 1080x1920 num monitor de 1080 px de altura), um
## SubViewport do tamanho exato, com o mesmo stretch "expand" da janela.
var target: Viewport

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var out_dir := args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://docs/evidence/ui-v5")
    var prefix := args[1] if args.size() > 1 else "1280x720"
    DirAccess.make_dir_recursive_absolute(out_dir)
    if prefix == "qa":
        await _capture_qa(out_dir)
        quit()
        return
    var window_size := DisplayServer.window_get_size()
    var requested := window_size
    var parts := prefix.split("x")
    if parts.size() == 2:
        requested = Vector2i(int(parts[0]), int(parts[1]))
    target = root
    var parent: Node = root
    if requested != window_size:
        var sub := SubViewport.new()
        sub.size = requested
        var factor := minf(requested.x / BASE_SIZE.x, requested.y / BASE_SIZE.y)
        sub.size_2d_override = Vector2i(Vector2(requested) / factor)
        sub.size_2d_override_stretch = true
        sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(sub)
        target = sub
        parent = sub
        print("CAPTURE_OFFSCREEN window=%s subviewport=%s logical=%s" % [window_size, requested, sub.size_2d_override])
    elif window_size.y > window_size.x:
        root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    await process_frame
    print("CAPTURE_WINDOW %s logical=%s" % [window_size, target.get_visible_rect().size])

    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    parent.add_child(world)
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

    # 5. Valores extremos: 9.999.999 de dinheiro e mochila cheia 56/56, 7/7.
    world.wallet.set_balance(9999999)
    world.harvest_inventory.set_amount(&"tomato", 56)
    await create_timer(0.5).timeout
    print("CAPTURE_EXTREMES money=%s tomato=%s crate=%s" % [hud.get_money_text(), hud.get_tomato_text(), hud.get_crate_text()])
    await _shot(out_dir, "%s-05-valores-extremos.png" % prefix)

    # 6. Cena de preview com todos os componentes (só na resolução desktop).
    if prefix == "1280x720":
        world.queue_free()
        await process_frame
        var preview := (load("res://scenes/ui/hud/UiPreview.tscn") as PackedScene).instantiate()
        root.add_child(preview)
        await create_timer(0.6).timeout
        await _shot(out_dir, "%s-06-preview-componentes.png" % prefix)
    quit()

## Tela de inspeção dos PNGs: página 1 (oito componentes corrigidos + CTAs) nos
## três fundos, páginas 2 e 3 no xadrez.
func _capture_qa(out_dir: String) -> void:
    var qa := (load("res://scenes/ui/hud/UIAssetQA.tscn") as PackedScene).instantiate()
    root.add_child(qa)
    for shot in [[0, 0, "qa-01-componentes-v5-xadrez.png"], [0, 1, "qa-02-componentes-v5-branco.png"], [0, 2, "qa-03-componentes-v5-preto.png"], [1, 0, "qa-04-hud-e-icones-xadrez.png"], [1, 2, "qa-05-hud-e-icones-preto.png"], [2, 0, "qa-06-demais-componentes-xadrez.png"], [2, 2, "qa-07-demais-componentes-preto.png"]]:
        qa.page = shot[0]
        qa.background_mode = shot[1]
        qa.rebuild()
        await create_timer(0.4).timeout
        await _shot(out_dir, shot[2])

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
    var image := (target if target else root).get_texture().get_image()
    var path := out_dir.path_join(file)
    image.save_png(path)
    print("CAPTURE ", path, " ", image.get_size())
