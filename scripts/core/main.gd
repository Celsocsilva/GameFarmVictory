extends Node
## Ponto de entrada da fundação; domínios serão adicionados por fases.

func _ready() -> void:
    assert(App.session_started)
