extends SceneTree
## Testes headless da colheita FV-HARVEST-001 (código de saída 1 em falha).
## Uso: Godot --headless --path . -s tools/harvest_smoke.gd
##
## Invariante central, checado em todos os cenários:
##   tomates na mochila + frutos restantes nas plantas == produção inicial
## (nenhuma duplicação, nenhum fruto perdido).

const ITEM := &"tomato"

var _failures := 0
var world: FarmWorld
var _initial_total := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error("HARVEST_SMOKE_FAIL: " + message)

func _run() -> void:
    _test_inventory_math()
    await _test_backpack_states()
    await _test_grid_spacing()
    await _test_front_middle_back_and_moving_target()
    await _test_replant_gate()
    await _test_walk_harvest_ten_plants()
    await _test_capacity_full_keeps_fruit()
    await _test_cancel_by_leaving_field()
    await _test_cancel_on_scene_exit()
    await _test_reload_mid_flight()
    await _test_approach_from_all_sides()
    if _failures > 0:
        print("HARVEST_SMOKE_FAILED failures=", _failures)
        quit(1)
        return
    print("HARVEST_SMOKE_OK")
    quit()

# --- Helpers ---------------------------------------------------------------

func _load_world(ripe_filter: Callable = Callable()) -> void:
    if world:
        world.queue_free()
        await process_frame
    world = (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    # Sem semeadura automática nem câmera seguindo: só a colheita roda.
    world.set_process(false)
    world.harvest_controller.enabled = false
    _initial_total = 0
    for cell in world.planting_grid.cells.values():
        if ripe_filter.is_null() or ripe_filter.call(cell):
            world.spawn_crop_at_stage(cell["id"], CropPlant.STAGES.size() - 1)
            _initial_total += world.planting_grid.get_remaining_yield(cell["id"])
    world.farmer.global_position = Vector3(-20.0, 0.0, -20.0)
    await process_frame

func _remaining_total() -> int:
    var total := 0
    for cell in world.planting_grid.cells.values():
        total += int(cell["remaining_yield"])
    return total

func _check_conservation(label: String) -> void:
    var carried := world.harvest_inventory.get_total()
    _check(carried + _remaining_total() == _initial_total,
        "%s: mochila (%d) + plantas (%d) deve ser %d" % [label, carried, _remaining_total(), _initial_total])
    _check(carried <= world.harvest_inventory.get_capacity(), "%s: mochila acima da capacidade" % label)

func _wait_jobs(timeout := 4.0) -> void:
    var start := Time.get_ticks_msec()
    while world.harvest_controller.get_active_job_count() > 0 and Time.get_ticks_msec() - start < timeout * 1000.0:
        await process_frame

func _wait_seconds(seconds: float) -> void:
    var start := Time.get_ticks_msec()
    while Time.get_ticks_msec() - start < seconds * 1000.0:
        await process_frame

func _cell_at(module: int, row: int, column: int) -> Dictionary:
    return world.planting_grid.cells["PlantingPlot_%02d_r%02d_c%02d" % [module, row, column]]

func _count_state(state: String) -> int:
    return world.planting_grid.cells.values().filter(func(c: Dictionary) -> bool: return c["state"] == state).size()

# --- Testes ----------------------------------------------------------------

## Mede o menor intervalo entre centros, inclusive nas bordas das tiras.
func _test_grid_spacing() -> void:
    await _load_world(func(_c: Dictionary) -> bool: return false)
    var grid := world.planting_grid
    var cells := grid.cells.values()
    _check(cells.size() == FarmWorld.PLANTING_PLOT_COUNT * grid.columns * grid.rows_per_module,
        "Espaçamento: quantidade de células")
    var nearest := INF
    for i in cells.size():
        var a: Vector3 = cells[i]["position"]
        for j in range(i + 1, cells.size()):
            var b: Vector3 = cells[j]["position"]
            nearest = minf(nearest, Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)))
    var gap := world.planting_plot_spacing.x - FarmWorld.PLANTING_PLOT_WIDTH * (1.0 - 1.0 / grid.columns)
    _check(nearest > 0.01 and is_equal_approx(nearest, gap),
        "Espaçamento real esperado %.3f m, obtido %.3f m" % [gap, nearest])
    _check(is_equal_approx(grid.get_cell_spacing(), nearest),
        "get_cell_spacing deve medir os centros reais: %.3f m, obtido %.3f m" % [nearest, grid.get_cell_spacing()])
    _check(is_equal_approx(world.harvest_controller.get_harvest_radius(),
        grid.get_cell_spacing() * world.harvest_controller.radius_multiplier),
        "Raio da colheita segue o multiplicador")
    print("GRID_SPACING measured=", snappedf(nearest, 0.001),
        " reported=", snappedf(grid.get_cell_spacing(), 0.001))

