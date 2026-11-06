extends SceneTree
## Teste do Balcão de vendas, da base de dinheiro 3 x 5 e das vendas aos clientes.
## Uso: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/sales_counter_smoke.gd

const STEP := 0.05

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SALES_SMOKE_FAIL " + message)
    print("SALES_SMOKE_FAIL ", message)
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
    var counter := world.sales_counter
    var inventory := world.harvest_inventory

    # 1. Nome e largura dobrada (antigo depósito: 4,25 m).
    if counter.name != "SalesCounter" or world.get_node_or_null("TomatoDepot") != null:
        return _fail("nome do balcão")
    var half := counter.get_half_extents()
    # 8,5 m (largura dobrada) x 1,3 = 11,05 m; fundo 2,25 x 1,3 = 2,925 m.
    if not is_equal_approx(half.x * 2.0, 8.5 * 1.3) or not is_equal_approx(half.y * 2.0, 2.25 * 1.3) or not is_equal_approx(SalesCounter.CRATE_WIDTH, 1.3 * 1.3):
        return _fail("largura %.2f" % (half.x * 2.0))
    print("COUNTER width=%.2f depth=%.2f z=%.2f" % [half.x * 2.0, half.y * 2.0, counter.global_position.z])

    # 2. Descarga: longe não descarrega; encostado em qualquer ponto da frente, sim.
    inventory.set_amount(&"tomato", 56)
    counter.process_farmer_position(counter.global_position + Vector3(0.0, 0.0, -half.y - 2.5))
    if inventory.get_total() != 56:
        return _fail("descarregou de longe")
    counter.process_farmer_position(counter.global_position + Vector3(half.x - 0.3, 0.0, -half.y - 0.5))
    if inventory.get_total() != 0 or counter.get_stored_total() != 56 or counter.get_displayed_crates() != 7:
        return _fail("descarga na ponta do balcão: estoque %d" % counter.get_stored_total())
    # Toda a produção cabe: mais 3 mochilas cheias.
    for i in 3:
        inventory.set_amount(&"tomato", 56)
        counter.deposit_from(inventory)
    if counter.get_stored_total() != 224 or counter.get_stock_crates() != 28 or counter.get_displayed_crates() != 28:
        return _fail("produção inteira: %d unidades, %d caixas" % [counter.get_stored_total(), counter.get_displayed_crates()])
    print("DEPOSIT stored=%d crates=%d" % [counter.get_stored_total(), counter.get_displayed_crates()])

    # 2b. Caixas do balcão = arte das caixas da mochila; 2 fileiras (uma na frente da outra).
    if counter.get_crate_texture(0) != BackpackCrates.CRATE_FULL_TEXTURE:
        return _fail("balcão sem a arte das caixas da mochila")
    var back := counter.get_crate_slot_position(0)
    var front := counter.get_crate_slot_position(SalesCounter.COLUMNS)
    if SalesCounter.ROWS_PER_LAYER < 2 or not is_equal_approx(back.x, front.x) or front.z - back.z < 0.9 \
            or absf(back.z - counter.global_position.z) + SalesCounter.CRATE_SPACING.z * 0.5 > half.y + 0.1:
        return _fail("2 caixas uma na frente da outra não cabem: trás %s frente %s" % [back, front])
    counter.set_stored_total(13)
    if counter.get_crate_texture(1) != BackpackCrates.CRATE_EMPTY_TEXTURE or counter.get_crate_texture(0) != BackpackCrates.CRATE_FULL_TEXTURE:
        return _fail("caixa incompleta sem a arte parcial")
    print("COUNTER_CRATES art=crate_full rows=%d back_z=%.2f front_z=%.2f depth=%.2f" % [SalesCounter.ROWS_PER_LAYER, back.z, front.z, half.y * 2.0])

    # 2c. Descarga animada: as caixas pulam das mãos do fazendeiro até a pilha.
    counter.set_stored_total(0)
    world.farmer.global_position = counter.global_position + Vector3(1.0, 0.0, -half.y - 0.6)
    var hands := world.get_farmer_hands_position()
    inventory.set_amount(&"tomato", 32)
    counter.process_farmer_position(world.farmer.global_position, hands)
    if counter.get_displayed_crates() != 4 or counter.get_visible_crate_count() != 0 or counter.get_flying_crate_count() != 4:
        return _fail("pulo: lógicas %d, visíveis %d, no ar %d" % [counter.get_displayed_crates(), counter.get_visible_crate_count(), counter.get_flying_crate_count()])
    var peak := -INF
    var waited := 0.0
    var landed_order: Array[int] = []
    while counter.get_flying_crate_count() > 0 and waited < 3.0:
        var flyer := counter.get_node_or_null("JumpingCrate_00") as Node3D
        if flyer:
            peak = maxf(peak, flyer.global_position.y)
        await process_frame
        waited += get_root().get_process_delta_time()
        if counter.get_visible_crate_count() > landed_order.size():
            landed_order.append(counter.get_visible_crate_count())
    var log0: Dictionary = counter.jump_log[0]
    var top_end := maxf((log0["from"] as Vector3).y, (log0["to"] as Vector3).y)
    if counter.get_flying_crate_count() != 0 or counter.get_visible_crate_count() != 4:
        return _fail("caixas não pousaram")
    if not (log0["from"] as Vector3).is_equal_approx(hands) or not (log0["to"] as Vector3).is_equal_approx(counter.get_crate_slot_position(0)):
        return _fail("pulo não sai das mãos para o lugar da pilha")
    if peak < top_end + 0.8:
        return _fail("sem arco de pulo: pico %.2f, ponta %.2f" % [peak, top_end])
    if landed_order.size() < 2:
        return _fail("caixas pousaram todas juntas")
    print("CRATE_JUMP crates=4 from_hands=%s peak=%.2f above_ends=%.2f land_time=%.2fs staggered=%s" % [hands, peak, peak - top_end, waited, landed_order])
    counter.set_stored_total(224)

    # 3. Colisão: o fazendeiro não atravessa o balcão nem passa pelas pontas.
    var farmer := world.farmer
    farmer.set_physics_process(false)
    var front_z := counter.global_position.z - half.y
    for x in [0.0, 3.5, -half.x - 2.0, 12.0, -25.0]:
        farmer.global_position = Vector3(x, 0.05, front_z - 2.5)
        farmer.velocity = Vector3.ZERO
        await physics_frame
        for i in 150:
            farmer.velocity = Vector3(0.0, -0.5, 4.0)
            farmer.move_and_slide()
            await physics_frame
        # No balcão para na frente; nas cercas laterais (linha central), antes dela.
        var limit_z := front_z if absf(x) < half.x else counter.global_position.z - 0.15
        if farmer.global_position.z + 0.45 > limit_z + 0.05:
            return _fail("fazendeiro passou do balcão em x=%.1f: z=%.2f" % [x, farmer.global_position.z])
        print("BLOCKED x=%.1f farmer_z=%.2f counter_front=%.2f" % [x, farmer.global_position.z, front_z])
    farmer.global_position = Vector3(0.0, 1.0, 0.0)

    # 4. Base de dinheiro 3 x 5 no lado do fazendeiro, ao lado do balcão.
    var money := world.money_stack
    if MoneyStack.COLUMNS != 3 or MoneyStack.ROWS != 5 or MoneyStack.SLOTS != 15:
        return _fail("base não é 3 x 5")
    var base_far_z := money.global_position.z + MoneyStack.ROWS * MoneyStack.CELL_SIZE.y * 0.5 + MoneyStack.BASE_MARGIN
    var base_near_x := money.global_position.x - MoneyStack.COLUMNS * MoneyStack.CELL_SIZE.x * 0.5 - MoneyStack.BASE_MARGIN
    if base_far_z >= counter.global_position.z or base_near_x <= counter.global_position.x + half.x:
        return _fail("base de dinheiro fora do lado do fazendeiro")
    # Bloco fino de madeira clara, cantos arredondados, sob toda a grade 3 x 5.
    var corners := money.get_children().filter(func(n): return n is MeshInstance3D and (n as MeshInstance3D).mesh is CylinderMesh)
    var base_size := MoneyStack.get_base_size()
    if corners.size() != 8 or base_size.y > 0.1 or base_size.x < MoneyStack.COLUMNS * MoneyStack.CELL_SIZE.x or base_size.z < MoneyStack.ROWS * MoneyStack.CELL_SIZE.y:
        return _fail("base de madeira: %d cantos, tamanho %s" % [corners.size(), base_size])
    var top := money.get_node("WoodBaseTop_X") as MeshInstance3D
    var wood := (top.material_override as StandardMaterial3D).albedo_color
    if not (wood.r > wood.g and wood.g > wood.b and wood.v > 0.7):
        return _fail("cor da madeira %s" % wood)
    # Sprite novo: cantos transparentes (fundo xadrez removido), centro opaco.
    var art := MoneyStack.MONEY_TEXTURE.get_image()
    if art.get_pixel(1, 1).a > 0.1 or art.get_pixel(art.get_width() / 2, art.get_height() / 2).a < 0.9:
        return _fail("sprite do dinheiro sem transparência")
    print("MONEY_BASE wood=%s size=%.2fx%.2fx%.2f corners=%d art=%s" % [wood, base_size.x, base_size.y, base_size.z, corners.size(), art.get_size()])
    # Base compacta: pilhas encostadas (posição = tamanho do maço) e borda fina.
    if not MoneyStack.CELL_SIZE.is_equal_approx(Vector2(MoneyStack.BUNDLE_WIDTH, MoneyStack.BUNDLE_WIDTH * 276.0 / 512.0 * MoneyStack.VIEW_STRETCH)):
        return _fail("vão entre pilhas: posição %s" % MoneyStack.CELL_SIZE)
    var art_aspect := float(art.get_height()) / float(art.get_width())
    if absf(art_aspect - MoneyStack.ART_ASPECT) > 0.005:
        return _fail("proporção da arte %.3f" % art_aspect)
    var gap := money.get_slot_position(1).x - money.get_slot_position(0).x - MoneyStack.CELL_SIZE.x
    if absf(gap) > 0.001 or MoneyStack.BASE_MARGIN > 0.12:
        return _fail("pilhas afastadas %.3f / borda %.2f" % [gap, MoneyStack.BASE_MARGIN])
    print("MONEY_COMPACT cell=%s gap=%.3f base=%.2fx%.2f margin=%.2f" % [MoneyStack.CELL_SIZE, gap, base_size.x, base_size.z, MoneyStack.BASE_MARGIN])
    money.add_money(20)
    if money.get_visible_bundles() != 20 or money.get_slot_height(0) != 2 or money.get_slot_height(4) != 2 or money.get_slot_height(5) != 1 or money.get_slot_height(14) != 1:
        return _fail("empilhamento: visíveis %d" % money.get_visible_bundles())
    money.add_money(10000)
    if money.get_visible_bundles() != money.get_capacity_visual() or money.get_balance() != 10020:
        return _fail("pilha máxima")
    money.set_balance(0)
    if money.get_visible_bundles() != 0 or world.hud.get_money_text() != "0":
        return _fail("zerar saldo / HUD: %s" % world.hud.get_money_text())

    # 4b. Tocar uma pilha esvazia só ela e o valor vai para a carteira (HUD).
    var wallet := world.wallet
    money.add_money(30)
    var touch := money.to_global(money.get_slot_position(7))
    if money.collect_at(money.global_position + Vector3(0.0, 0.0, -20.0), wallet) != 0:
        return _fail("recolheu de longe")
    var got := money.collect_at(touch, wallet)
    if got != 2 or money.get_slot_amount(7) != 0 or money.get_balance() != 28 or wallet.get_balance() != 2 or world.hud.get_money_text() != "2":
        return _fail("toque na pilha: %d, base %d, carteira %d, HUD %s" % [got, money.get_balance(), wallet.get_balance(), world.hud.get_money_text()])
    if money.collect_at(touch, wallet) != 0:
        return _fail("pilha vazia recolhida de novo")
    # Andando por cima de todas as pilhas recolhe tudo.
    for slot in MoneyStack.SLOTS:
        money.collect_at(money.to_global(money.get_slot_position(slot)), wallet)
    if money.get_balance() != 0 or money.get_visible_bundles() != 0 or wallet.get_balance() != 30 or world.hud.get_money_text() != "30":
        return _fail("recolher tudo: base %d carteira %d" % [money.get_balance(), wallet.get_balance()])
    # Nova venda volta a empilhar primeiro nas pilhas vazias; o saldo é reutilizável.
    money.add_money(3)
    if money.get_slot_height(0) != 1 or money.get_slot_height(2) != 1 or money.get_slot_height(3) != 0:
        return _fail("reempilhar após recolher")
    if not wallet.can_afford(30) or wallet.spend(31) or not wallet.spend(10) or wallet.get_balance() != 20:
        return _fail("gastar saldo")
    print("MONEY_COLLECT slot7=2 all=30 wallet_after_spend=%d hud=%s" % [wallet.get_balance(), world.hud.get_money_text()])
    money.set_balance(0)
    wallet.set_balance(0)

    # 5. Preço: 1 caixa = 3, proporcional.
    var sales := world.sales_controller
    var prices := [sales.price_for_units(8), sales.price_for_units(16), sales.price_for_units(24), sales.price_for_units(4)]
    if prices != [3, 6, 9, 2]:
        return _fail("preços %s" % [prices])

    # 6. Vendas com a fila: compras sorteadas de 1-3 caixas enquanto houver estoque.
    var queue := world.customer_queue
    queue.set_seed(20261106)
    sales.set_seed(7)
    counter.set_stored_total(80)
    var t := 0.0
    var max_total := 0
    while t < 400.0 and counter.get_stored_total() > 0:
        _advance(world, STEP)
        t += STEP
        max_total = maxi(max_total, queue.get_total_customers())
    if counter.get_stored_total() != 0:
        return _fail("estoque não acabou em 400 s: %d" % counter.get_stored_total())
    var sold_units := 0
    var paid := 0
    var amounts := {}
    for sale in sales.sales_log:
        if sale["crates"] < 1 or sale["crates"] > 3:
            return _fail("compra de %d caixas" % sale["crates"])
        if sale["money"] != sales.price_for_units(sale["units"]):
            return _fail("pagamento errado")
        if sale["carried"] != sale["crates"]:
            return _fail("cliente não leva as caixas")
        sold_units += sale["units"]
        paid += sale["money"]
        amounts[sale["crates"]] = true
    if sold_units != 80 or paid != 30 or money.get_balance() != 30 or money.get_visible_bundles() != 30:
        return _fail("vendido %d, pago %d, saldo %d" % [sold_units, paid, money.get_balance()])
    if amounts.size() < 2:
        return _fail("compras sem variação: %s" % [amounts.keys()])
    if max_total > queue.max_customers:
        return _fail("mais de %d clientes" % queue.max_customers)
    print("SALES count=%d crates=%s money=%d time=%.1fs" % [sales.sales_log.size(), sales.sales_log.map(func(s): return s["crates"]), money.get_balance(), t])

    # 7. Sem estoque: ninguém compra e a paciência de 15-20 s volta a valer.
    var sales_before := sales.sales_log.size()
    var leaves_before := queue.leave_log.size()
    var t2 := 0.0
    while t2 < 60.0:
        _advance(world, STEP)
        t2 += STEP
    if sales.sales_log.size() != sales_before:
        return _fail("venda sem estoque")
    if queue.leave_log.size() <= leaves_before:
        return _fail("ninguém desistiu sem estoque")
    # Reabastecido: o primeiro da fila volta a comprar.
    counter.set_stored_total(8)
    t2 = 0.0
    while t2 < 30.0 and sales.sales_log.size() == sales_before:
        _advance(world, STEP)
        t2 += STEP
    if sales.sales_log.size() != sales_before + 1 or counter.get_stored_total() != 0 or money.get_balance() != 33:
        return _fail("venda após reabastecer")
    print("SALES_SMOKE_OK width=11.05 blocked=5 base=3x5 sales=%d money=%d" % [sales.sales_log.size(), money.get_balance()])
    quit()
