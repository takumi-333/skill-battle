extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)
	var prototype := main_scene.instantiate()
	root.add_child(prototype)
	await process_frame
	var player_one_ready := prototype.get_node("UIRoot/Lobby/PlayerOneReady") as Button
	var player_two_ready := prototype.get_node("UIRoot/Lobby/PlayerTwoReady") as Button
	assert(_has_ready_connection(player_one_ready))
	assert(_has_ready_connection(player_two_ready))
	prototype.set("local_player_id", 1)
	assert(prototype.call("get_local_lobby_ready_button") == player_one_ready)
	prototype.set("local_player_id", 2)
	assert(prototype.call("get_local_lobby_ready_button") == player_two_ready)
	_test_dedicated_snapshot_ui(prototype)
	print("online lobby ready UI tests passed")
	quit()


func _has_ready_connection(button: Button) -> bool:
	for connection in button.pressed.get_connections():
		var callback: Callable = connection.get("callable")
		if callback.get_method() == "toggle_local_lobby_ready":
			return true
	return false


func _test_dedicated_snapshot_ui(prototype: Node) -> void:
	prototype.set("local_player_id", 1)
	prototype.set("network_mode", "client")
	var dedicated_connection: Node = prototype.get("dedicated_connection")
	dedicated_connection.set("_join_data", {"room": {"id": "ui-test"}})
	var players: Dictionary = prototype.get("players")
	var typing_snapshot := {
		"players": players,
		"time_remaining": 80.0,
		"match_over": false,
		"winner_id": 0,
		"phase": "match",
		"status_text": "入力中",
		"ready": {1: false, 2: false},
		"skill_projectiles": [],
		"magic_zones": [],
		"shockwaves": [],
		"trident_impacts": [],
		"decoys": [],
		"hammer_spins": [],
		"challenge": {"owner": 1, "skill": "small_typing", "prompt": "Track", "typed": "Tr", "type": "typing", "limit": 6.0, "elapsed": 1.0, "target": PackedVector2Array(), "trace": PackedVector2Array()},
	}
	prototype.call("_on_dedicated_snapshot_received", typing_snapshot)
	var typing_input := prototype.get_node("ChallengeLayer/Challenge/Content/Input") as LineEdit
	assert(typing_input.text == "Tr")
	var lobby_snapshot: Dictionary = typing_snapshot.duplicate(true)
	lobby_snapshot["phase"] = "lobby"
	lobby_snapshot["challenge"] = {}
	prototype.call("_on_dedicated_snapshot_received", lobby_snapshot)
	assert(str(prototype.get("screen")) == "online_waiting")
	var start_button := prototype.get_node("UIRoot/Lobby/StartButton") as Button
	assert(start_button.visible)
	assert(start_button.disabled)
	assert(start_button.text == "ゲーム開始")
	lobby_snapshot["ready"] = {1: true, 2: true}
	prototype.call("_on_dedicated_snapshot_received", lobby_snapshot)
	assert(start_button.visible)
	assert(not start_button.disabled)
	prototype.set("local_player_id", 2)
	prototype.call("refresh_lobby_label")
	assert(not start_button.visible)