## O reset só ocorre após colher a última célula; a planta é removida.
func _test_replant_gate() -> void:
    var first_id := "PlantingPlot_02_r03_c01"
    var last_id := "PlantingPlot_03_r04_c01"
    await _load_world(func(c: Dictionary) -> bool: return c["id"] in [first_id, last_id])
    var grid := world.planting_grid
    var controller := world.harvest_controller
    var first_crop := world.crops[first_id] as CropPlant
    var last_crop := world.crops[last_id] as CropPlant
    for cell in grid.cells.values():
        if cell["id"] not in [first_id, last_id]:
            cell["state"] = PlantingGrid.STATE_HARVESTED
            cell["remaining_yield"] = 0
    _check(not grid.reset_if_fully_harvested(), "Reset bloqueado com duas plantas maduras")
    world.farmer.global_position = grid.get_cell_world_position(first_id)
    _check(controller.request_collect(first_id), "Primeira coleta iniciada")
    _check(not grid.plant_cell(first_id), "Plantio bloqueado durante HARVESTING")
    await _wait_jobs()
    await process_frame
    _check(controller.get_active_job_count() == 0, "Primeira coleta terminou")
    _check(grid.cells[first_id]["state"] == PlantingGrid.STATE_HARVESTED,
        "Primeira célula permanece HARVESTED")
    _check(not grid.plant_cell(first_id), "Plantio bloqueado enquanto sobra planta madura")
    _check(not world.crops.has(first_id) and not is_instance_valid(first_crop),
        "Primeira planta liberada e removida do mapa")
    _check(world.crops.has(last_id), "Última planta ainda existe")
    _check(not grid.reset_if_fully_harvested(), "Reset manual bloqueado antes da última coleta")
    world.farmer.global_position = grid.get_cell_world_position(last_id)
    _check(controller.request_collect(last_id), "Última coleta iniciada")
    await _wait_jobs()
    await process_frame
    _check(controller.get_active_job_count() == 0, "Última coleta terminou")
    _check(not world.crops.has(last_id) and not is_instance_valid(last_crop),
        "Última planta liberada e removida do mapa")
    _check(grid.get_planting_progress()["remaining"] == grid.cells.size(),
        "Grade inteira EMPTY após última coleta")
    _check(not grid.reset_if_fully_harvested(), "Reset repetido bloqueado")
    _check(grid.plant_cell(first_id), "Replantio permitido após reset completo")
    _check(grid.cells[first_id]["state"] == "SEEDED", "Nova safra em SEEDED")
    _check(world.harvest_inventory.get_total() == 2 * controller.yield_per_crop,
        "Duas plantas colhidas uma vez")
    _check_conservation("replantio")
    print("REPLANT_GATE carried=", world.harvest_inventory.get_total(),
        " remaining=", grid.get_planting_progress()["remaining"])

