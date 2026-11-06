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

    # 9. QA de assets: só PNGs do pacote UI v5; dinheiro = maço oficial;
    # nenhuma imagem de referência; nenhum PNG cortado ou distorcido.
    hud.reward_popup.show_reward("Recompensa!", "Missão concluída!", 25)
    var probe := hud.show_sale_popup(6, 2)
    await create_timer(0.5).timeout
    # Retângulo visível real do aviso (inclui escala em torno do centro).
    var probe_rect := probe.get_global_transform() * Rect2(Vector2.ZERO, probe.size)
    if not Rect2(Vector2.ZERO, hud.root_control.size).encloses(probe_rect):
        return _fail("aviso de venda sai da tela: %s" % probe_rect)
    var checked := _check_textures(hud.root_control)
    if _failed:
        return
    if checked < 15:
        return _fail("poucas texturas verificadas: %d" % checked)
    # 10. Todos os componentes dentro da tela, sem cobrir o joystick nem o centro
    # da tela (fazendeiro/canteiro). 720x1280 e 1080x1920 dão a mesma área lógica
    # 1280 x 2275 (expand); desktop 1280x720 e 1920x1080 dão 1280 x 720.
    var joystick := world.get_node("HUD/VirtualJoystick") as Control
    for screen in [Vector2(1280, 720), Vector2(1280, 2275), Vector2(1600, 720)]:
        hud.layout_for(screen)
        var bounds := Rect2(Vector2.ZERO, screen)
        for control in [hud.level_panel, hud.mission_panel, hud.money_counter, hud.tomato_counter, hud.crate_counter, hud.store_button, hud.info_banner]:
            var r := (control as Control).get_global_rect()
            if not bounds.encloses(r):
                return _fail("%s fora da tela %s: %s" % [control.name, screen, r])
        var popup_zone := Rect2(hud.sale_popups.global_position, FarmHUD.SALE_POPUP_SCENE_SIZE * FarmHUD.SALE_POPUP_SCALE * (FarmHUD.PORTRAIT_BOOST if screen.y > screen.x else 1.0) * Vector2(1, 2.1))
        if popup_zone.intersects(hud.info_banner.get_global_rect()) or not bounds.encloses(popup_zone):
            return _fail("avisos de venda sobre a faixa ou fora da tela em %s" % screen)
        if hud.level_panel.get_global_rect().intersects(hud.money_counter.get_global_rect()) or hud.mission_panel.get_global_rect().intersects(hud.info_banner.get_global_rect()):
            return _fail("sobreposição em %s" % screen)
        var joystick_rect := Rect2(Vector2(28, screen.y - 250), joystick.size)
        var center := Rect2(screen * 0.5 - Vector2(220, 100), Vector2(440, 200))
        for control in [hud.level_panel, hud.mission_panel, hud.money_counter, hud.tomato_counter, hud.crate_counter, hud.store_button, hud.info_banner]:
            var r := (control as Control).get_global_rect()
            if r.intersects(joystick_rect) or r.intersects(center):
                return _fail("%s cobre joystick/centro em %s" % [control.name, screen])
    hud.layout()
    var viewport_rect := Rect2(Vector2.ZERO, hud.root_control.size)
    var card := hud.reward_popup.card.get_global_rect()
    if not viewport_rect.encloses(card):
        return _fail("popup fora da tela: %s em %s" % [card, viewport_rect])
    print("HUD_QA textures=%d layouts=3 card=%s" % [checked, card])
    await _qa_v5(world)
    if _failed:
        return
    print("HUD_SMOKE_OK")
    quit(0)

