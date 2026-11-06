extends SceneTree
## Teste do HUD UI-004: contadores ligados aos estados reais (carteira, mochila),
## nível, missões, aviso de venda e popup de recompensa; QA dos assets.
## Uso: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/hud_smoke.gd

const STEP := 0.05
const ALLOWED_TEXTURE_PREFIXES := ["res://assets/ui/hud/", "res://assets/ui/icons/", "res://assets/ui/components/"]
const OFFICIAL_CASH := "res://assets/currency/cash_bundle_official.png"

var _failed := false

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    _failed = true
    push_error("HUD_SMOKE_FAIL " + message)
    print("HUD_SMOKE_FAIL ", message)
    quit(1)

func _advance(world: FarmWorld, delta: float) -> void:
    world.customer_queue.tick(delta)
    for child in world.customer_queue.get_children():
        if child is Customer and is_instance_valid(child):
            (child as Customer).step(delta)
    world.sales_controller.tick(delta)

func _run() -> void:
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.set_process(false)
    world.harvest_controller.enabled = false
    world.customer_queue.set_process(false)
    world.sales_controller.set_process(false)
    var hud := world.hud
    var inventory := world.harvest_inventory
    var wallet := world.wallet

    # 1. Estrutura: HUD em CanvasLayer com os componentes e o joystick de antes.
    if hud == null or not (hud is CanvasLayer) or hud.name != "HUD":
        return _fail("FarmHUD ausente")
    if world.get_node_or_null("HUD/VirtualJoystick") == null or world.farmer.joystick_path != NodePath("../HUD/VirtualJoystick"):
        return _fail("joystick fora do HUD")
    for path in ["Root/PlayerLevelPanel", "Root/MissionPanel", "Root/Counters/MoneyCounter", "Root/Counters/TomatoCounter", "Root/Counters/CrateCounter", "Root/StoreButton", "Root/RewardPopup", "Root/InfoBanner"]:
        if hud.get_node_or_null(path) == null:
            return _fail("componente ausente: " + path)

    # 2. Valores iniciais vindos dos estados existentes.
    if hud.get_money_text() != "0" or hud.get_tomato_text() != "0/56" or hud.get_crate_text() != "0/7":
        return _fail("valores iniciais: %s %s %s" % [hud.get_money_text(), hud.get_tomato_text(), hud.get_crate_text()])
    print("HUD_BEFORE money=%s tomato=%s crate=%s" % [hud.get_money_text(), hud.get_tomato_text(), hud.get_crate_text()])

    # 3. Mochila: 18 tomates = 3 caixas (8 por caixa); cheia mostra o aviso.
    inventory.set_amount(&"tomato", 18)
    if hud.get_tomato_text() != "18/56" or hud.get_crate_text() != "3/7" or hud.get_banner_message() != "":
        return _fail("mochila 18: %s %s" % [hud.get_tomato_text(), hud.get_crate_text()])
    # 4. Carteira: separador de milhar.
    wallet.add(1250, &"test")
    if hud.get_money_text() != "1.250":
        return _fail("carteira 1250: %s" % hud.get_money_text())
    print("HUD_AFTER money=%s tomato=%s crate=%s" % [hud.get_money_text(), hud.get_tomato_text(), hud.get_crate_text()])
    if UiStyle.format_int(0) != "0" or UiStyle.format_int(999) != "999" or UiStyle.format_int(1000000) != "1.000.000":
        return _fail("format_int")

    # 5. Missão 1 (colher 56): progresso pela mochila, popup de recompensa ao concluir.
    var missions := world.mission_tracker
    var panel := hud.mission_panel
    if panel.get_title() != "Colher tomates" or panel.get_progress_text() != "18/56":
        return _fail("missão colher: %s %s" % [panel.get_title(), panel.get_progress_text()])
    inventory.set_amount(&"tomato", 56)
    if not hud.get_banner_message().contains("Mochila cheia"):
        return _fail("aviso de mochila cheia")
    if not missions.completed or not hud.reward_popup.is_open or not hud.reward_popup.visible:
        return _fail("missão concluída sem popup")
    if hud.reward_popup.value_label.text != "10" or hud.reward_popup.value_icon.texture.resource_path != OFFICIAL_CASH:
        return _fail("popup: valor %s ícone %s" % [hud.reward_popup.value_label.text, hud.reward_popup.value_icon.texture.resource_path])
    # Coletar: saída animada, prêmio na mesma Wallet (origem mission), XP e missão 2.
    var balance_before := wallet.get_balance()
    hud.reward_popup.collect_button.pressed.emit()
    if wallet.get_balance() != balance_before + 10 or wallet.history[wallet.history.size() - 1]["source"] != &"mission":
        return _fail("prêmio não entrou na carteira")
    if hud.get_money_text() != "1.260" or panel.get_title() != "Vender caixas" or panel.get_progress_text() != "0/7":
        return _fail("após coletar: %s %s %s" % [hud.get_money_text(), panel.get_title(), panel.get_progress_text()])
    await create_timer(0.4).timeout
    if hud.reward_popup.visible:
        return _fail("popup não saiu")
    if world.player_level.xp != 10 or hud.level_panel.xp_bar.get_label_text() != "10/40":
        return _fail("xp da missão: %d %s" % [world.player_level.xp, hud.level_panel.xp_bar.get_label_text()])
    print("HUD_MISSION reward=10 wallet=%s next=%s" % [hud.get_money_text(), panel.get_title()])

    # 6. Venda real no balcão: aviso de venda, XP por tomate e missão de caixas.
    var counter := world.sales_counter
    counter.deposit_from(inventory)
    if hud.get_tomato_text() != "0/56" or hud.get_crate_text() != "0/7" or hud.get_banner_message() != "":
        return _fail("mochila descarregada: %s %s" % [hud.get_tomato_text(), hud.get_crate_text()])
    var sales := world.sales_controller
    world.customer_queue.set_seed(20261106)
    sales.set_seed(7)
    var guard := 0
    while sales.sales_log.is_empty() and guard < 4000:
        _advance(world, STEP)
        guard += 1
    if sales.sales_log.is_empty():
        return _fail("nenhuma venda")
    var sale: Dictionary = sales.sales_log[0]
    var popups := hud.get_active_sale_popups()
    if popups.size() != 1:
        return _fail("avisos de venda: %d" % popups.size())
    var expected := "+%d %d %s" % [sale["money"], sale["crates"], "caixa" if sale["crates"] == 1 else "caixas"]
    if popups[0].get_text() != expected or popups[0].icon_rect.texture.resource_path != OFFICIAL_CASH:
        return _fail("aviso de venda: '%s' esperado '%s'" % [popups[0].get_text(), expected])
    if panel.get_progress_text() != "%d/7" % sale["crates"]:
        return _fail("missão vender: %s" % panel.get_progress_text())
    if world.player_level.xp != 10 + int(sale["units"]):
        return _fail("xp da venda: %d" % world.player_level.xp)
    # O dinheiro da venda vai para a base (não para o HUD) até ser recolhido.
    if hud.get_money_text() != "1.260":
        return _fail("venda alterou o HUD antes de recolher")
    print("HUD_SALE popup='%s' mission=%s xp=%d" % [popups[0].get_text(), panel.get_progress_text(), world.player_level.xp])
    await create_timer(2.2).timeout
    if not hud.get_active_sale_popups().is_empty():
        return _fail("aviso de venda não sumiu")

    # 7. Nível sobe e o painel acompanha.
    world.player_level.add_xp(200)
    if hud.level_panel.level_label.text != str(world.player_level.level) or world.player_level.level < 3:
        return _fail("nível: %s" % hud.level_panel.level_label.text)

    # 8. Loja: botão responde com aviso temporário.
    hud.store_button.pressed.emit()
    if hud.get_banner_message() != "Loja em breve!":
        return _fail("loja")

    # 9. QA de assets: só PNGs do pacote UI-004; dinheiro = maço oficial;
    # nenhuma imagem de referência; nenhum PNG cortado ou distorcido.
    hud.reward_popup.show_reward("Recompensa!", "Missão concluída!", 25)
    hud.show_sale_popup(6, 2)
    await create_timer(0.5).timeout
    var checked := _check_textures(hud.root_control)
    if _failed:
        return
    if checked < 15:
        return _fail("poucas texturas verificadas: %d" % checked)
    # 10. Todos os componentes dentro da tela em paisagem e retrato (lógico 1280 x 2275).
    for screen in [Vector2(1280, 720), Vector2(1280, 2275), Vector2(1600, 720)]:
        hud.layout_for(screen)
        var bounds := Rect2(Vector2.ZERO, screen)
        for control in [hud.level_panel, hud.mission_panel, hud.money_counter, hud.tomato_counter, hud.crate_counter, hud.store_button, hud.info_banner]:
            var r := (control as Control).get_global_rect()
            if not bounds.encloses(r):
                return _fail("%s fora da tela %s: %s" % [control.name, screen, r])
        if hud.level_panel.get_global_rect().intersects(hud.money_counter.get_global_rect()) or hud.mission_panel.get_global_rect().intersects(hud.info_banner.get_global_rect()):
            return _fail("sobreposição em %s" % screen)
    hud.layout()
    var viewport_rect := Rect2(Vector2.ZERO, hud.root_control.size)
    var card := hud.reward_popup.card.get_global_rect()
    if not viewport_rect.encloses(card):
        return _fail("popup fora da tela: %s em %s" % [card, viewport_rect])
    print("HUD_QA textures=%d layouts=3 card=%s" % [checked, card])
    print("HUD_SMOKE_OK")
    quit(0)