func _test_inventory_math() -> void:
    var inventory := HarvestInventory.new()
    _check(inventory.get_capacity() == 56, "Capacidade 7 x 8 = 56")
    var expected := {0: [0, 0], 1: [1, 0], 8: [1, 1], 9: [2, 1], 55: [7, 6], 56: [7, 7]}
    for amount in expected:
        inventory.set_amount(ITEM, amount)
        _check(inventory.get_crate_count() == expected[amount][0], "%d unidades -> %d caixas" % [amount, expected[amount][0]])
        _check(inventory.get_full_crate_count() == expected[amount][1], "%d unidades -> %d caixas cheias" % [amount, expected[amount][1]])
    inventory.set_amount(ITEM, 0)
    var big := inventory.try_reserve(ITEM, 80)
    _check(big.amount == 56, "Reserva limitada à capacidade livre")
    _check(not inventory.try_reserve(ITEM, 1).is_valid(), "Sem capacidade livre, nova reserva é inválida")
    _check(inventory.commit(big, 10) == 10 and inventory.get_total() == 10, "Confirmação parcial")
    _check(inventory.cancel(big) == 46 and inventory.get_free_capacity() == 46, "Cancelar devolve só o pendente")
    _check(inventory.commit(big, 5) == 0 and inventory.get_total() == 10, "Reserva cancelada não confirma de novo")
    var rest := inventory.try_reserve(ITEM, 50)
    inventory.commit(rest)
    _check(inventory.get_total() == 56 and inventory.is_full(), "Mochila cheia em 56")
    _check(inventory.commit(rest) == 0, "Commit repetido não duplica")
    var restored := HarvestInventory.new()
    restored.from_dict(inventory.to_dict())
    _check(restored.get_total() == 56, "Save/load do inventário")
    inventory.free()
    restored.free()
    print("INVENTORY_OK capacity=56 states=0/1/8/9/55/56")

func _test_backpack_states() -> void:
    await _load_world(func(_c: Dictionary) -> bool: return false)
    var backpack := world.backpack
    # [caixas visíveis, caixas cheias, mini tomates na parcial]
    var expected := {0: [0, 0, 0], 1: [1, 0, 1], 8: [1, 1, 0], 9: [2, 1, 1], 55: [7, 6, 7], 56: [7, 7, 0]}
    for amount in expected:
        world.harvest_inventory.set_amount(ITEM, amount)
        await process_frame
        _check(backpack.get_visible_crate_count() == expected[amount][0], "Mochila %d: caixas visíveis" % amount)
        _check(backpack.get_full_crate_count() == expected[amount][1], "Mochila %d: caixas cheias (crate_full)" % amount)
        var top := backpack.stack_root.get_child(maxi(0, expected[amount][0] - 1))
        var minis: int = top.get_node("PartialFill").get_children().filter(func(n: Node3D) -> bool: return n.visible).size()
        _check(minis == expected[amount][2], "Mochila %d: %d mini tomates na caixa parcial (obtido %d)" % [amount, expected[amount][2], minis])
    # Pilha cresce para cima, nunca abaixo do ponto de fixação, e não colide.
    var base_y := backpack.stack_root.global_position.y
    var last := backpack.stack_root.get_child(6) as Node3D
    _check(last.global_position.y > base_y + 2.0, "Sétima caixa empilhada acima das outras")
    _check(backpack.find_children("*", "CollisionObject3D", true, false).is_empty(), "Caixas não colidem com o jogador")
    var to_farmer := backpack.global_position - world.farmer.global_position
    _check(Vector2(to_farmer.x, to_farmer.z).length() > 0.45, "Pilha fora do corpo do fazendeiro (raio 0.45)")
    print("BACKPACK_STATES_OK 0/1/8/9/55/56")

