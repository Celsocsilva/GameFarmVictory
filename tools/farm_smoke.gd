extends SceneTree
## Smoke test headless: grade de plantio, tamanho dos tomates e punhado de sementes.
## Uso: Godot --headless --path . -s tools/farm_smoke.gd   (código de saída 1 em falha)

const SOIL_TEXTURE_SIZE := Vector2i(466, 912)

var _failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error("FARM_SMOKE_FAIL: " + message)

func _run() -> void:
    var scene := load("res://scenes/world/farm_world.tscn") as PackedScene
    var world := scene.instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    _check_soil(world)
    _check_grid(world)
    _check_throw_reach(world)
    await _check_crop_sizes(world)
    await _check_seed_throw(world)
    if _failures > 0:
        print("FARM_SMOKE_FAILED failures=", _failures)
        quit(1)
        return
    print("FARM_SMOKE_OK")
    quit()

func _check_soil(world: FarmWorld) -> void:
    var soil := FarmWorld.SOIL_TEXTURE
    _check(Vector2i(soil.get_size()) == SOIL_TEXTURE_SIZE, "Textura do solo deve ser a nova arte 466x912")
    var plots := world.get_node("PlantingArea").get_children()
    _check(plots.size() == FarmWorld.PLANTING_PLOT_COUNT, "Quantidade de canteiros")
    # Área 1,7x a da versão anterior (tiras de 3,8 m de largura), mesma proporção.
    var plot_area := world.planting_plot_size.x * world.planting_plot_size.y
    var legacy_width := 3.8
    var legacy_area := legacy_width * legacy_width * world.planting_plot_size.y / world.planting_plot_size.x
    _check(absf(plot_area / legacy_area - 1.7) < 0.01, "Área de plantio deve ser 1,7x (obtido %.3f)" % (plot_area / legacy_area))
    # Ciclo da planta com o dobro do tempo (30 s -> 60 s) em todas as fases.
    _check(is_equal_approx(CropPlant.new().growth_duration, 60.0), "Ciclo da planta deve durar 60 s")
    # Dinheiro 1,7x e base fora da plantação.
    _check(is_equal_approx(MoneyStack.CELL_SIZE.x, MoneyStack.BUNDLE_WIDTH) and is_equal_approx(MoneyStack.BUNDLE_WIDTH, 0.74 * 1.7), "Maços de dinheiro 1,7x")
    var base_half := MoneyStack.get_base_size() * 0.5
    var money_left := world.money_stack.global_position.x - base_half.x
    _check(money_left > world.get_planting_area_half_width(), "Base de dinheiro não pode invadir a plantação")
    print("AREA_CYCLE_MONEY_OK area_ratio=", snappedf(plot_area / legacy_area, 0.001), " cycle=60s money_cell=", MoneyStack.CELL_SIZE)
    var visual := plots[0].get_node("PlowedSoil") as MeshInstance3D
    var quad := visual.mesh as QuadMesh
    var aspect := quad.size.y / quad.size.x
    var expected := float(SOIL_TEXTURE_SIZE.y) / float(SOIL_TEXTURE_SIZE.x) * FarmWorld.PLANTING_LENGTH_STRETCH
    _check(absf(aspect - expected) < 0.01, "Quad do solo deve seguir a arte compensada pela câmera")
    # Na tela, a tira deve aparecer na proporção da arte (compensação = inclinação real da câmera).
    var pitch := rad_to_deg(atan2(world.camera_height, world.camera_distance))
    _check(absf(pitch - FarmWorld.PLANTING_VIEW_PITCH_DEGREES) < 0.5, "Compensação do comprimento deve casar com a inclinação da câmera")
    var on_screen_aspect := aspect * sin(deg_to_rad(pitch))
    var art_aspect := float(SOIL_TEXTURE_SIZE.y) / float(SOIL_TEXTURE_SIZE.x)
    _check(absf(on_screen_aspect - art_aspect) < 0.02, "Tira não pode parecer comprimida na tela")
    print("SOIL_OK texture=", soil.get_size(), " quad=", quad.size)

