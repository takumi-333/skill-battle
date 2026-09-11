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
	_test_character_skill_persistence(prototype)
	_test_public_lobby_configuration(prototype)
	_test_local_development_lobby_configuration(prototype)
	_test_online_focus_bgm_scope(prototype)
	_test_p2p_result_challenge_cleanup(prototype)
	_test_dedicated_snapshot_ui(prototype)
	_test_dedicated_trace_persistence(prototype)
	_test_dedicated_trident_landing_shake(prototype)
	_test_sound_effect_setup(prototype)
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


func _test_character_skill_persistence(prototype: Node) -> void:
	var path := "user://character_skills.cfg"
	var had_file := FileAccess.file_exists(path)
	var original_bytes := FileAccess.get_file_as_bytes(path) if had_file else PackedByteArray()
	prototype.set("character_selection", 0)
	prototype.set("character_skill_selection", {"typist": [0, 0, 1], "arithmetician": [0, 0, 0], "chanter": [0, 0, 0]})
	prototype.call("save_character_skills")
	var save_status := prototype.get("character_saved_label") as Label
	var persistence_writable := FileAccess.file_exists(path) and save_status != null and not save_status.text.begins_with("Failed")
	if persistence_writable:
		prototype.set("character_skill_selection", {"typist": [0, 0, 0], "arithmetician": [0, 0, 0], "chanter": [0, 0, 0]})
		prototype.call("load_character_skills")
		var selections: Dictionary = prototype.get("character_skill_selection")
		assert(selections["typist"] == [0, 0, 1])
	else:
		print("character skill persistence test skipped: user:// is not writable in this environment")
	assert(prototype.call("normalize_character_skill_selection", "typist", [99, -1, 1]) == [0, 0, 1])
	if had_file and persistence_writable:
		var restore_file := FileAccess.open(path, FileAccess.WRITE)
		if restore_file != null:
			restore_file.store_buffer(original_bytes)
	elif not had_file:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_public_lobby_configuration(prototype: Node) -> void:
	var url_input := prototype.get_node("UIRoot/Home/UserSettingsModal/Panel/LobbyUrlInput") as LineEdit
	var token_input := prototype.get_node("UIRoot/Home/UserSettingsModal/Panel/InviteTokenInput") as LineEdit
	assert(url_input != null)
	assert(token_input != null)
	assert(token_input.secret)
	assert(prototype.call("_lobby_configuration_error", "", "") != "")
	assert(prototype.call("_lobby_configuration_error", "http://127.0.0.1:8000", "a".repeat(32)) != "")
	assert(prototype.call("_lobby_configuration_error", "https://lobby.example.test", "a".repeat(32)).is_empty())
	prototype.set("allow_insecure_lobby_url", true)
	assert(prototype.call("_lobby_configuration_error", "http://127.0.0.1:8000", "a".repeat(32)).is_empty())
	prototype.set("allow_insecure_lobby_url", false)