## Uma planta da frente, do meio e do fundo, com o fazendeiro andando e virando
## durante o voo: os frutos terminam no marcador móvel.
func _test_front_middle_back_and_moving_target() -> void:
    await _load_world()
    var controller := world.harvest_controller
    var arrival_errors: Array[float] = []
    for row in [0, 3, 6]:
        var cell := _cell_at(2, row, 1)
        var cell_pos: Vector3 = cell["position"]
        var crop := world.crops[cell["id"]] as CropPlant
        world.farmer.global_position = cell_pos + Vector3(0.0, 0.0, -1.0)
        await process_frame
        _check(controller.request_collect(cell["id"]), "Fileira %d: coleta iniciada" % row)
        _check(not controller.request_collect(cell["id"]), "Fileira %d: segunda coleta simultânea bloqueada" % row)
        _check(cell["state"] == PlantingGrid.STATE_HARVESTING, "Fileira %d em HARVESTING" % row)
        var fx: TomatoPickupFX = controller._jobs[cell["id"]]["fx"]
        var fruits := fx.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("PickupTomato"))
        _check(fruits.size() >= 3 and fruits.size() <= 5, "Fileira %d: 3 a 5 tomates visuais" % row)
        for fruit in fruits:
            var p: Vector3 = (fruit as Node3D).global_position
            _check(Vector2(p.x - cell_pos.x, p.z - cell_pos.z).length() <= float(cell["cell_width"]), "Fruto nasce na célula associada")
            _check(p.y > 0.3, "Fruto nasce na copa, acima do solo")
        # O erro é medido pelo FX antes da confirmação (que sobe o marcador para a próxima caixa).
        fx.fruit_arrived.connect(func(_index: int) -> void: arrival_errors.append(fx.get_max_arrival_error()))
        # Anda para a direita e dá um giro brusco para a esquerda no meio do voo.
        var start := Time.get_ticks_msec()
        var last_tick := start
        while controller.get_active_job_count() > 0 and Time.get_ticks_msec() - start < 3000:
            await process_frame
            var now := Time.get_ticks_msec()
            var dt := (now - last_tick) / 1000.0
            last_tick = now
            var direction := Vector3.RIGHT if now - start < 250 else Vector3(-0.7, 0.0, 0.7).normalized()
            world.farmer.global_position += direction * 4.0 * dt
            world.farmer.rotation.y = atan2(-direction.x, -direction.z)
        _check(fx.get_lowest_world_y() >= fx.min_world_y, "Fileira %d: fruto nunca abaixo do terreno" % row)
        _check(cell["state"] == PlantingGrid.STATE_HARVESTED and int(cell["remaining_yield"]) == 0, "Fileira %d colhida por completo" % row)
        _check(not world.crops.has(cell["id"]), "Fileira %d: planta removida do mapa" % row)
        await process_frame
        _check(not is_instance_valid(crop), "Fileira %d: nó da planta liberado" % row)
    var worst := 0.0
    for e in arrival_errors:
        worst = maxf(worst, e)
    _check(arrival_errors.size() >= 9, "Chegadas registradas")
    _check(worst < 0.05, "Frutos acompanham o marcador móvel (erro máx %.3f)" % worst)
    _check(world.harvest_inventory.get_total() == 18, "3 plantas x 6 = 18 unidades")
    _check_conservation("frente/meio/fundo")
    print("FRONT_MIDDLE_BACK_OK arrivals=", arrival_errors.size(), " max_arrival_error=", snappedf(worst, 0.001))

## Caminhada contínua (sem parar) pelo canteiro inteiro: >= 10 plantas, sem duplicar.
func _test_walk_harvest_ten_plants() -> void:
    await _load_world()
    var controller := world.harvest_controller
    controller.enabled = true
    var started := {}
    var duplicated := [false]
    var max_jobs := [0]
    controller.harvest_started.connect(func(cell_id: String, _units: int) -> void:
        if started.has(cell_id) and world.planting_grid.get_remaining_yield(cell_id) == 6:
            duplicated[0] = true
        started[cell_id] = true)
    # Desce a tira do meio a 4 m/s, com zigue-zague e giro brusco.
    var path: Array[Vector3] = [Vector3(0.0, 0.0, 2.0), Vector3(0.0, 0.0, 6.5), Vector3(1.3, 0.0, 6.5), Vector3(-1.3, 0.0, 9.0), Vector3(0.0, 0.0, 14.5)]
    world.farmer.global_position = path[0]
    var last_tick := Time.get_ticks_msec()
    for i in range(1, path.size()):
        while world.farmer.global_position.distance_to(path[i]) > 0.05:
            await process_frame
            var now := Time.get_ticks_msec()
            var dt := (now - last_tick) / 1000.0
            last_tick = now
            world.farmer.global_position = world.farmer.global_position.move_toward(path[i], 4.0 * dt)
            max_jobs[0] = maxi(max_jobs[0], controller.get_active_job_count())
            _check_conservation_silent()
    await _wait_jobs()
    var harvested := _count_state(PlantingGrid.STATE_HARVESTED)
    _check(started.size() >= 10, "Ao menos 10 plantas colhidas em sequência (obtido %d)" % started.size())
    _check(not duplicated[0], "Nenhuma planta colhida em dobro")
    _check(max_jobs[0] >= 2, "Vários efeitos simultâneos durante a caminhada")
    _check(_count_state(PlantingGrid.STATE_HARVESTING) == 0, "Nenhuma célula presa em HARVESTING")
    _check(world.harvest_inventory.get_total() == 56, "Mochila cheia ao fim do canteiro")
    _check(world.harvest_inventory.get_pending_reservation_count() == 0, "Sem reservas pendentes")
    _check_conservation("caminhada")
    print("WALK_HARVEST_OK plants=", started.size(), " harvested=", harvested, " max_parallel_fx=", max_jobs[0], " total=", world.harvest_inventory.get_total())