## Testes do prompt de QA UI v5: valores extremos, atualização única, sem
## crédito duplicado e estados dos CTAs.
func _qa_v5(world: FarmWorld) -> void:
    var hud := world.hud
    var wallet := world.wallet
    var inventory := world.harvest_inventory
    # Dinheiro: 0, 1, 999, 1.250 e 9.999.999 sem truncar.
    for pair in [[0, "0"], [1, "1"], [999, "999"], [1250, "1.250"], [9999999, "9.999.999"]]:
        wallet.set_balance(pair[0])
        var label := hud.money_counter.get_value_label()
        if hud.get_money_text() != pair[1] or UiStyle.text_width(label) > label.size.x:
            return _fail("dinheiro %s: '%s' largura %.0f/%.0f" % [pair[1], hud.get_money_text(), UiStyle.text_width(label), label.size.x])
        print("QA_MONEY %s font=%d width=%.0f/%.0f" % [pair[1], label.get_theme_font_size("font_size"), UiStyle.text_width(label), label.size.x])
    # Tomates 0/56, 18/56, 56/56 e caixas 0/7, 3/7, 7/7 pela mochila real.
    for pair in [[0, "0/56", "0/7"], [18, "18/56", "3/7"], [56, "56/56", "7/7"]]:
        inventory.set_amount(&"tomato", pair[0])
        var tomato := hud.tomato_counter.get_value_label()
        var crate := hud.crate_counter.get_value_label()
        if hud.get_tomato_text() != pair[1] or hud.get_crate_text() != pair[2] or UiStyle.text_width(tomato) > tomato.size.x or UiStyle.text_width(crate) > crate.size.x:
            return _fail("mochila %s: %s %s" % [pair[0], hud.get_tomato_text(), hud.get_crate_text()])
        print("QA_BACKPACK %s %s" % [pair[1], pair[2]])
    if hud.reward_popup.is_open:
        hud.reward_popup.collect()
    inventory.set_amount(&"tomato", 0)
    # Uma atualização do contador por mudança; nenhuma quando o valor não muda.
    wallet.set_balance(100)
    var updates := hud.money_counter.update_count
    wallet.add(5, &"qa")
    if hud.money_counter.update_count != updates + 1:
        return _fail("contador atualizou %d vezes" % (hud.money_counter.update_count - updates))
    wallet.add(0, &"qa")
    hud.refresh()
    if hud.money_counter.update_count != updates + 1:
        return _fail("atualização sem mudança de valor")
    # Abrir o popup não cria dinheiro; coletar várias vezes credita uma vez só.
    var tracker := world.mission_tracker
    var before := wallet.get_balance()
    hud.reward_popup.show_reward("Recompensa!", "Teste", 50)
    if wallet.get_balance() != before:
        return _fail("abrir popup criou dinheiro")
    hud.reward_popup.collect()
    await create_timer(0.3).timeout
    tracker.add_progress(int(MissionTracker.MISSIONS[tracker.index]["kind"]), 100000)
    var reward := int(tracker.get_current()["reward"])
    before = wallet.get_balance()
    hud.reward_popup.collect_button.pressed.emit()
    hud.reward_popup.collect_button.pressed.emit()
    hud.reward_popup.collect()
    if wallet.get_balance() != before + reward:
        return _fail("crédito duplicado: %d -> %d (prêmio %d)" % [before, wallet.get_balance(), reward])
    print("QA_SIGNALS single_update=ok reward_once=%d" % reward)
    # CTA: tamanho proporcional ao PNG v5 (sem fator extra de 1,3) e estados.
    await create_timer(0.4).timeout
    var scene := load("res://scenes/ui/hud/components/CtaButton.tscn") as PackedScene
    var cta := scene.instantiate() as CtaButton
    hud.root_control.add_child(cta)
    cta.position = Vector2(400, 300)
    cta.color = "orange"
    cta.text = "Comprar"
    cta.fit_height(86)
    await process_frame
    var tex := cta.texture_normal
    var png_aspect := float(tex.get_width()) / float(tex.get_height())
    if tex.get_width() != 606 or cta.stretch_mode != TextureButton.STRETCH_KEEP_ASPECT_CENTERED or absf(png_aspect - cta.size.x / cta.size.y) > 0.01:
        return _fail("CTA laranja %s aspecto %.2f" % [tex.get_size(), png_aspect])
    var states := []
    states.append(cta.get_state_name())
    # Sinais que a Godot emite com mouse/toque reais.
    cta.mouse_entered.emit()
    states.append(cta.get_state_name())
    var hover_tint := cta.self_modulate
    cta.button_down.emit()
    states.append(cta.get_state_name())
    var pressed_tint := cta.self_modulate
    var pressed_scale := cta.scale.x
    cta.button_up.emit()
    cta.mouse_exited.emit()
    if hover_tint == Color.WHITE or pressed_tint == hover_tint or pressed_scale >= 1.0:
        return _fail("CTA sem diferença visual em hover/pressed")
    cta.grab_focus()
    await process_frame
    states.append(cta.get_state_name())
    var focus_visible := cta.focus_ring.visible
    cta.set_enabled(false)
    states.append(cta.get_state_name())
    print("QA_CTA states=%s focus_ring=%s" % [states, focus_visible])
    if states[0] != "normal" or not states[1].begins_with("hover") or not states[2].begins_with("pressed") or not states[3].ends_with("+focus") or states[4] != "disabled" or not focus_visible:
        return _fail("estados do CTA: %s" % [states])
    if cta.self_modulate == Color.WHITE:
        return _fail("CTA desabilitado sem diferença visual")
    cta.queue_free()

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
        # Só a margem transparente de segurança pode ficar fora da região exibida.
        var atlas := texture as AtlasTexture
        path = atlas.atlas.resource_path
        var image := atlas.atlas.get_image()
        if image.is_compressed():
            image.decompress()
        var region := Rect2i(atlas.region)
        for y in image.get_height():
            for x in image.get_width():
                if not region.has_point(Vector2i(x, y)) and image.get_pixel(x, y).a > 0.02:
                    _fail("região de %s corta pixel visível (%d, %d)" % [path, x, y])
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
