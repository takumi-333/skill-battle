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
	prototype.dedicated_connection._join_data = {"room": {"id": "ffa-ui-test"}, "slot": 1}
	prototype.dedicated_connection.reserved_slot = 1
	prototype.dedicated_connected_slots.append(1)
	prototype.refresh_lobby_label()
	assert(prototype.get_node("UIRoot/Lobby/PlayerOnePreview").visible)
	assert(str(prototype.get_node("UIRoot/Lobby/PlayerOneInfo").text).begins_with("あなた"))
	assert(prototype.get_node("UIRoot/Lobby/PlayerThreeCard").visible)
	assert(prototype.get_node("UIRoot/Lobby/PlayerOneReady").visible)
	assert(prototype.get_node("UIRoot/Lobby/StartButton").visible)
	var local_player: Dictionary = prototype.players[1]
	local_player["defeated"] = true
	local_player["spectator_target_id"] = 2
	prototype.players[1] = local_player
	assert(prototype.is_local_player_spectating())
	assert(prototype.get_camera_player_id() == 2)
	prototype.queue_free()
	print("FFA lobby UI test passed")
	quit()