var _conservation_broken := false
func _check_conservation_silent() -> void:
    # Durante o voo, reservas pendentes ainda estão na planta: a soma vale a cada frame.
    if _conservation_broken:
        return
    if world.harvest_inventory.get_total() + _remaining_total() != _initial_total:
        _conservation_broken = true
        _check(false, "Conservação quebrada no meio da caminhada")

func _test_capacity_full_keeps_fruit() -> void:
    await _load_world(func(c: Dictionary) -> bool: return c["module_id"] == "PlantingPlot_02" and c["row"] == 2)
    var inventory := world.harvest_inventory
    var controller := world.harvest_controller
    var full_signals := [0]
    controller.backpack_full.connect(func() -> void: full_signals[0] += 1)
    inventory.set_amount(ITEM, 55)
    _initial_total += 55
    var cell := _cell_at(2, 2, 1)
    world.farmer.global_position = cell["position"]
    controller.enabled = true
    await _wait_seconds(0.3)
    await _wait_jobs()
    _check(inventory.get_total() == 56, "55 + 1 = 56")
    _check(cell["state"] == PlantingGrid.STATE_RIPE and int(cell["remaining_yield"]) == 5, "Planta parcialmente colhida volta a RIPE com 5")
    _check(full_signals[0] == 1, "backpack_full emitido uma vez")
    await _wait_seconds(0.5)
    _check(not controller.request_collect(_cell_at(2, 2, 0)["id"]), "Mochila cheia bloqueia novas reservas")
    _check(_count_state(PlantingGrid.STATE_RIPE) == 3, "Frutos excedentes continuam nas plantas")
    _check(world.harvest_label.text.contains("Mochila cheia"), "HUD orienta descarregar na bancada")
    _check_conservation("mochila cheia")
    # Descarregar (Balcão de vendas) libera a colheita de novo.
    inventory.remove(ITEM, 56)
    _initial_total -= 56
    await _wait_seconds(0.3)
    await _wait_jobs()
    _check(inventory.get_total() > 0, "Após descarregar, a colheita continua")
    _check_conservation("após descarregar")
    print("CAPACITY_FULL_OK remaining_on_plant=5 after_unload=", inventory.get_total())

func _test_cancel_by_leaving_field() -> void:
    await _load_world()
    var controller := world.harvest_controller
    var cell := _cell_at(1, 3, 1)
    world.farmer.global_position = cell["position"]
    _check(controller.request_collect(cell["id"]), "Coleta iniciada")
    # Espera o primeiro fruto confirmar e então "sai do campo".
    var start := Time.get_ticks_msec()
    while world.harvest_inventory.get_total() == 0 and Time.get_ticks_msec() - start < 2000:
        await process_frame
    var committed := world.harvest_inventory.get_total()
    world.farmer.global_position = Vector3(-25.0, 0.0, -25.0)
    await process_frame
    await process_frame
    _check(controller.get_active_job_count() == 0, "Coleta cancelada ao sair do campo")
    _check(world.harvest_inventory.get_pending_reservation_count() == 0, "Reserva revertida")
    _check(committed > 0 and committed < 6, "Cancelado no meio do voo (%d confirmadas)" % committed)
    _check(cell["state"] == PlantingGrid.STATE_RIPE and int(cell["remaining_yield"]) == 6 - committed, "Planta mantém os frutos não confirmados")
    await _wait_seconds(0.5)
    _check(world.harvest_inventory.get_total() == committed, "Frutos cancelados não chegam depois")
    _check_conservation("cancelamento")
    # De volta à planta: o restante é colhido normalmente.
    world.farmer.global_position = cell["position"]
    _check(controller.request_collect(cell["id"]), "Planta parcialmente colhida pode ser colhida de novo")
    await _wait_jobs()
    _check(cell["state"] == PlantingGrid.STATE_HARVESTED and world.harvest_inventory.get_total() == 6, "Total final 6, sem duplicar")
    _check_conservation("recoleta")
    print("CANCEL_LEAVE_OK committed_before_cancel=", committed)

