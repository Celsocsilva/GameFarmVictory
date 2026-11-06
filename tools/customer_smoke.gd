extends SceneTree
## Teste da fila de clientes: posição da bancada, fila dupla 2 x 7, intervalo
## sorteado de 10-15 s, limite de 5 acumulados e clientes clonados do fazendeiro.

const STEP := 0.05

func _initialize() -> void:
    call_deferred("_run")

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
    var depot := world.tomato_depot
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

    # 2. Intervalos e limite: 240 s simulados com semente fixa.
    queue.set_seed(20261106)
    var max_seen := 0
    var t := 0.0
    while t < 240.0:
        queue.tick(STEP)
        for customer in queue.get_customers():
            customer.step(STEP)
        max_seen = maxi(max_seen, queue.get_customer_count())
        t += STEP
    var times := queue.spawn_times
    if times.size() != 5 or max_seen != 5:
        return _fail("esperado 5 clientes, surgiram %d (máx %d)" % [times.size(), max_seen])
    var previous := 0.0
    var intervals: Array[String] = []
    for time in times:
        var interval: float = time - previous
        if interval < 10.0 - STEP or interval > 15.0 + STEP:
            return _fail("intervalo fora de 10-15 s: %.2f" % interval)
        intervals.append("%.2f" % interval)
        previous = time
    if not queue.is_paused_full():
        return _fail("relógio deveria estar parado com 5 clientes")
    print("SPAWN_TIMES ", times.map(func(v): return "%.2f" % v), " INTERVALS ", intervals)
    print("HOLD_AT_MAX count=%d after %.0f s (último em %.2f s)" % [queue.get_customer_count(), queue.get_elapsed(), times[4]])
    if queue.get_lane_count(0) != 3 or queue.get_lane_count(1) != 2:
        return _fail("divisão entre filas %d/%d" % [queue.get_lane_count(0), queue.get_lane_count(1)])
    for customer in queue.get_customers():
        if customer.is_walking():
            return _fail("cliente não chegou ao lugar")
        if customer.position.distance_to(queue.get_slot_position(customer.lane, customer.slot)) > 0.05:
            return _fail("cliente fora do lugar")

    # 3. Clones do fazendeiro com cores alternativas.
    var farmer_meshes := 0
    var farmer_color := Color()
    for child in world.farmer.get_children():
        if child is MeshInstance3D:
            farmer_meshes += 1
            if child.name == "Body":
                farmer_color = ((child as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
    var customers := queue.get_customers()
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

    # 4. Saída de um cliente libera vaga e um novo intervalo completo de 10-15 s.
    var released := queue.release_front(0)
    if released == null or queue.get_customer_count() != 4:
        return _fail("liberação falhou")
    var freed_at := queue.get_elapsed()
    var before := times.size()
    while queue.spawn_times.size() == before and queue.get_elapsed() - freed_at < 30.0:
        queue.tick(STEP)
    var wait := queue.spawn_times[queue.spawn_times.size() - 1] - freed_at
    if queue.spawn_times.size() != before + 1 or wait < 10.0 - STEP or wait > 15.0 + STEP:
        return _fail("após vaga, novo cliente em %.2f s" % wait)
    if queue.get_customer_count() != 5:
        return _fail("contagem após reposição")
    print("REFILL_AFTER_RELEASE wait=%.2f count=%d" % [wait, queue.get_customer_count()])

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
    print("CUSTOMER_SMOKE_OK lanes=2x7 max=5 intervals=10-15s refill=%.2fs" % wait)
    quit()
