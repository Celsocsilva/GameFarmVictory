extends SceneTree
## Auditoria de ângulo/proporção (FV-SALES-003): mede, com a câmera real do jogo,
## como cada elemento aparece na tela e compara com a arte original.
##
## Para cada elemento com arte (solo do canteiro, maço de dinheiro, caixa do
## balcão, caixa da mochila, planta de tomate) projeta os 4 cantos do quadro no
## plano da tela e confere:
##   - proporção altura/largura na tela == proporção do PNG (tolerância 2%);
##   - bordas horizontais do quadro horizontais na tela (sem giro);
## e para os objetos 3D (fazendeiro, cliente, balcão, base de dinheiro) confere
## que estão alinhados ao eixo da câmera (sem giro em Y) e em pé (sem inclinação).
##
## Uso: --headless -s tools/angle_audit.gd           (só números; sai 1 se falhar)
##      -s tools/angle_audit.gd -- <pasta>           (também gera a prancha lado a lado)

const TOLERANCE := 0.02

var _rows: Array[Dictionary] = []
var _failed := false
var _windowed := false
## Captura da tela usada para recortar o elemento auditado (null em headless).
var _shot: Image

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var out_dir := args[0] if args.size() > 0 else ""
    var world := (load("res://scenes/world/farm_world.tscn") as PackedScene).instantiate() as FarmWorld
    root.add_child(world)
    await process_frame
    world.set_process(false)
    world.harvest_controller.enabled = false
    world.customer_queue.set_process(false)
    world.sales_controller.set_process(false)
    world.farmer.set_physics_process(false)
    _windowed = out_dir != "" and DisplayServer.get_name() != "headless"
    (world.get_node("HUD") as CanvasLayer).visible = false
    var camera := world.camera
    # Câmera parada na posição de jogo, olhando o balcão (sem alterar a câmera:
    # mesma altura, distância e look_at que FarmWorld usa).
    var focus := world.sales_counter.global_position + Vector3(0.0, 0.0, -2.5)
    camera.global_position = focus + Vector3(0.0, world.camera_height, world.camera_distance)
    camera.look_at(focus, Vector3.UP)

    # Cena com todos os elementos visíveis.
    world.harvest_inventory.set_amount(&"tomato", 40)
    world.sales_counter.set_stored_total(48)
    world.money_stack.add_money(30)
    world.farmer.global_position = world.sales_counter.global_position + Vector3(-3.0, 0.0, -2.6)
    world.farmer.rotation.y = PI
    var cell_ids := world.planting_grid.cells.keys()
    var crop := world.spawn_crop_at_stage(cell_ids[cell_ids.size() - 1], 3)
    var customer := world.customer_queue.spawn_customer(true)
    world.customer_queue.snap_all_to_targets()
    for i in 4:
        await process_frame

    var pitch := rad_to_deg(asin(-camera.global_basis.z.y))
    var yaw := rad_to_deg(atan2(camera.global_basis.z.x, camera.global_basis.z.z))
    print("CAMERA pitch=%.2f yaw=%.2f ortho=%s size=%.1f" % [-pitch, yaw, camera.projection == Camera3D.PROJECTION_ORTHOGONAL, camera.size])
    _check(absf(absf(pitch) - 45.0) < 0.5 and absf(yaw) < 0.5, "câmera a 45° sem giro")

    # Elementos com arte (quadros planos ou de pé). O solo é medido com a câmera
    # (mesmo ângulo, só deslocada e com mais zoom-out) sobre o canteiro inteiro.
    var plot := world.get_node("PlantingArea").get_child(1) as Node3D
    var soil := plot.get_node("PlowedSoil") as MeshInstance3D
    var previous_size := camera.size
    camera.size = 20.0
    camera.global_position = plot.global_position + Vector3(0.0, world.camera_height, world.camera_distance)
    camera.look_at(plot.global_position, Vector3.UP)
    await _capture()
    _audit_quad(camera, "Terreno de cultivo (solo)", world.SOIL_TEXTURE, soil.global_transform, (soil.mesh as QuadMesh).size)
    camera.size = previous_size
    camera.global_position = focus + Vector3(0.0, world.camera_height, world.camera_distance)
    camera.look_at(focus, Vector3.UP)
    await _capture()
    if _shot:
        _shot.save_png(out_dir.path_join("08-cena-auditada.png"))
    var money := world.money_stack
    var bundle := money.get_node("Money_00_00") as MeshInstance3D
    _audit_quad(camera, "Maço na base de dinheiro", MoneyStack.MONEY_TEXTURE, bundle.global_transform, (bundle.mesh as QuadMesh).size)
    var counter_sprite := world.sales_counter.get_node("CounterCrate_00/CrateSprite") as Sprite3D
    _audit_sprite(camera, "Caixa no Balcão de vendas", counter_sprite)
    var backpack_sprite := world.backpack.get_node("BackpackStackRoot/Crate_0/CrateSprite") as Sprite3D
    _audit_sprite(camera, "Caixa na mochila", backpack_sprite)
    _audit_billboard(camera, "Planta de tomate", crop.sprite)

    # Objetos 3D: alinhados ao eixo da câmera e em pé.
    _audit_upright("Fazendeiro (corpo em pé)", world.farmer, false)
    _audit_upright("Cliente (corpo em pé)", customer, false)
    _audit_upright("Balcão de vendas (sem giro)", world.sales_counter, true)
    _audit_upright("Base de dinheiro (sem giro)", money, true)
    _audit_upright("Canteiro (sem giro)", plot, true)
    _audit_edges(camera, "Borda do balcão horizontal na tela", world.sales_counter, world.sales_counter.get_half_extents())
    var base := MoneyStack.get_base_size()
    _audit_edges(camera, "Borda da base de dinheiro horizontal na tela", money, Vector2(base.x, base.z) * 0.5)

    if _windowed:
        await _board(world, out_dir)
    if _failed:
        print("ANGLE_AUDIT_FAIL")
        quit(1)
        return
    print("ANGLE_AUDIT_OK elements=%d" % _rows.size())
    quit()

