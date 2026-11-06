extends Node3D
class_name TomatoPickupFX
## Tomates visuais que se soltam do pé e são sugados até a mochila (FV-HARVEST-001).
##
## Só visual: a quantidade de sprites não define o rendimento. Cada fruto segue
## uma curva de Bézier quadrática cujo destino é lido de `intake` A CADA FRAME,
## então os frutos acompanham o fazendeiro quando ele anda ou muda de direção.

signal fruit_arrived(index: int)
signal finished()
signal cancelled()

const TOMATO_TEXTURE := preload("res://assets/harvest/tomato_ripe.png")
const TRAIL_TEXTURE := preload("res://assets/harvest/harvest_suction_trail.png")
const SPARK_TEXTURE := preload("res://assets/harvest/harvest_pickup_spark.png")

@export_range(0.2, 1.0, 0.01) var duration_min: float = 0.35
@export_range(0.2, 1.0, 0.01) var duration_max: float = 0.60
## Altura do arco em unidades do mundo (o controlador usa 0.3–0.6 × largura da célula).
@export_range(0.0, 2.0, 0.01) var arc_height: float = 0.55
@export_range(0.0, 0.3, 0.01) var stagger: float = 0.07
## Tempo em que o fruto "estufa" no pé antes de ser puxado.
@export_range(0.0, 0.3, 0.01) var detach_time: float = 0.10
@export_range(0.1, 0.8, 0.01) var fruit_height: float = 0.6
@export_range(0.1, 1.0, 0.01) var arrival_scale: float = 0.42
@export var use_trail: bool = true
@export var use_spark: bool = true
## Altura mínima do mundo para qualquer fruto: nunca abaixo do terreno.
@export var min_world_y: float = 0.12

var _fruits: Array[Dictionary] = []
var _intake: Node3D
var _camera: Camera3D
var _elapsed := 0.0
var _arrived := 0
var _running := false
var _cancelling := false
var _lowest_y := INF
var _max_arrival_error := 0.0

## `origins`: ponto de desprendimento de cada fruto visual (um sprite por ponto).
func launch(origins: Array[Vector3], intake: Node3D) -> void:
    _intake = intake
    _camera = get_viewport().get_camera_3d()
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(origins)
    for i in origins.size():
        var sprite := _make_sprite(TOMATO_TEXTURE, fruit_height / float(TOMATO_TEXTURE.get_height()))
        sprite.name = "PickupTomato_%d" % i
        sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
        sprite.render_priority = 2
        sprite.scale = Vector3.ONE * 0.75
        sprite.top_level = true
        add_child(sprite)
        sprite.global_position = origins[i]
        var trail: Sprite3D = null
        if use_trail:
            trail = _make_sprite(TRAIL_TEXTURE, 0.7 / float(TRAIL_TEXTURE.get_width()))
            trail.name = "SuctionTrail_%d" % i
            trail.billboard = BaseMaterial3D.BILLBOARD_DISABLED
            trail.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
            # Cabeça luminosa do rastro (canto inferior esquerdo do PNG) na origem do nó.
            trail.offset = Vector2(185.0, 170.0)
            trail.modulate.a = 0.0
            trail.render_priority = 1
            trail.top_level = true
            add_child(trail)
        _fruits.append({
            "sprite": sprite,
            "trail": trail,
            "origin": origins[i],
            "start": i * stagger,
            "duration": rng.randf_range(duration_min, duration_max),
            # Trajetórias levemente diferentes: lateral e altura do arco.
            "side": rng.randf_range(-0.35, 0.35),
            "arc": arc_height * rng.randf_range(0.8, 1.15),
            "done": false,
            "last_position": origins[i]
        })
    _running = true
    if _fruits.is_empty():
        _finish()

func get_fruit_count() -> int:
    return _fruits.size()

func get_lowest_world_y() -> float:
    return _lowest_y

## Maior distância entre o fruto e o marcador no instante da chegada (QA).
func get_max_arrival_error() -> float:
    return _max_arrival_error

func is_running() -> bool:
    return _running

## Interrompe: frutos ainda no ar voltam para a planta e somem. Nada é confirmado.
func cancel() -> void:
    if not _running:
        return
    _running = false
    _cancelling = true
    cancelled.emit()
    if not is_inside_tree():
        queue_free()
        return
    var tween := create_tween().set_parallel(true)
    for fruit in _fruits:
        if fruit["done"]:
            continue
        var sprite: Sprite3D = fruit["sprite"]
        tween.tween_property(sprite, "global_position", fruit["origin"], 0.18)
        tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
        if fruit["trail"]:
            (fruit["trail"] as Sprite3D).visible = false
    tween.chain().tween_callback(queue_free)

