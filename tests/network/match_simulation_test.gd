extends SceneTree

func _init() -> void:
	_test_state_and_normal_attack()
	_test_typist_skills()
	_test_arithmetician_skills()
	_test_chanter_skills()
	_test_chanter_skill1_timeline()
	_test_focus_interruption()
	_test_simultaneous_challenges_and_individual_interruption()
	_test_challenge_miss_sequence_and_snapshot()
	_test_session_event_deduplication()
	_test_session_ready_start()
	_test_session_result_actions()
	_test_session_disconnect_transitions()
	_test_snapshot_metadata_and_recipient_filtering()
	_test_visual_snapshot_interpolation()
	_test_delayed_keycap_targets_from_launch_position()
	_test_decoy_flash_expires()
	_test_snapshot_dictionary_array_conversion()
	_test_display_name_loadout_validation()
	print("server-authoritative match simulation tests passed")
	quit()

func _test_state_and_normal_attack() -> void:
	var simulation := MatchSimulation.new()
	assert(Vector2(simulation.state["players"][1]["position"]).is_equal_approx(Vector2(200, 387)))
	assert(Vector2(simulation.state["players"][2]["position"]).is_equal_approx(Vector2(1480, 387)))
	simulation.step(10.0, {1: {"move": Vector2.LEFT}, 2: {"move": Vector2.DOWN}})
	assert(Vector2(simulation.state["players"][1]["position"]).is_equal_approx(Vector2(30, 387)))
	assert(Vector2(simulation.state["players"][2]["position"]).is_equal_approx(Vector2(1480, 744)))
	for player in simulation.state["players"].values():
		assert(player.has("attack_time"))
		assert(player.has("hit_time"))
		assert(player.has("challenge_count"))
	simulation.state["players"][1]["position"] = Vector2(100, 100)
	simulation.state["players"][1]["facing"] = Vector2.RIGHT
	simulation.state["players"][2]["position"] = Vector2(180, 100)
	assert(simulation.handle_event(1, {"type": "attack"}))
	assert(int(simulation.state["players"][2]["hp"]) == 88)
	assert(not simulation.handle_event(1, {"type": "attack"}))


func _test_display_name_loadout_validation() -> void:
	assert(MatchProtocol.valid_display_name("プレイヤー01"))
	assert(not MatchProtocol.valid_display_name("   "))
	assert(not MatchProtocol.valid_display_name("a".repeat(MatchProtocol.MAX_DISPLAY_NAME_LENGTH + 1)))
	assert(MatchProtocol.valid_event(MatchProtocol.make_event(1, "loadout", {"character": 0, "big_skill": "typist_trident", "display_name": "名前テスト"}), -1))
	assert(not MatchProtocol.valid_event(MatchProtocol.make_event(1, "loadout", {"character": 0, "big_skill": "typist_trident", "display_name": ""}), -1))
	var simulation := MatchSimulation.new()
	assert(simulation.handle_event(1, {"type": "loadout", "payload": {"character": 2, "big_skill": "typist_trident", "display_name": "同期名"}}))
	assert(str(simulation.state["players"][1]["name"]) == "同期名")
	assert(bool(simulation.state["players"][1]["has_display_name"]))
	assert(not bool(simulation.state["players"][2]["has_display_name"]))

func _test_typist_skills() -> void:
	var simulation := MatchSimulation.new()
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	_complete_typing(simulation, 1)
	assert(simulation.state["challenges"].is_empty())
	assert(not simulation.state["skill_projectiles"].is_empty())
	var big_simulation := MatchSimulation.new()
	assert(big_simulation.handle_event(1, {"type": "big_skill"}))
	_complete_typing(big_simulation, 1)
	assert(int(big_simulation.state["trident_impacts"][0]["impact_id"]) > 0)
	big_simulation.step(1.1, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(bool(big_simulation.state["trident_impacts"][0]["released"]))
	assert(not big_simulation.state["trident_impacts"].is_empty() or not big_simulation.state["skill_projectiles"].is_empty())
	var skill3_simulation := MatchSimulation.new()
	assert(skill3_simulation.handle_event(1, {"type": "skill3"}))
	_complete_typing(skill3_simulation, 1)
	assert(not skill3_simulation.state["hammer_spins"].is_empty())
	assert(int(skill3_simulation.state["hammer_spins"][0]["presentation_id"]) > 0)

func _test_arithmetician_skills() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 1, "typist_trident")
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	_complete_arithmetic(simulation, 1)
	assert(not simulation.state["decoys"].is_empty())
	var big_simulation := MatchSimulation.new()
	big_simulation.configure_loadout(1, 1, "typist_trident")
	assert(big_simulation.handle_event(1, {"type": "big_skill"}))
	_complete_arithmetic(big_simulation, 1)
	assert(float(big_simulation.state["players"][1]["invisible_time"]) > 0.0)