func _check(ok: bool, label: String) -> void:
    if not ok:
        _failed = true
        push_error("ANGLE_AUDIT_FAIL " + label)
        print("ANGLE_AUDIT_FAIL ", label)

## Quadro com a arte: compara a proporção na tela com a do PNG.
func _audit_quad(camera: Camera3D, label: String, texture: Texture2D, xform: Transform3D, size: Vector2) -> void:
    var half := size * 0.5
    var corners: Array[Vector3] = [
        xform * Vector3(-half.x, half.y, 0.0), xform * Vector3(half.x, half.y, 0.0),
        xform * Vector3(half.x, -half.y, 0.0), xform * Vector3(-half.x, -half.y, 0.0)]
    _record(camera, label, texture, Vector2(texture.get_size()), corners)

func _audit_sprite(camera: Camera3D, label: String, sprite: Sprite3D) -> void:
    var box := sprite.get_aabb()
    var xform := sprite.global_transform
    var z := box.position.z + box.size.z * 0.5
    var corners: Array[Vector3] = [
        xform * Vector3(box.position.x, box.end.y, z), xform * Vector3(box.end.x, box.end.y, z),
        xform * Vector3(box.end.x, box.position.y, z), xform * Vector3(box.position.x, box.position.y, z)]
    _record(camera, label, sprite.texture, Vector2(sprite.texture.get_size()), corners)

## Billboard completo: o quadro já fica de frente para a tela.
func _audit_billboard(camera: Camera3D, label: String, sprite: Sprite3D) -> void:
    var size := sprite.region_rect.size * sprite.pixel_size
    var origin := sprite.global_position
    var right := camera.global_basis.x * size.x * 0.5
    var up := camera.global_basis.y * size.y
    var corners: Array[Vector3] = [origin - right + up, origin + right + up, origin + right, origin - right]
    _record(camera, label, sprite.texture, sprite.region_rect.size, corners, sprite.region_rect)

func _record(camera: Camera3D, label: String, texture: Texture2D, art_size: Vector2, corners: Array[Vector3], region: Rect2 = Rect2()) -> void:
    var screen: Array[Vector2] = []
    for corner in corners:
        screen.append(camera.unproject_position(corner))
    var width := screen[0].distance_to(screen[1])
    var height := screen[1].distance_to(screen[2])
    var art_aspect := art_size.y / art_size.x
    var screen_aspect := height / width
    var tilt := rad_to_deg(atan2(screen[1].y - screen[0].y, screen[1].x - screen[0].x))
    var error := screen_aspect / art_aspect - 1.0
    var ok := absf(error) <= TOLERANCE and absf(tilt) < 0.5
    var rect := Rect2(screen[0], Vector2.ZERO)
    for point in screen:
        rect = rect.expand(point)
    var crop: Image = null
    if _shot:
        var area := rect.grow(4).intersection(Rect2(Vector2.ZERO, Vector2(_shot.get_size())))
        crop = _shot.get_region(Rect2i(area))
    _rows.append({"label": label, "texture": texture, "region": region, "art": art_aspect, "screen": screen_aspect, "error": error, "tilt": tilt, "crop": crop, "ok": ok})
    print("%s %s art_h/w=%.3f screen_h/w=%.3f diff=%+.1f%% tilt=%.2f°" % ["OK  " if ok else "FAIL", label, art_aspect, screen_aspect, error * 100.0, tilt])
    _check(ok, label)