func _process(delta: float) -> void:
    if not _running:
        return
    if not is_instance_valid(_intake):
        cancel()
        return
    _elapsed += delta
    var target := _intake.global_position
    for i in _fruits.size():
        var fruit := _fruits[i]
        if fruit["done"]:
            continue
        var local_time: float = _elapsed - fruit["start"]
        var sprite: Sprite3D = fruit["sprite"]
        if local_time < 0.0:
            continue
        if local_time < detach_time:
            # Estufa no pé, como se fosse arrancado.
            var k := local_time / detach_time
            sprite.scale = Vector3.ONE * lerpf(0.75, 1.12, sin(k * PI * 0.5))
            continue
        var t := clampf((local_time - detach_time) / fruit["duration"], 0.0, 1.0)
        # Sucção: começa devagar e acelera rumo à mochila.
        var s := 1.0 - cos(t * PI * 0.5)
        s = lerpf(s, t, 0.35)
        var point := _bezier(fruit["origin"], target, fruit["arc"], fruit["side"], s)
        point.y = maxf(point.y, min_world_y)
        _lowest_y = minf(_lowest_y, point.y)
        sprite.global_position = point
        sprite.scale = Vector3.ONE * lerpf(1.12, arrival_scale, s * s)
        _update_trail(fruit, point, t, delta)
        fruit["last_position"] = point
        if t >= 1.0:
            _max_arrival_error = maxf(_max_arrival_error, point.distance_to(_intake.global_position))
            fruit["done"] = true
            sprite.visible = false
            if fruit["trail"]:
                (fruit["trail"] as Sprite3D).visible = false
            _arrived += 1
            fruit_arrived.emit(i)
            if _arrived >= _fruits.size():
                _finish()
                return

func _bezier(origin: Vector3, target: Vector3, arc: float, side: float, s: float) -> Vector3:
    var mid := (origin + target) * 0.5
    var flat := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
    var lateral := Vector3.UP.cross(flat.normalized()) if flat.length() > 0.01 else Vector3.RIGHT
    var control := mid + Vector3.UP * (arc + absf(target.y - origin.y) * 0.25) + lateral * side
    var a := origin.lerp(control, s)
    var b := control.lerp(target, s)
    return a.lerp(b, s)

## Rastro discreto alinhado à direção do voo na tela; some no início e no fim.
func _update_trail(fruit: Dictionary, point: Vector3, t: float, delta: float) -> void:
    var trail: Sprite3D = fruit["trail"]
    if trail == null or _camera == null or delta <= 0.0:
        return
    var velocity: Vector3 = (point - fruit["last_position"]) / delta
    var basis := _camera.global_basis
    var screen := Vector2(velocity.dot(basis.x), velocity.dot(basis.y))
    if screen.length() < 0.2:
        trail.modulate.a = 0.0
        return
    # No PNG o rastro corre do canto superior direito para a cabeça (inferior esquerdo).
    var art_direction := Vector2(-1.0, -0.62).angle()
    var roll := screen.angle() - art_direction
    var stretch := clampf(screen.length() / 9.0, 0.45, 1.0)
    trail.global_transform = Transform3D(basis * Basis(Vector3(0.0, 0.0, 1.0), roll) * Basis.from_scale(Vector3.ONE * stretch), point)
    trail.modulate.a = sin(t * PI) * 0.4

func _finish() -> void:
    _running = false
    if use_spark and is_instance_valid(_intake):
        _play_spark(_intake.global_position)
    else:
        queue_free()
    finished.emit()

func _play_spark(at: Vector3) -> void:
    var spark := _make_sprite(SPARK_TEXTURE, 0.75 / float(SPARK_TEXTURE.get_width()))
    spark.name = "PickupSpark"
    spark.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
    spark.no_depth_test = true
    spark.render_priority = 3
    spark.top_level = true
    add_child(spark)
    spark.global_position = at
    spark.scale = Vector3.ONE * 0.3
    var tween := create_tween().set_parallel(true)
    tween.tween_property(spark, "scale", Vector3.ONE * 0.85, 0.26).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(spark, "modulate:a", 0.0, 0.26).set_ease(Tween.EASE_IN)
    tween.chain().tween_callback(queue_free)

func _make_sprite(texture: Texture2D, pixel_size: float) -> Sprite3D:
    var sprite := Sprite3D.new()
    sprite.texture = texture
    sprite.pixel_size = pixel_size
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.shaded = false
    sprite.double_sided = true
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return sprite