func _check_grid(world: FarmWorld) -> void:
    var grid := world.planting_grid
    var expected_cells := FarmWorld.PLANTING_PLOT_COUNT * grid.columns * grid.rows_per_module
    _check(FarmWorld.PLANTING_PLOT_COUNT == 3, "Área de tomate deve ter 3 tiras")
    _check(grid.cells.size() == expected_cells, "Esperado %d tiras x %d sulcos x %d fileiras" % [FarmWorld.PLANTING_PLOT_COUNT, grid.columns, grid.rows_per_module])
    var front: Dictionary = {}
    var back: Dictionary = {}
    for cell in grid.cells.values():
        if front.is_empty() or cell["position"].z > front["position"].z:
            front = cell
        if back.is_empty() or cell["position"].z < back["position"].z:
            back = cell
    _check(front["id"] != back["id"], "Frente e fundo distintos")
    grid.cell_planted.disconnect(world._on_grid_cell_planted)
    _check(grid.plant_cell(front["id"]), "Frente plantável")
    _check(not grid.plant_cell(front["id"]), "Plantio duplicado")
    _check(grid.plant_cell(back["id"]), "Fundo plantável")
    _check(grid.get_planting_progress()["planted"] == 2, "Progresso após 2 plantios")
    var positions := {}
    for cell in grid.cells.values():
        var position: Vector3 = cell["position"]
        var key := Vector2i(roundi(position.x * 1000), roundi(position.z * 1000))
        _check(not positions.has(key), "Posição de plantio duplicada")
        positions[key] = true
        grid.plant_cell(cell["id"])
    _check(grid.get_planting_progress()["remaining"] == 0, "Todas as células plantadas")
    grid.cell_planted.connect(world._on_grid_cell_planted)
    print("GRID_OK cells=", grid.cells.size(), " unique=", positions.size(), " front=", front["id"], " back=", back["id"])

func _check_throw_reach(world: FarmWorld) -> void:
    # Grade nova (sem sinal ligado) com os mesmos canteiros do mundo.
    var grid := PlantingGrid.new()
    world.add_child(grid)
    var modules: Array[Area3D] = []
    for child in world.get_node("PlantingArea").get_children():
        modules.append(child as Area3D)
    grid.configure(modules)
    # Fazendeiro em cima da 2ª cova de um sulco, andando em +Z.
    var start_cell: Dictionary = grid.cells["PlantingPlot_02_r01_c01"]
    var farmer_position: Vector3 = start_cell["position"]
    grid.process_farmer_position(farmer_position - Vector3(0.0, 0.0, 0.3), 0.0)
    grid.process_farmer_position(farmer_position, 0.4)
    var planted: Array = grid.cells.values().filter(func(c: Dictionary) -> bool: return c["state"] != "EMPTY")
    var rows := []
    for cell in planted:
        _check(cell["module_id"] == "PlantingPlot_02" and cell["column"] == 1, "Faixa deve ficar no sulco da caminhada (%s)" % cell["id"])
        rows.append(cell["row"])
    rows.sort()
    _check(rows == [1, 2, 3, 4], "Deve semear do pé (fileira 1) até 3 plantas à frente (fileira 4), obtido %s" % [rows])
    # Próximo passo continua a faixa à frente, sem replantar.
    var next_position: Vector3 = grid.cells["PlantingPlot_02_r02_c01"]["position"]
    grid.process_farmer_position(next_position, 0.4)
    _check(grid.cells["PlantingPlot_02_r05_c01"]["state"] != "EMPTY", "Passo seguinte semeia a próxima cova da frente")
    _check(grid.cells["PlantingPlot_02_r06_c01"]["state"] == "EMPTY", "Não semeia além de 3 plantas à frente")
    print("SEED_BAND_OK rows=", rows, " ahead=", grid.seed_plants_ahead, " band=", snappedf(grid.get_seed_band_length(), 0.01), "m")
    grid.queue_free()