func _test_chanter_skills() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 2, "typist_trident")
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var target: PackedVector2Array = simulation.state["challenges"][1]["target"]
	assert(simulation.handle_event(1, {"type": "challenge_trace", "payload": target}))
	assert(simulation.state["challenges"].is_empty())
	assert(simulation.state["magic_zones"].size() == 3)
	var big_simulation := MatchSimulation.new()
	big_simulation.configure_loadout(1, 2, "typist_trident")
	assert(big_simulation.handle_event(1, {"type": "big_skill"}))
	big_simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var big_target: PackedVector2Array = big_simulation.state["challenges"][1]["target"]
	assert(big_simulation.handle_event(1, {"type": "challenge_trace", "payload": big_target}))
	assert(big_simulation.state["skill_projectiles"].size() == 16)
	# Shot 5 is perpendicular to the owner's default right-facing direction.
	# Its direction must remain radial after its delayed launch time elapses.
	big_simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var radial_projectile: Dictionary = big_simulation.state["skill_projectiles"][4]
	assert(Vector2(radial_projectile["velocity"]).normalized().is_equal_approx(Vector2.DOWN))


func _test_chanter_skill1_timeline() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 2, "typist_trident")
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var target: PackedVector2Array = simulation.state["challenges"][1]["target"]
	assert(simulation.handle_event(1, {"type": "challenge_trace", "payload": target}))
	assert(simulation.state["magic_zones"].size() == 3)
	var first_zone: Dictionary = simulation.state["magic_zones"][0]
	assert(is_equal_approx(float(first_zone["delay"]), 0.0))
	assert(is_equal_approx(float(first_zone["warning_duration"]), 0.5))
	assert(is_equal_approx(float(first_zone["active_duration"]), 2.0))
	assert(is_equal_approx(float(simulation.state["magic_zones"][1]["delay"]), 1.5))
	assert(is_equal_approx(float(simulation.state["magic_zones"][2]["delay"]), 3.0))

	var initial_target_position := Vector2(simulation.state["players"][2]["position"])
	var damage := int(first_zone["damage"])
	assert(damage == 7)
	simulation.step(0.49, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(bool(simulation.state["magic_zones"][0]["spawned"]))
	assert(Vector2(simulation.state["magic_zones"][0]["position"]).is_equal_approx(initial_target_position))
	assert(int(simulation.state["players"][2]["hp"]) == 100)
	simulation.step(0.01, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(int(simulation.state["players"][2]["hp"]) == 100 - damage)
	simulation.step(0.5, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(int(simulation.state["players"][2]["hp"]) == 100 - damage * 2)
	# サーバー権威判定はローカル側と同じ、横100px・縦110pxへ拡張した
	# 楕円で魔方陣とキャラクターの重なりを判定する。
	var zone_center := Vector2(600.0, 400.0)
	simulation.state["players"][2]["position"] = zone_center + Vector2(100.0, 12.0)
	assert(simulation._point_hits_chanter_zone(zone_center, 2))
	simulation.state["players"][2]["position"] = zone_center + Vector2(100.1, 12.0)
	assert(not simulation._point_hits_chanter_zone(zone_center, 2))
	simulation.state["players"][2]["position"] = zone_center + Vector2(0.0, 122.1)
	assert(not simulation._point_hits_chanter_zone(zone_center, 2))

	var failure_simulation := MatchSimulation.new()
	failure_simulation.configure_loadout(1, 2, "typist_trident")
	assert(failure_simulation.handle_event(1, {"type": "small_skill"}))
	failure_simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var failed_trace := PackedVector2Array()
	for index in range(10):
		failed_trace.append(Vector2(10.0 + float(index) * 10.0, 10.0))
	assert(failure_simulation.handle_event(1, {"type": "challenge_trace", "payload": failed_trace}))
	assert(failure_simulation.state["challenges"].is_empty())
	assert(failure_simulation.state["magic_zones"].is_empty())

func _test_focus_interruption() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(2, 0, "typist_trident")
	simulation.state["players"][1]["position"] = Vector2(100, 100)
	simulation.state["players"][1]["facing"] = Vector2.RIGHT
	simulation.state["players"][2]["position"] = Vector2(180, 100)
	assert(simulation.handle_event(2, {"type": "small_skill"}))
	for index in 3:
		simulation.handle_event(1, {"type": "attack"})
		simulation.state["players"][1]["attack_cooldown"] = 0.0
	assert(simulation.state["challenges"].is_empty())

func _test_simultaneous_challenges_and_individual_interruption() -> void:
	var simulation := MatchSimulation.new()
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	assert(simulation.handle_event(2, {"type": "small_skill"}))
	assert(simulation.state["challenges"].size() == 2)
	assert(bool(simulation.state["players"][1]["focused"]))
	assert(bool(simulation.state["players"][2]["focused"]))
	simulation.call("_apply_damage", 1, 30, "test")
	assert(not simulation.state["challenges"].has(1))
	assert(simulation.state["challenges"].has(2))
	_complete_arithmetic(simulation, 2)
	assert(simulation.state["challenges"].is_empty())

func _test_challenge_miss_sequence_and_snapshot() -> void:
	var simulation := MatchSimulation.new()
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	assert(simulation.handle_event(1, {"type": "challenge_character", "payload": "?"}))
	var challenge: Dictionary = simulation.state["challenges"][1]
	assert(int(challenge["miss_sequence"]) == 1)
	assert(is_equal_approx(float(challenge["elapsed"]), 1.8))
	var snapshot := MatchProtocol.snapshot("test", simulation.state, "match", "", 1, 42, {1: 7, 2: 3})
	var snapshot_challenge: Dictionary = snapshot["challenges"][1]
	assert(int(snapshot_challenge["miss_sequence"]) == 1)
	assert(not snapshot_challenge.has("answer"))
	assert(int(snapshot["server_tick"]) == 42)
	assert(int(snapshot["input_acknowledgements"][1]) == 7)


func _test_snapshot_metadata_and_recipient_filtering() -> void:
	var simulation := MatchSimulation.new()
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	assert(simulation.handle_event(2, {"type": "small_skill"}))
	var snapshot := MatchProtocol.snapshot("test", simulation.state, "match", "", 1, 120, {1: 15, 2: 18})
	assert(snapshot["challenges"].has(1))
	assert(not snapshot["challenges"].has(2))
	assert(not (snapshot["challenges"][1] as Dictionary).has("answer"))
	assert(not (snapshot["players"][1] as Dictionary).has("normal_damage"))
	assert(not (snapshot["players"][1] as Dictionary).has("attack_damage_buff"))
	assert(is_equal_approx(MatchProtocol.TICK_SECONDS, 1.0 / 60.0))


func _test_visual_snapshot_interpolation() -> void:
	var previous := {
		"players": {1: {"position": Vector2(0, 0), "facing": Vector2.RIGHT}},
		"skill_projectiles": [{"projectile_id": 7, "owner_id": 1, "position": Vector2(10, 0), "velocity": Vector2.RIGHT, "lifetime": 2.0}],
		"magic_zones": [{"presentation_id": 8, "owner_id": 1, "position": Vector2.ZERO, "spawned": false}],
		"shockwaves": [], "trident_impacts": [], "decoys": [], "hammer_spins": [],
	}
	var current := {
		"players": {1: {"position": Vector2(20, 0), "facing": Vector2.DOWN}},
		"skill_projectiles": [{"projectile_id": 7, "owner_id": 1, "position": Vector2(30, 0), "velocity": Vector2.DOWN, "lifetime": 1.0}],
		"magic_zones": [{"presentation_id": 8, "owner_id": 1, "position": Vector2(600, 400), "spawned": true}],
		"shockwaves": [], "trident_impacts": [], "decoys": [], "hammer_spins": [],
	}
	var blended := MatchProtocol.interpolate_visual_state(previous, current, 0.5)
	assert(Vector2(blended["players"][1]["position"]).is_equal_approx(Vector2(10, 0)))
	assert(Vector2(blended["skill_projectiles"][0]["position"]).is_equal_approx(Vector2(20, 0)))
	assert(Vector2(blended["magic_zones"][0]["position"]).is_equal_approx(Vector2(600, 400)))
	assert(is_equal_approx(float(blended["skill_projectiles"][0]["lifetime"]), 1.5))
	assert(absf(MatchProtocol.lerp_angle_shortest(6.2, 0.1, 0.5) - 0.008407) < 0.02)

func _test_session_event_deduplication() -> void:
	var session := MatchSession.new("test-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
	session.phase = "match"
	assert(session.submit_event(11, MatchProtocol.make_event(1, "small_skill")))
	assert(not session.submit_event(11, MatchProtocol.make_event(1, "small_skill")))
	assert(session.submit_input(11, MatchProtocol.make_input(4, Vector2.RIGHT)))
	var snapshot := session.make_snapshot(1, 99)
	assert(int(snapshot["server_tick"]) == 99)
	assert(int(snapshot["input_acknowledgements"][1]) == 4)
	var start_position := Vector2(session.simulation.state["players"][1]["position"])
	session.step(MatchProtocol.TICK_SECONDS)
	assert(Vector2(session.simulation.state["players"][1]["position"]).x > start_position.x)
	for index in MatchSession.INPUT_STALE_TICKS + 1:
		session.step(MatchProtocol.TICK_SECONDS)
	var stale_position := Vector2(session.simulation.state["players"][1]["position"])
	session.step(MatchProtocol.TICK_SECONDS)
	assert(Vector2(session.simulation.state["players"][1]["position"]).is_equal_approx(stale_position))

func _test_session_ready_start() -> void:
	var session := MatchSession.new("ready-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
	assert(session.make_snapshot()["connected_slots"] == [1, 2])
	session.set_ready(11, true)
	assert(session.phase == "lobby")
	assert(bool(session.make_snapshot()["ready"][1]))
	assert(not bool(session.make_snapshot()["ready"][2]))
	session.set_ready(12, true)
	assert(session.phase == "lobby")
	assert(bool(session.make_snapshot()["ready"][1]))
	assert(bool(session.make_snapshot()["ready"][2]))
	assert(not session.start(12))
	assert(session.start(11))
	assert(session.phase == "countdown")
	assert(is_equal_approx(float(session.make_snapshot()["countdown_remaining"]), MatchSession.READY_DURATION))
	assert(not session.submit_input(11, MatchProtocol.make_input(0, Vector2.RIGHT)))
	session.step(MatchSession.READY_DURATION)
	assert(session.phase == "match")
	assert(is_equal_approx(float(session.simulation.state["time_remaining"]), 90.0))


func _test_session_result_actions() -> void:
	var session := MatchSession.new("result-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
	session.simulation.configure_loadout(1, 1, "typist_trident")
	session.phase = "result"
	session.simulation.state["match_over"] = true
	assert(not session.request_result_action(999, "rematch"))
	assert(session.request_result_action(11, "rematch"))
	assert(session.phase == "result")
	assert(bool(session.make_snapshot()["rematch_ready"][1]))
	assert(not bool(session.make_snapshot()["rematch_ready"][2]))
	assert(session.request_result_action(12, "rematch"))
	assert(session.phase == "countdown")
	assert(not session.submit_event(11, MatchProtocol.make_event(1, "small_skill")))
	session.step(MatchSession.READY_DURATION)
	assert(session.phase == "match")
	assert(not bool(session.simulation.state["match_over"]))
	assert(str(session.simulation.state["players"][1]["character_id"]) == "arithmetic")
	session.phase = "result"
	session.simulation.state["match_over"] = true
	assert(session.request_result_action(12, "lobby"))
	assert(session.phase == "lobby")
	assert(not bool(session.make_snapshot()["ready"][1]))
	assert(not bool(session.make_snapshot()["ready"][2]))
	assert(not bool(session.make_snapshot()["rematch_ready"][1]))
	assert(not bool(session.make_snapshot()["rematch_ready"][2]))


func _test_session_disconnect_transitions() -> void:
	var lobby_session := MatchSession.new("lobby-disconnect-room")
	assert(lobby_session.join(11, 1) == 1)
	assert(lobby_session.join(12, 2) == 2)
	lobby_session.set_ready(12, true)
	assert(lobby_session.leave(12))
	assert(lobby_session.phase == "lobby")
	assert(not bool(lobby_session.simulation.state["match_over"]))
	assert(lobby_session.make_snapshot()["connected_slots"] == [1])
	assert(not bool(lobby_session.make_snapshot()["ready"][2]))
	var countdown_session := MatchSession.new("countdown-disconnect-room")
	assert(countdown_session.join(11, 1) == 1)
	assert(countdown_session.join(12, 2) == 2)
	countdown_session.set_ready(11, true)
	countdown_session.set_ready(12, true)
	assert(countdown_session.start(11))
	assert(countdown_session.phase == "countdown")
	assert(countdown_session.leave(12))
	assert(countdown_session.phase == "lobby")
	assert(is_zero_approx(float(countdown_session.make_snapshot()["countdown_remaining"])))
	var match_session := MatchSession.new("match-disconnect-room")
	assert(match_session.join(11, 1) == 1)
	assert(match_session.join(12, 2) == 2)
	match_session.phase = "match"
	assert(match_session.leave(12))
	assert(match_session.phase == "result")
	assert(bool(match_session.simulation.state["match_over"]))
	assert(int(match_session.simulation.state["winner_id"]) == 1)


func _test_delayed_keycap_targets_from_launch_position() -> void:
	var simulation := MatchSimulation.new()
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	_complete_typing(simulation, 1)
	var projectile: Dictionary = simulation.state["skill_projectiles"][1]
	projectile["delay"] = 0.01
	simulation.state["skill_projectiles"][1] = projectile
	simulation.state["players"][1]["position"] = Vector2(900, 180)
	simulation.state["players"][2]["position"] = Vector2(1500, 720)
	simulation.step(0.01, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	projectile = simulation.state["skill_projectiles"][1]
	var to_target := Vector2(simulation.state["players"][2]["position"]) - Vector2(projectile["position"])
	assert(Vector2(projectile["velocity"]).normalized().dot(to_target.normalized()) > 0.999)


func _test_decoy_flash_expires() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 1, "typist_trident")
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	_complete_arithmetic(simulation, 1)
	simulation.step(0.3, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	for decoy in simulation.state["decoys"]:
		assert(is_zero_approx(float(decoy["flash_time"])))

func _test_snapshot_dictionary_array_conversion() -> void:
	var wire_array: Array = [{"id": 1}, {"id": 2}]
	var converted: Array[Dictionary] = MatchProtocol.dictionary_array(wire_array)
	assert(converted.size() == 2)
	assert(int(converted[0]["id"]) == 1)
	wire_array[0]["id"] = 99
	assert(int(converted[0]["id"]) == 1)
	assert(MatchProtocol.dictionary_array(["invalid", 10]).is_empty())

func _complete_typing(simulation: MatchSimulation, slot: int) -> void:
	var answer := str(simulation.state["challenges"][slot]["answer"])
	for character in answer:
		assert(simulation.handle_event(slot, {"type": "challenge_character", "payload": character}))

func _complete_arithmetic(simulation: MatchSimulation, slot: int) -> void:
	var answer := str(simulation.state["challenges"][slot]["answer"])
	assert(simulation.handle_event(slot, {"type": "challenge_submit", "payload": answer}))
