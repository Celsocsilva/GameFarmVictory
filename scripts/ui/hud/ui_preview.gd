extends Control
## Cena de preview do UI-004: todos os componentes reutilizáveis aplicados, com
## valores de exemplo desenhados pela engine (nenhum número vem dos PNGs).
## Abrir scenes/ui/hud/UiPreview.tscn e rodar (F6).

const COMPONENTS := "res://scenes/ui/hud/components/"

func _ready() -> void:
    var background := ColorRect.new()
    background.color = Color(0.55, 0.74, 0.38)
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var bar := _add("TopStatusBar", Vector2(16, 12), 0.62) as TopStatusBar
    bar.set_level(12)
    bar.set_money(1250)
    bar.set_tomatoes(18, 56)
    bar.set_crates(3, 7)

    var level := _add("PlayerLevelPanel", Vector2(16, 130), 0.45) as PlayerLevelPanel
    level.set_level(12, 2340, 3000)

    var mission := _add("MissionPanel", Vector2(16, 260), 0.5) as MissionPanel
    mission.set_mission("Colher tomates", MissionTracker.ICON_TOMATO, 56, 10)
    mission.set_progress(18, 56)

    var values := {"MoneyCounter": [1250, -1], "TomatoCounter": [18, 56], "CrateCounter": [3, 7], "WaterCounter": [30, -1], "CoinCounter": [5, -1]}
    var y := 130.0
    for scene_name in values:
        var counter := _add(scene_name, Vector2(880, y), 0.6) as HudCounter
        var pair: Array = values[scene_name]
        if int(pair[1]) > 0:
            counter.set_ratio(int(pair[0]), int(pair[1]), false)
        else:
            counter.set_value(int(pair[0]), false)
        y += 86.0

    var sale := _add("SalePopup", Vector2(16, 460), 0.5) as SalePopup
    sale.setup(6, 2)

    var store := _add("StoreButton", Vector2(1150, 580), 0.45)
    store.name = "StoreButton"

    var banner := _add("InfoBanner", Vector2(300, 600), 0.42) as InfoBanner
    banner.show_message("Mochila cheia! Leve as caixas ao Balcão de vendas.")

    var reward := (load(COMPONENTS + "RewardPopup.tscn") as PackedScene).instantiate() as RewardPopup
    add_child(reward)
    reward.set_anchors_preset(Control.PRESET_FULL_RECT)
    reward.offset_left = 330.0
    reward.offset_right = -420.0
    reward.dim.color = Color(0, 0, 0, 0)
    reward.show_reward("Recompensa!", "Missão concluída!", 75)

func _add(scene_name: String, at: Vector2, factor: float) -> Control:
    var node := (load(COMPONENTS + scene_name + ".tscn") as PackedScene).instantiate() as Control
    add_child(node)
    node.position = at
    node.scale = Vector2.ONE * factor
    return node
