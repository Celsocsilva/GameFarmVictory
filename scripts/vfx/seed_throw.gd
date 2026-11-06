extends Node3D
class_name SeedThrow

@export_range(12, 20, 1) var seed_amount: int = 16
@export_range(0.5, 1.0, 0.05) var particle_lifetime: float = 0.8
@export_range(0.8, 1.5, 0.05) var seed_scale_min: float = 0.9
@export_range(0.8, 1.5, 0.05) var seed_scale_max: float = 1.1
@export_range(0.0, 15.0, 1.0) var spread_degrees: float = 7.0
@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0)
@export var seed_texture: Texture2D = preload("res://assets/seeds/tomato_seed.png")

@onready var particles: GPUParticles3D = $GPUParticles3D
var _active := false

func launch(origin: Vector3, target: Vector3) -> void:
    if _active:
        var overlapping := duplicate() as SeedThrow
        overlapping._active = false
        get_parent().add_child(overlapping)
        overlapping.launch(origin, target)
        return

    _active = true
    global_position = origin

    # Cada lançamento precisa de material próprio para não alterar outros arcos ativos.
    var launch_material := particles.process_material.duplicate() as ParticleProcessMaterial
    particles.process_material = launch_material

    # Resolve a velocidade inicial para o centro do feixe alcançar o alvo sob gravidade.
    var flight_time := maxf(particle_lifetime, 0.1)
    var travel := target - origin
    var velocity := (travel - 0.5 * gravity * flight_time * flight_time) / flight_time
    var speed := velocity.length()
    launch_material.direction = velocity.normalized() if speed > 0.001 else Vector3.UP
    launch_material.spread = spread_degrees
    launch_material.initial_velocity_min = speed * 0.97
    launch_material.initial_velocity_max = speed * 1.03
    launch_material.gravity = gravity
    launch_material.scale_min = seed_scale_min
    launch_material.scale_max = seed_scale_max

    particles.amount = clampi(seed_amount, 12, 20)
    particles.lifetime = flight_time
    particles.restart()
    particles.emitting = true
    await get_tree().create_timer(flight_time + 0.15).timeout
    queue_free()
