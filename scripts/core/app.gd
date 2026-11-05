extends Node
## Estado global mínimo. Regras de domínio não devem ser colocadas aqui.

const SAVE_VERSION: int = 1
var session_started: bool = false

func _ready() -> void:
    session_started = true