func _test_local_development_lobby_configuration(prototype: Node) -> void:
	if not OS.is_debug_build():
		print("local development lobby configuration test skipped: release build")
		return
	var path := "res://.local-server/local-client.env"
	var had_file := FileAccess.file_exists(path)
	var original_bytes := FileAccess.get_file_as_bytes(path) if had_file else PackedByteArray()
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string("LOBBY_URL=http://127.0.0.1:8000\nINVITE_TOKEN=" + "a".repeat(32) + "\n")
	file.close()
	var original_url := str(prototype.get("lobby_api_url"))
	var original_token := str(prototype.get("lobby_access_token"))
	var original_allow_http := bool(prototype.get("allow_insecure_lobby_url"))
	prototype.set("lobby_api_url", "")
	prototype.set("lobby_access_token", "")
	prototype.set("allow_insecure_lobby_url", false)
	prototype.call("_load_local_development_lobby_config")
	assert(str(prototype.get("lobby_api_url")) == "http://127.0.0.1:8000")
	assert(str(prototype.get("lobby_access_token")) == "a".repeat(32))
	assert(bool(prototype.get("allow_insecure_lobby_url")))
	prototype.set("lobby_api_url", "http://127.0.0.1:8000")
	prototype.set("lobby_access_token", "b".repeat(32))
	prototype.set("allow_insecure_lobby_url", false)
	prototype.call("_load_local_development_lobby_config")
	assert(str(prototype.get("lobby_api_url")) == "http://127.0.0.1:8000")
	assert(str(prototype.get("lobby_access_token")) == "a".repeat(32))
	assert(bool(prototype.get("allow_insecure_lobby_url")))
	prototype.set("lobby_api_url", "https://lobby.example.test")
	prototype.set("lobby_access_token", "c".repeat(32))
	prototype.set("allow_insecure_lobby_url", false)
	prototype.call("_load_local_development_lobby_config")
	assert(str(prototype.get("lobby_api_url")) == "https://lobby.example.test")
	assert(str(prototype.get("lobby_access_token")) == "c".repeat(32))
	assert(not bool(prototype.get("allow_insecure_lobby_url")))
	prototype.set("lobby_api_url", original_url)
	prototype.set("lobby_access_token", original_token)
	prototype.set("allow_insecure_lobby_url", original_allow_http)
	if had_file:
		var restore_file := FileAccess.open(path, FileAccess.WRITE)
		assert(restore_file != null)
		restore_file.store_buffer(original_bytes)
		restore_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_online_focus_bgm_scope(prototype: Node) -> void:
	var players: Dictionary = prototype.get("players").duplicate(true)
	players[1]["focused"] = false
	players[2]["focused"] = true
	prototype.set("players", players)
	prototype.set("network_mode", "client")
	prototype.set("local_player_id", 1)
	assert(not bool(prototype.call("is_battle_focus_active")))
	prototype.set("local_player_id", 2)
	assert(bool(prototype.call("is_battle_focus_active")))


