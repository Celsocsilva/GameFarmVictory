extends Node3D
class_name SeedThrow

## Punhado de sementes lançado da mão do fazendeiro até a célula.
## Cada instância faz um único lançamento e se libera ao terminar; para vários
## punhados simultâneos, instancie uma cena por lançamento.

## Emitido quando o centro do punhado toca o solo (após flight_time).
signal landed(target: Vector3)

@export_range(12, 24, 1) var seed_amount: int = 18
@export_range(0.4, 1.2, 0.05) var flight_time: float = 0.75
## Variação de tamanho entre as sementes do mesmo punhado.
@export_range(0.3, 1.5, 0.05) var seed_scale_min: float = 0.45
@export_range(0.3, 1.5, 0.05) var seed_scale_max: float = 1.25
## Abertura do cone do punhado, em graus.
@export_range(0.0, 45.0, 1.0) var spread_degrees: float = 16.0
## Variação de força entre as sementes (0.18 = ±18%), espalha a queda ao redor do alvo.
@export_range(0.0, 0.4, 0.01) var velocity_variation: float = 0.18
## 1.0 solta tudo no mesmo quadro; valores menores escalonam o punhado.
@export_range(0.5, 1.0, 0.01) var release_explosiveness: float = 0.88
@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0)

@onready var particles: GPUParticles3D = $GPUParticles3D
var _launched := false

func launch(origin: Vector3, target: Vector3) -> void:
    if _launched:
        push_warning("SeedThrow.launch chamado duas vezes; instancie uma nova cena por punhado.")
        return
    _launched = true
    global_position = origin

    # Material próprio por lançamento para não alterar outros punhados ativos.
    var launch_material := particles.process_material.duplicate() as ParticleProcessMaterial
    particles.process_material = launch_material

    var velocity := solve_launch_velocity(origin, target, gravity, flight_time)
    var speed := velocity.length()
    launch_material.direction = velocity.normalized() if speed > 0.001 else Vector3.UP
    launch_material.spread = spread_degrees
    launch_material.initial_velocity_min = speed * (1.0 - velocity_variation)
    launch_material.initial_velocity_max = speed * (1.0 + velocity_variation)
    launch_material.gravity = gravity
    launch_material.scale_min = minf(seed_scale_min, seed_scale_max)
    launch_material.scale_max = maxf(seed_scale_min, seed_scale_max)

    particles.amount = clampi(seed_amount, 12, 24)
    particles.lifetime = flight_time
    particles.explosiveness = release_explosiveness
    particles.restart()
    particles.emitting = true
    await get_tree().create_timer(flight_time).timeout
    landed.emit(target)
    # A última semente sai após (1 - explosiveness) do tempo de voo.
    await get_tree().create_timer(flight_time * (1.0 - release_explosiveness) + 0.1).timeout
    queue_free()

## Velocidade inicial para que o centro do punhado chegue ao alvo sob gravidade.
static func solve_launch_velocity(origin: Vector3, target: Vector3, gravity_vector: Vector3, time: float) -> Vector3:
    var t := maxf(time, 0.1)
    return (target - origin - 0.5 * gravity_vector * t * t) / t