func _check_crop_sizes(world: FarmWorld) -> void:
    var cell: Dictionary = world.planting_grid.cells.values()[0]
    var cell_width: float = cell["cell_width"]
    var crop := CropPlant.new()
    crop.cell_width = cell_width
    crop.position = cell["position"]
    world.add_child(crop)
    # planted_at = 0 congela o crescimento automático durante a inspeção.
    crop.initialize(cell["id"], 0.0)
    # Referência: dimensionamento antigo (PNG inteiro 1254 px, 0.9 da célula).
    # Referência na célula original (antes da área 1,7x), para medir só o ganho do sprite.
    var legacy_cell_width := cell_width / FarmWorld.PLANTING_LINEAR_SCALE
    var legacy_pixel_size := minf(1.8 / 1254.0, legacy_cell_width * 0.9 / 1254.0)
    var previous_height := 0.0
    var report := []
    for stage in CropPlant.STAGES.size():
        crop._update_stage(stage)
        await process_frame
        var size := crop.get_visible_world_size()
        var legacy_size := crop.sprite.region_rect.size * legacy_pixel_size
        _check(size.y > previous_height, "Estágio %d deve ser mais alto que o anterior" % stage)
        _check(size.x <= cell_width * crop.max_width_fraction + 0.001, "Estágio %d excede a largura máxima" % stage)
        _check(size.y >= legacy_size.y * 1.3, "Estágio %d deve ficar ao menos 30%% maior que antes" % stage)
        # Billboard: a AABB do Sprite3D é esférica, então a âncora é verificada
        # pelos parâmetros de desenho (base no sulco, centralizado em X).
        _check(not crop.sprite.centered and is_zero_approx(crop.sprite.offset.y), "Estágio %d deve crescer a partir da base do sulco" % stage)
        _check(is_equal_approx(crop.sprite.offset.x, -crop.sprite.region_rect.size.x * 0.5), "Estágio %d deve ficar centralizado no sulco" % stage)
        previous_height = size.y
        report.append("%s=%.2fx%.2f(+%d%%)" % [CropPlant.STAGES[stage], size.x, size.y, roundi((size.y / legacy_size.y - 1.0) * 100.0)])
    crop.queue_free()
    await process_frame
    print("CROP_SIZES_OK ", " ".join(report))

func _check_seed_throw(world: FarmWorld) -> void:
    var throw := FarmWorld.SEED_THROW_SCENE.instantiate() as SeedThrow
    world.add_child(throw)
    var origin := Vector3(0.0, 1.2, 0.0)
    var target := Vector3(2.0, 0.2, 4.0)
    var velocity := SeedThrow.solve_launch_velocity(origin, target, throw.gravity, throw.flight_time)
    var t := throw.flight_time
    var landing := origin + velocity * t + 0.5 * throw.gravity * t * t
    _check(landing.distance_to(target) < 0.001, "Trajetória central deve atingir a célula")
    var landed := [false]
    throw.landed.connect(func(_point: Vector3) -> void: landed[0] = true)
    throw.launch(origin, target)
    var particles := throw.particles
    var material := particles.process_material as ParticleProcessMaterial
    var draw_material := (particles.draw_pass_1 as QuadMesh).material as StandardMaterial3D
    _check(particles.emitting, "Punhado deve estar emitindo")
    _check(particles.amount >= 6, "Punhado deve ter ao menos 6 grãos principais")
    var fine_material := throw.fine_particles.process_material as ParticleProcessMaterial
    _check(throw.fine_particles.emitting and throw.fine_particles.amount >= 15, "Camada de grãos finos emitindo")
    _check(fine_material.scale_max < material.scale_min, "Grãos finos devem ser menores que os principais")
    _check(fine_material.spread > material.spread, "Grãos finos devem abrir mais (pulverizado)")
    _check(material.scale_max / fine_material.scale_min >= 10.0, "Faixa total de tamanhos >= 10x")
    _check(material.scale_curve != null, "Curva de escala para pousar suavemente")
    _check(material.anim_offset_max > material.anim_offset_min, "Sementes devem sortear formatos do atlas")
    # Sem keep_scale o billboard de partículas descarta scale_min/max e a curva.
    _check(draw_material.billboard_keep_scale, "Billboard deve manter a escala de cada semente")
    _check(draw_material.particles_anim_h_frames * draw_material.particles_anim_v_frames == 4, "Atlas 2x2 de sementes")
    _check(particles.explosiveness < 1.0, "Saída escalonada (punhado fluido)")
    var amount := particles.amount + throw.fine_particles.amount
    var ground_grains := [0]
    throw.landed.connect(func(_point: Vector3) -> void:
        ground_grains[0] = throw.get_children().filter(func(n: Node) -> bool: return n is Sprite3D).size(), CONNECT_DEFERRED)
    var start := Time.get_ticks_msec()
    while is_instance_valid(throw) and Time.get_ticks_msec() - start < 3000:
        await process_frame
    _check(landed[0], "SeedThrow deve emitir landed para o broto nascer no pouso")
    _check(ground_grains[0] >= 8, "Grãos devem ficar espalhados no solo após o pouso")
    _check(not is_instance_valid(throw), "SeedThrow deve se liberar após o voo")
    print("SEED_THROW_OK amount=", amount, " ground_grains=", ground_grains[0],
        " scale=", fine_material.scale_min, "-", material.scale_max, " landing_error=", landing.distance_to(target))