func _test_p2p_result_challenge_cleanup(prototype: Node) -> void:
	prototype.set("network_mode", "client")
	prototype.set("phase", "match")
	prototype.set("screen", "match")
	prototype.set("challenge_owner", 1)
	(prototype.get_node("ChallengeLayer/Challenge") as Control).visible = true
	(prototype.get_node("ChallengeLayer/ChallengeDimmer") as Control).visible = true
	(prototype.get_node("ChallengeLayer/Challenge/Content/Input") as LineEdit).visible = true
	prototype.set("phase", "result")
	var result_state: Dictionary = prototype.call("make_network_state")
	prototype.set("phase", "match")
	prototype.call("receive_network_state", result_state)
	assert(str(prototype.get("phase")) == "result")
	assert(not (prototype.get_node("ChallengeLayer/Challenge") as Control).visible)
	assert(not (prototype.get_node("ChallengeLayer/Challenge/Content/Input") as LineEdit).visible)
	assert(int(prototype.get("challenge_owner")) == 0)


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
	var countdown_snapshot: Dictionary = lobby_snapshot.duplicate(true)
	countdown_snapshot["phase"] = "countdown"
	countdown_snapshot["status_text"] = "READY"
	countdown_snapshot["countdown_remaining"] = 0.5
	prototype.call("_on_dedicated_snapshot_received", countdown_snapshot)
	var start_prompt := prototype.get_node("UIRoot/MatchStartPrompt") as Control
	var start_prompt_label := prototype.get_node("UIRoot/MatchStartPrompt/Center/Label") as Label
	assert(str(prototype.get("screen")) == "match")
	assert(start_prompt.visible)
	assert(start_prompt_label.text == "READY")
	var fight_snapshot: Dictionary = countdown_snapshot.duplicate(true)
	fight_snapshot["phase"] = "match"
	fight_snapshot["status_text"] = "FIGHT"
	fight_snapshot["countdown_remaining"] = 0.0
	prototype.call("_on_dedicated_snapshot_received", fight_snapshot)
	assert(start_prompt.visible)
	assert(start_prompt_label.text == "FIGHT")
	prototype.set("local_player_id", 2)
	prototype.call("refresh_lobby_label")
	assert(not start_button.visible)
	prototype.set("local_player_id", 1)
	var finish_snapshot: Dictionary = typing_snapshot.duplicate(true)
	finish_snapshot["phase"] = "finish"
	finish_snapshot["match_over"] = true
	finish_snapshot["winner_id"] = 1
	finish_snapshot["finish_remaining"] = 2.0
	finish_snapshot["challenges"] = {}
	finish_snapshot["players"][2]["hp"] = 0
	finish_snapshot["players"][2]["hit_time"] = 0.2
	prototype.call("_on_dedicated_snapshot_received", finish_snapshot)
	assert(str(prototype.get("phase")) == "finish")
	assert(str(prototype.get("screen")) == "match")
	assert(is_equal_approx(float(prototype.get("finish_remaining")), 2.0))
	assert(not (prototype.get_node("ChallengeLayer/Challenge") as Control).visible)
	prototype.call("_process", 0.5)
	var finish_players: Dictionary = prototype.get("players")
	assert(is_equal_approx(float(finish_players[2]["hit_time"]), 0.1))
	var result_snapshot: Dictionary = finish_snapshot.duplicate(true)
	result_snapshot["phase"] = "result"
	result_snapshot["match_over"] = true
	result_snapshot["winner_id"] = 1
	result_snapshot["challenges"] = typing_snapshot["challenges"]
	result_snapshot["rematch_ready"] = {1: true, 2: false}
	prototype.call("_on_dedicated_snapshot_received", result_snapshot)
	var rematch_button := prototype.get_node("UIRoot/Result/RematchButton") as Button
	assert(str(prototype.get("screen")) == "result")
	assert(not (prototype.get_node("ChallengeLayer/Challenge") as Control).visible)
	assert(not (prototype.get_node("ChallengeLayer/Challenge/Content/Input") as LineEdit).visible)
	assert(int(prototype.get("challenge_owner")) == 0)
	assert(rematch_button.disabled)
	assert(rematch_button.text == "再戦を待機中")
	var return_to_lobby_snapshot: Dictionary = result_snapshot.duplicate(true)
	return_to_lobby_snapshot["phase"] = "lobby"
	return_to_lobby_snapshot["match_over"] = false
	return_to_lobby_snapshot["rematch_ready"] = {1: false, 2: false}
	return_to_lobby_snapshot["connected_slots"] = [1]
	prototype.call("_on_dedicated_snapshot_received", return_to_lobby_snapshot)
	assert(str(prototype.get("screen")) == "online_waiting")
	assert(not rematch_button.get_parent().visible)
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
		"trident_impacts": [{"impact_id": 99, "owner_id": 1, "origin": Vector2(200, 260), "facing": Vector2.RIGHT, "score": 80, "elapsed": 0.9, "strike_duration": 1.0, "duration": 1.9, "released": false}],
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


func _test_sound_effect_setup(prototype: Node) -> void:
	for path in [
		"res://assets/audio/damaged.mp3",
		"res://assets/audio/game_hit_midheavy.wav",
		"res://assets/audio/skill_miss.mp3",
		"res://assets/audio/writing_sound.wav",
	]:
		assert(ResourceLoader.exists(path))
	assert(prototype.has_method("emit_shared_sound"))
	assert(prototype.has_method("trigger_challenge_miss_feedback"))
	var writing_player := prototype.get("writing_sound_player") as AudioStreamPlayer
	assert(writing_player != null)
	assert(writing_player.stream != null)
	var writing_stream := writing_player.stream as AudioStreamWAV
	assert(writing_stream != null)
	assert(writing_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED)
	prototype.call("note_challenge_trace_motion")
	assert(int(prototype.get("writing_sound_last_motion_msec")) > 0)
	assert(writing_player.playing)
	prototype.call("stop_writing_sound")
	assert(is_zero_approx(float(prototype.get("writing_sound_last_motion_msec"))))
	assert(not writing_player.playing)
