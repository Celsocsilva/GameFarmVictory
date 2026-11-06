extends SceneTree
## Teste da fila de clientes: posição da bancada, fila dupla 2 x 7, intervalo
## sorteado de 10-15 s, limite de 5 acumulados e clientes clonados do fazendeiro.

const STEP := 0.05

func _initialize() -> void:
    call_deferred("_run")

func _advance(queue: CustomerQueue, delta: float) -> void:
    queue.tick(delta)
    for child in queue.get_children():
        if child is Customer and is_instance_valid(child):
            (child as Customer).step(delta)

func _fail(message: String) -> void:
    push_error("CUSTOMER_SMOKE_FAIL " + message)
    print("CUSTOMER_SMOKE_FAIL ", message)
    quit(1)

func _run() -> void:
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.set_process(false)
    world.harvest_controller.enabled = false
    var queue := world.customer_queue
    queue.set_process(false)
    world.sales_controller.set_process(false)
    var depot := world.sales_counter
    var edge := world.farm_size * 0.5

    # 1. Layout: bancada recuada, entre o canteiro e a fila; 14 lugares dentro da cerca.
    var plot_far_edge := 0.0
    for plot in world.get_node("PlantingArea").get_children():
        var shape := ((plot as Node3D).get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
        plot_far_edge = maxf(plot_far_edge, (plot as Node3D).global_position.z + shape.size.z * 0.5)
    var depot_z := depot.global_position.z
    if depot_z - 1.2 - plot_far_edge < 4.0:
        return _fail("bancada colada no canteiro: %.2f" % (depot_z - plot_far_edge))
    if queue.get_capacity() != 14:
        return _fail("capacidade %d" % queue.get_capacity())
    var slots: Array[Vector3] = []
    for lane in CustomerQueue.LANES:
        for slot in CustomerQueue.SLOTS_PER_LANE:
            var world_pos := queue.to_global(queue.get_slot_position(lane, slot))
            if world_pos.z - 0.45 <= depot_z + 1.26:
                return _fail("lugar dentro da bancada %s" % world_pos)
            if world_pos.z + 0.45 >= edge - 0.2:
                return _fail("lugar fora da cerca %s" % world_pos)
            for other in slots:
                if other.distance_to(world_pos) < 1.0:
                    return _fail("lugares sobrepostos")
            slots.append(world_pos)
    var spawn_z := queue.to_global(queue.get_spawn_position(0)).z
    if spawn_z >= edge - 0.2 or spawn_z <= slots[slots.size() - 1].z:
        return _fail("ponto de surgimento %.2f" % spawn_z)
    print("LAYOUT depot_z=%.2f plot_far_edge=%.2f first_slot_z=%.2f last_slot_z=%.2f spawn_z=%.2f fence_z=%.2f" % [depot_z, plot_far_edge, slots[0].z, slots[6].z, spawn_z, edge])

    # 2. Intervalos, limite de 5, paciência 15-20 s e volta 15-20 s: 300 s simulados.
    queue.set_seed(20261106)
    var max_total := 0
    var distinct := {}
    var t := 0.0
    while t < 300.0:
        _advance(queue, STEP)
        t += STEP
        max_total = maxi(max_total, queue.get_total_customers())
        for customer in queue.get_customers():
            distinct[customer] = true
        for lane in CustomerQueue.LANES:
            var members := queue.get_lane(lane)
            for index in members.size():
                if members[index].slot != index:
                    return _fail("fila com buraco: lane %d slot %d em %d" % [lane, members[index].slot, index])
    var times := queue.spawn_times
    if times.size() != 5 or max_total != 5 or distinct.size() != 5:
        return _fail("esperado 5 clientes diferentes, surgiram %d (máx %d, distintos %d)" % [times.size(), max_total, distinct.size()])
    var previous := 0.0
    var intervals: Array[String] = []
    for time in times:
        var interval: float = time - previous
        if interval < 10.0 - STEP or interval > 15.0 + STEP:
            return _fail("intervalo fora de 10-15 s: %.2f" % interval)
        intervals.append("%.2f" % interval)
        previous = time
    print("SPAWN_TIMES ", times.map(func(v): return "%.2f" % v), " INTERVALS ", intervals)
    if queue.leave_log.size() < 5 or queue.return_log.size() < 5:
        return _fail("poucas saídas/voltas: %d/%d" % [queue.leave_log.size(), queue.return_log.size()])
    var waits: Array[String] = []
    for entry in queue.leave_log:
        if entry["waited"] < 15.0 - STEP or entry["waited"] > 20.0 + 2.0 * STEP:
            return _fail("espera fora de 15-20 s: %.2f" % entry["waited"])
        waits.append("%.2f" % entry["waited"])
    var aways: Array[String] = []
    for entry in queue.return_log:
        if entry["away"] < 15.0 - STEP or entry["away"] > 20.0 + STEP:
            return _fail("ausência fora de 15-20 s: %.2f" % entry["away"])
        if not distinct.has(entry["customer"]):
            return _fail("voltou um cliente que não existia")
        aways.append("%.2f" % entry["away"])
    print("LEAVES=%d WAITED " % queue.leave_log.size(), waits)
    print("RETURNS=%d AWAY " % queue.return_log.size(), aways)
    print("MAX_TOTAL=%d DISTINCT=%d em %.0f s (fila sem buracos em todos os passos)" % [max_total, distinct.size(), queue.get_elapsed()])
    for customer in queue.get_customers():
        if not customer.is_walking() and customer.position.distance_to(queue.get_slot_position(customer.lane, customer.slot)) > 0.05:
            return _fail("cliente parado fora do lugar")
    # A fila anda: o de trás ocupa o lugar de quem saiu.
    while queue.get_lane_count(0) < 2 or queue.get_lane(0)[0].is_walking() or queue.get_lane(0)[1].is_walking():
        _advance(queue, STEP)
    var second := queue.get_lane(0)[1]
    queue.get_lane(0)[0].patience_left = 0.0
    _advance(queue, STEP)
    if second.slot != 0 or second.get_target() != queue.get_slot_position(0, 0):
        return _fail("fila não andou após saída")
    for i in 40:
        _advance(queue, STEP)
    if second.is_walking() or second.position.distance_to(queue.get_slot_position(0, 0)) > 0.05:
        return _fail("cliente de trás não chegou ao primeiro lugar")
    print("QUEUE_ADVANCES_OK")

    # 3. Clones do fazendeiro com cores alternativas.
    var farmer_meshes := 0
    var farmer_color := Color()
    for child in world.farmer.get_children():
        if child is MeshInstance3D:
            farmer_meshes += 1
            if child.name == "Body":
                farmer_color = ((child as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
    var customers := queue.get_customers()
    customers.append_array(queue.get_away_customers())
    for index in customers.size():
        var customer := customers[index]
        var meshes := customer.get_children().filter(func(n): return n is MeshInstance3D)
        if meshes.size() != farmer_meshes:
            return _fail("cliente com %d meshes, fazendeiro %d" % [meshes.size(), farmer_meshes])
        var body := customer.get_node("Body") as MeshInstance3D
        var source := world.farmer.get_node("Body") as MeshInstance3D
        if body.mesh != source.mesh:
            return _fail("cliente não usa o mesh do fazendeiro")
        var color := (body.material_override as StandardMaterial3D).albedo_color
        if color.is_equal_approx(farmer_color):
            return _fail("cliente com a cor do fazendeiro")
        if customer.get_script() != Customer or (customer as Node) is CharacterBody3D:
            return _fail("cliente com controle do fazendeiro")
    var schemes := {}
    for customer in customers:
        schemes[customer.color_scheme_index] = true
    if schemes.size() < 3:
        return _fail("pouca variação de cores: %d" % schemes.size())

    # 4. Atendimento (release_front) libera vaga e um novo intervalo completo de 10-15 s.
    var lane_to_serve := 0 if queue.get_lane_count(0) > 0 else 1
    var released := queue.release_front(lane_to_serve)
    if released == null or queue.get_total_customers() != 4:
        return _fail("liberação falhou")
    var freed_at := queue.get_elapsed()
    var before := queue.spawn_times.size()
    while queue.spawn_times.size() == before and queue.get_elapsed() - freed_at < 30.0:
        _advance(queue, STEP)
    var wait := queue.spawn_times[queue.spawn_times.size() - 1] - freed_at
    if queue.spawn_times.size() != before + 1 or wait < 10.0 - STEP or wait > 15.0 + STEP:
        return _fail("após vaga, novo cliente em %.2f s" % wait)
    if queue.get_total_customers() != 5:
        return _fail("contagem após reposição")
    print("REFILL_AFTER_RELEASE wait=%.2f total=%d" % [wait, queue.get_total_customers()])

    # 5. Capacidade física: força 14 e garante que o 15º é recusado.
    while queue.spawn_customer(true) != null:
        pass
    if queue.get_customer_count() != 14 or queue.get_lane_count(0) != 7 or queue.get_lane_count(1) != 7:
        return _fail("capacidade forçada %d" % queue.get_customer_count())
    # 6. A descarga da mochila continua funcionando com a bancada recuada.
    world.harvest_inventory.set_amount(&"tomato", 16)
    depot.process_farmer_position(depot.global_position + Vector3(0.0, 0.0, -2.0))
    if world.harvest_inventory.get_total() != 0 or depot.get_stored_total() != 16:
        return _fail("descarga na bancada recuada")
    print("CUSTOMER_SMOKE_OK lanes=2x7 max=5 intervals=10-15s patience=15-20s away=15-20s refill=%.2fs" % wait)
    quit()
