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
	_test_dedicated_trace_persistence(prototype)
	_test_dedicated_trident_landing_shake(prototype)
	# The test supplies a pending reservation to exercise dedicated-only UI.
	# Clear it before the next frame so the scene never attempts a real RPC.
	(prototype.get("dedicated_connection") as Node).set("_join_data", {})
	prototype.set("phase", "result")
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
		"challenges": {
			1: {"id": 11, "owner": 1, "skill": "small_typing", "prompt": "Track", "typed": "Tr", "type": "typing", "limit": 6.0, "elapsed": 1.0, "target": PackedVector2Array(), "trace": PackedVector2Array(), "miss_sequence": 0},
			2: {"id": 12, "owner": 2, "skill": "small_arithmetic", "prompt": "12 + 3 * 8 = ?", "typed": "", "type": "arithmetic", "limit": 7.0, "elapsed": 2.0, "target": PackedVector2Array(), "trace": PackedVector2Array(), "miss_sequence": 0},
		},
	}
	prototype.call("_on_dedicated_snapshot_received", typing_snapshot)
	var typing_input := prototype.get_node("ChallengeLayer/Challenge/Content/Input") as LineEdit
	assert(typing_input.text == "Tr")
	var miss_snapshot: Dictionary = typing_snapshot.duplicate(true)
	miss_snapshot["challenges"][1]["miss_sequence"] = 1
	prototype.call("_on_dedicated_snapshot_received", miss_snapshot)
	assert(float(prototype.get("challenge_miss_flash")) > 0.0)
	assert(float(prototype.get("challenge_shake")) > 0.0)
	prototype.set("challenge_miss_flash", 0.1)
	prototype.call("_on_dedicated_snapshot_received", miss_snapshot)
	assert(is_equal_approx(float(prototype.get("challenge_miss_flash")), 0.1))
	prototype.set("local_player_id", 2)
	prototype.call("_on_dedicated_snapshot_received", typing_snapshot)
	assert(int(prototype.get("challenge_owner")) == 2)
	var prompt := prototype.get_node("ChallengeLayer/Challenge/Content/Prompt") as Label
	assert(prompt.text == "12 + 3 * 8 = ?")
	prototype.set("local_player_id", 1)
	var lobby_snapshot: Dictionary = typing_snapshot.duplicate(true)
	lobby_snapshot["phase"] = "lobby"
	lobby_snapshot["challenges"] = {}
	lobby_snapshot["connected_slots"] = [1]
	prototype.call("_on_dedicated_snapshot_received", lobby_snapshot)
	assert(str(prototype.get("screen")) == "online_waiting")
	var opponent_preview := prototype.get_node("UIRoot/Lobby/PlayerTwoPreview") as TextureRect
	assert(not opponent_preview.visible)
	lobby_snapshot["connected_slots"] = [1, 2]
	prototype.call("_on_dedicated_snapshot_received", lobby_snapshot)
	assert(opponent_preview.visible)
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
	_test_room_list_modal(prototype)


func _test_room_list_modal(prototype: Node) -> void:
	var join_button := prototype.get_node("UIRoot/Connection/JoinButton") as Button
	assert(_has_connection(join_button, "open_room_list_modal"))
	prototype.call("_on_dedicated_rooms_received", [
		{"id": "alpha", "name": "アルファ", "players": 1},
		{"id": "beta", "name": "ベータ", "players": 0},
	])
	var rows := prototype.get_node("UIRoot/Connection/RoomListModal/RoomRowsScroll/RoomRows") as VBoxContainer
	assert(rows.get_child_count() == 2)
	for row in rows.get_children():
		var enter_button := (row as HBoxContainer).get_child(1) as Button
		assert(enter_button.text == "入室")
		assert(_has_connection(enter_button, "_join_dedicated_room"))


func _has_connection(button: Button, method_name: String) -> bool:
	for connection in button.pressed.get_connections():
		var callback: Callable = connection.get("callable")
		if callback.get_method() == method_name:
			return true
	return false


func _test_dedicated_trace_persistence(prototype: Node) -> void:
	prototype.set("local_player_id", 1)
	prototype.set("network_mode", "client")
	var dedicated_connection: Node = prototype.get("dedicated_connection")
	dedicated_connection.set("_join_data", {"room": {"id": "trace-test"}})
	var players: Dictionary = prototype.get("players").duplicate(true)
	players[1]["character_id"] = "chanter"
	players[1]["visual_id"] = "chanter"
	var trace_snapshot := {
		"players": players,
		"time_remaining": 80.0,
		"match_over": false,
		"winner_id": 0,
		"phase": "match",
		"status_text": "tracing",
		"ready": {1: false, 2: false},
		"skill_projectiles": [], "magic_zones": [], "shockwaves": [], "trident_impacts": [], "decoys": [], "hammer_spins": [],
		"challenges": {
			1: {"id": 31, "owner": 1, "skill": "small_trace", "prompt": "円をなぞってください", "typed": "", "type": "tracing", "limit": 0.0, "elapsed": 1.0, "target": PackedVector2Array([Vector2(100, 100), Vector2(120, 100)]), "trace": PackedVector2Array(), "miss_sequence": 0},
		},
	}
	prototype.call("_on_dedicated_snapshot_received", trace_snapshot)
	var local_trace := PackedVector2Array([Vector2(100, 100), Vector2(105, 103), Vector2(110, 108)])
	prototype.set("challenge_trace_points", local_trace)
	prototype.call("_on_dedicated_snapshot_received", trace_snapshot)
	assert(prototype.get("challenge_trace_points") == local_trace)
	var new_trace_snapshot: Dictionary = trace_snapshot.duplicate(true)
	new_trace_snapshot["challenges"][1]["id"] = 32
	prototype.call("_on_dedicated_snapshot_received", new_trace_snapshot)
	assert((prototype.get("challenge_trace_points") as PackedVector2Array).is_empty())


func _test_dedicated_trident_landing_shake(prototype: Node) -> void:
	prototype.set("local_player_id", 1)
	prototype.set("network_mode", "client")
	prototype.set("dedicated_trident_release_states", {})
	prototype.set("screen_shake_time", 0.0)
	var snapshot := {
		"players": prototype.get("players"),
		"time_remaining": 80.0,
		"match_over": false,
		"winner_id": 0,
		"phase": "match",
		"status_text": "三叉震槌",
		"ready": {1: false, 2: false},
		"skill_projectiles": [],
		"magic_zones": [],
		"shockwaves": [],
		"trident_impacts": [{"impact_id": 99, "owner_id": 1, "origin": Vector2(300, 390), "facing": Vector2.RIGHT, "score": 80, "elapsed": 0.9, "strike_duration": 1.0, "duration": 1.9, "released": false}],
		"decoys": [],
		"hammer_spins": [],
		"challenges": {},
	}
	prototype.call("_on_dedicated_snapshot_received", snapshot)
	assert(is_zero_approx(float(prototype.get("screen_shake_time"))))
	var landed_snapshot: Dictionary = snapshot.duplicate(true)
	landed_snapshot["trident_impacts"][0]["released"] = true
	prototype.call("_on_dedicated_snapshot_received", landed_snapshot)
	assert(float(prototype.get("screen_shake_time")) > 0.0)
	prototype.set("screen_shake_time", 0.0)
	prototype.call("_on_dedicated_snapshot_received", landed_snapshot)
	assert(is_zero_approx(float(prototype.get("screen_shake_time"))))