func _check_textures(node: Node) -> int:
    var count := 0
    for child in node.get_children():
        count += _check_textures(child)
        if _failed:
            return count
    var texture: Texture2D = null
    if node is TextureRect:
        texture = (node as TextureRect).texture
        var rect := node as TextureRect
        if texture and rect.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
            _fail("%s sem keep aspect" % node.get_path())
            return count
    elif node is TextureButton:
        texture = (node as TextureButton).texture_normal
    elif node is TextureProgressBar:
        texture = (node as TextureProgressBar).texture_progress
    if texture == null:
        return count
    var path := texture.resource_path
    if texture is AtlasTexture:
        # Recorte de exibição do popup: a região tem de conter o cartão inteiro.
        var atlas := texture as AtlasTexture
        path = atlas.atlas.resource_path
        var full := Rect2(Vector2.ZERO, atlas.atlas.get_size())
        if not full.encloses(atlas.region) or atlas.region.end.y != full.end.y or atlas.region.size.x != full.size.x:
            _fail("região do popup corta o cartão: %s" % atlas.region)
            return count
    if path.contains("reference") or path == "res://assets/sales/money_bundle.png":
        _fail("textura proibida: " + path)
        return count
    var allowed := path == OFFICIAL_CASH
    for prefix in ALLOWED_TEXTURE_PREFIXES:
        allowed = allowed or path.begins_with(prefix)
    if not allowed:
        _fail("textura fora do pacote UI-004: %s em %s" % [path, node.get_path()])
        return count
    # Controles com tamanho próprio precisam manter a proporção do PNG.
    if node is TextureButton:
        var button := node as TextureButton
        var aspect_png := float(texture.get_width()) / float(texture.get_height())
        var aspect_node := button.size.x / button.size.y
        if button.stretch_mode != TextureButton.STRETCH_KEEP_ASPECT_CENTERED and absf(aspect_png - aspect_node) > 0.02:
            _fail("%s distorcido" % node.get_path())
            return count
    return count + 1