func _test_cancel_on_scene_exit() -> void:
    await _load_world()
    var controller := world.harvest_controller
    var cell := _cell_at(3, 4, 2)
    world.farmer.global_position = cell["position"]
    _check(controller.request_collect(cell["id"]), "Coleta iniciada")
    await process_frame
    # Simula troca de cena: o controlador sai da árvore com voos pendentes.
    world.remove_child(controller)
    _check(world.harvest_inventory.get_pending_reservation_count() == 0, "Troca de cena reverte reservas")
    _check(cell["state"] == PlantingGrid.STATE_RIPE, "Célula volta a RIPE na troca de cena")
    await _wait_seconds(0.8)
    _check(world.harvest_inventory.get_total() == 0, "Nada confirmado após a troca de cena")
    _check_conservation("troca de cena")
    world.add_child(controller)
    print("CANCEL_SCENE_EXIT_OK")

func _test_reload_mid_flight() -> void:
    await _load_world()
    var controller := world.harvest_controller
    var cell := _cell_at(2, 5, 0)
    world.farmer.global_position = cell["position"]
    controller.request_collect(cell["id"])
    var start := Time.get_ticks_msec()
    while world.harvest_inventory.get_total() == 0 and Time.get_ticks_msec() - start < 2000:
        await process_frame
    var save := {"inventory": world.harvest_inventory.to_dict(), "cells": world.planting_grid.get_harvest_state()}
    var saved_total := world.harvest_inventory.get_total()
    var expected_remaining := 6 - saved_total
    # Recarrega o mundo do zero e aplica o save.
    await _load_world()
    world.harvest_inventory.from_dict(save["inventory"])
    world.planting_grid.apply_harvest_state(save["cells"])
    var restored := _cell_at(2, 5, 0)
    _check(world.harvest_inventory.get_total() == saved_total, "Reload: inventário restaurado")
    _check(restored["state"] == PlantingGrid.STATE_RIPE, "Reload: célula em voo salva como RIPE")
    _check(int(restored["remaining_yield"]) == expected_remaining, "Reload: frutos não confirmados continuam na planta (%d)" % expected_remaining)
    _initial_total = saved_total + _remaining_total()
    _check(_initial_total == 63 * 6, "Reload: nenhuma unidade criada ou perdida")
    print("RELOAD_OK saved_total=", saved_total, " remaining_on_plant=", expected_remaining)

func _test_approach_from_all_sides() -> void:
    var targets := {"norte": [1, 1, 1], "sul": [1, 5, 1], "leste": [3, 3, 1], "oeste": [2, 3, 0]}
    var ids := []
    for key in targets:
        var t: Array = targets[key]
        ids.append("PlantingPlot_%02d_r%02d_c%02d" % [t[0], t[1], t[2]])
    await _load_world(func(c: Dictionary) -> bool: return ids.has(c["id"]))
    var controller := world.harvest_controller
    controller.enabled = true
    var directions := {"norte": Vector3(0, 0, 1), "sul": Vector3(0, 0, -1), "leste": Vector3(-1, 0, 0), "oeste": Vector3(1, 0, 0)}
    for key in targets:
        var t: Array = targets[key]
        var cell := _cell_at(t[0], t[1], t[2])
        var dir: Vector3 = directions[key]
        var target: Vector3 = cell["position"]
        # Vem de 3 m e passa direto pela planta, sem parar.
        world.farmer.global_position = target - dir * 3.0
        var last_tick := Time.get_ticks_msec()
        var travelled := 0.0
        while travelled < 4.0:
            await process_frame
            var now := Time.get_ticks_msec()
            var step := 4.0 * (now - last_tick) / 1000.0
            last_tick = now
            travelled += step
            world.farmer.global_position += dir * step
        await _wait_jobs()
        _check(cell["state"] == PlantingGrid.STATE_HARVESTED, "Aproximação pelo %s colhe a planta" % key)
    _check_conservation("aproximação")
    print("APPROACH_ALL_SIDES_OK total=", world.harvest_inventory.get_total())
