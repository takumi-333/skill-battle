extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var prototype = MAIN_SCENE.instantiate()
	root.add_child(prototype)
	await process_frame
	prototype.network_mode = "client"
	prototype.local_player_id = 1
	prototype.dedicated_match_mode = "free_for_all"
	var first_opponent: Dictionary = prototype.players[2]
	first_opponent["character_id"] = "arithmetic"
	first_opponent["arithmetic_interference_multiplier"] = 1.5
	prototype.players[2] = first_opponent
	var second_opponent: Dictionary = prototype.players[3]
	second_opponent["character_id"] = "arithmetic"
	second_opponent["arithmetic_interference_multiplier"] = 2.0
	prototype.players[3] = second_opponent
	prototype.update_hud()
	var duel_layout: Control = prototype.get_node("HUDLayer/HUD/DuelLayout")
	var ffa_layout: Control = prototype.get_node("HUDLayer/HUD/FfaLayout")
	var first_label: Label = ffa_layout.get_node("OpponentOneArithmeticMultiplier")
	var second_label: Label = ffa_layout.get_node("OpponentTwoArithmeticMultiplier")
	assert(not duel_layout.visible)
	assert(ffa_layout.visible)
	assert(first_label.visible)
	assert(second_label.visible)
	assert(first_label.text == "f(x) = 1.5x")
	assert(second_label.text == "f(x) = 2.0x")
	assert(first_label.position.is_equal_approx(Vector2(780, 77)))
	assert(second_label.position.is_equal_approx(Vector2(780, 136)))

	second_opponent["character_id"] = "typist"
	prototype.players[3] = second_opponent
	prototype.update_hud()
	assert(first_label.visible)
	assert(not second_label.visible)

	prototype.players.erase(3)
	prototype.dedicated_match_mode = "duel"
	prototype.update_hud()
	assert(duel_layout.visible)
	assert(not ffa_layout.visible)
	var duel_first_label: Label = duel_layout.get_node("OpponentOneArithmeticMultiplier")
	assert(duel_first_label.visible)
	assert(duel_first_label.text == "f(x) = 1.5x")
	assert(duel_first_label.position.is_equal_approx(Vector2(780, 77)))
	prototype.queue_free()
	print("Opponent arithmetic HUD test passed")
	quit()
