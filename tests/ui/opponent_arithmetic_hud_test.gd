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
	var first_opponent: Dictionary = prototype.players[2]
	first_opponent["character_id"] = "arithmetic"
	first_opponent["arithmetic_interference_multiplier"] = 1.5
	prototype.players[2] = first_opponent
	var second_opponent: Dictionary = prototype.players[3]
	second_opponent["character_id"] = "arithmetic"
	second_opponent["arithmetic_interference_multiplier"] = 2.0
	prototype.players[3] = second_opponent
	prototype.update_hud()
	var first_label: Label = prototype.get_node("HUDLayer/HUD/OpponentOneArithmeticMultiplier")
	var second_label: Label = prototype.get_node("HUDLayer/HUD/OpponentTwoArithmeticMultiplier")
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
	prototype.update_hud()
	assert(first_label.visible)
	assert(first_label.text == "f(x) = 1.5x")
	assert(not second_label.visible)
	prototype.queue_free()
	print("Opponent arithmetic HUD test passed")
	quit()