func _audit_upright(label: String, node: Node3D, axis_aligned: bool) -> void:
    var basis := node.global_basis.orthonormalized()
    var lean := rad_to_deg(basis.y.angle_to(Vector3.UP))
    var yaw := rad_to_deg(atan2(basis.z.x, basis.z.z))
    var ok := lean < 0.5 and (not axis_aligned or absf(yaw) < 0.5)
    print("%s %s inclinação=%.2f° giro_y=%.2f°" % ["OK  " if ok else "FAIL", label, lean, yaw])
    _rows.append({"label": label, "ok": ok, "lean": lean, "yaw": yaw})
    _check(ok, label)

func _audit_edges(camera: Camera3D, label: String, node: Node3D, half: Vector2) -> void:
    var left := camera.unproject_position(node.to_global(Vector3(-half.x, 0.0, -half.y)))
    var right := camera.unproject_position(node.to_global(Vector3(half.x, 0.0, -half.y)))
    var tilt := rad_to_deg(atan2(right.y - left.y, right.x - left.x))
    var ok := absf(tilt) < 0.5
    print("%s %s tilt=%.2f°" % ["OK  " if ok else "FAIL", label, tilt])
    _rows.append({"label": label, "ok": ok, "tilt": tilt})
    _check(ok, label)

## Prancha lado a lado: arte original (esquerda) x recorte da tela do jogo (direita).
func _capture() -> void:
    if not _windowed:
        return
    await create_timer(0.25).timeout
    _shot = root.get_viewport().get_texture().get_image()

func _board(world: FarmWorld, out_dir: String) -> void:
    DirAccess.make_dir_recursive_absolute(out_dir)
    var layer := CanvasLayer.new()
    layer.layer = 100
    root.add_child(layer)
    var panel := ColorRect.new()
    panel.color = Color(0.13, 0.15, 0.13)
    panel.size = Vector2(root.get_viewport().get_visible_rect().size)
    layer.add_child(panel)
    var title := Label.new()
    title.text = "Arte original (esquerda)  x  como aparece no jogo, câmera real a 45° (direita)"
    title.position = Vector2(20, 8)
    title.add_theme_font_size_override("font_size", 18)
    layer.add_child(title)
    var art_rows := _rows.filter(func(r): return r.has("texture"))
    var row_h := 104.0
    for index in art_rows.size():
        var row: Dictionary = art_rows[index]
        var y := 40.0 + index * row_h
        var art_image := (row["texture"] as Texture2D).get_image()
        if (row["region"] as Rect2).size != Vector2.ZERO:
            art_image = art_image.get_region(Rect2i(row["region"]))
        _add_image(layer, art_image, Rect2(20, y, 250, row_h - 12))
        _add_image(layer, row["crop"], Rect2(290, y, 250, row_h - 12))
        var text := Label.new()
        text.position = Vector2(560, y + 18)
        text.add_theme_font_size_override("font_size", 17)
        text.text = "%s\nproporção arte %.3f  |  tela %.3f  |  diferença %+.1f%%  |  giro %.1f°  %s" % [row["label"], row["art"], row["screen"], row["error"] * 100.0, row["tilt"], "OK" if row["ok"] else "FORA"]
        text.add_theme_color_override("font_color", Color(0.75, 1.0, 0.6) if row["ok"] else Color(1.0, 0.5, 0.4))
        layer.add_child(text)
    var others := _rows.filter(func(r): return not r.has("texture"))
    var lines := PackedStringArray()
    for row in others:
        var detail := "inclinação %.1f°, giro %.1f°" % [row["lean"], row["yaw"]] if row.has("lean") else "giro na tela %.1f°" % row["tilt"]
        lines.append("%s  %s: %s" % ["OK" if row["ok"] else "FORA", row["label"], detail])
    var info := Label.new()
    info.position = Vector2(20, 44.0 + art_rows.size() * row_h)
    info.add_theme_font_size_override("font_size", 13)
    info.text = "\n".join(lines)
    layer.add_child(info)
    await create_timer(0.3).timeout
    var board := root.get_viewport().get_texture().get_image()
    board.save_png(out_dir.path_join("09-auditoria-angulos-lado-a-lado.png"))
    print("BOARD ", out_dir.path_join("09-auditoria-angulos-lado-a-lado.png"))

func _add_image(layer: CanvasLayer, image: Image, box: Rect2) -> void:
    var frame := ColorRect.new()
    frame.color = Color(0.3, 0.55, 0.25)
    frame.position = box.position
    frame.size = box.size
    layer.add_child(frame)
    var rect := TextureRect.new()
    rect.texture = ImageTexture.create_from_image(image)
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.position = box.position
    rect.size = box.size
    layer.add_child(rect)
