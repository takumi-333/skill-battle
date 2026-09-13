extends SceneTree

const TypistHammerShockwaveHitboxData = preload("res://scripts/data/typist_hammer_shockwave_hitbox.gd")

func _init() -> void:
	_test_state_and_normal_attack()
	_test_typist_skills()
	_test_typist_hammer_shockwave_hitbox()
	_test_arithmetician_skills()
	_test_hack_vision_full_homing()
	_test_arithmetician_perfect_mapping()
	_test_arithmetician_interference_points()
	_test_chanter_skills()
	_test_chanter_skill2_specification()
	_test_chanter_meteor_shower()
	_test_chanter_skill1_candidate_and_skill3()
	_test_chanter_skill3_event_driven_presentation()
	_test_lunar_eclipse_rules()
	_test_chanter_skill1_timeline()
	_test_damage_does_not_interrupt_focus()
	_test_damage_does_not_interrupt_simultaneous_challenges()
	_test_challenge_miss_sequence_and_snapshot()
	_test_session_event_deduplication()
	_test_session_ready_start()
	_test_session_knockout_finish_phase()
	_test_session_result_actions()
	_test_session_disconnect_transitions()
	_test_session_rejects_result_or_closed_room_joins()
	_test_session_keeps_result_actions_after_admission_closes()
	_test_dedicated_admission_timeout_and_status_retry_policy()
	_test_snapshot_metadata_and_recipient_filtering()
	_test_visual_snapshot_interpolation()
	_test_delayed_keycap_targets_from_launch_position()
	_test_decoy_flash_expires()
	_test_snapshot_dictionary_array_conversion()
	_test_display_name_loadout_validation()
	print("server-authoritative match simulation tests passed")
	quit()

func _test_session_rejects_result_or_closed_room_joins() -> void:
	var session := MatchSession.new("terminal-room")
	assert(session.join(11, 1) == 1)
	session.phase = "result"
	assert(session.join(22, 2) == 0)
	session.close_terminal()
	session.phase = "lobby"
	assert(session.join(22, 2) == 0)
	assert(not session.request_result_action(11, "rematch"))


func _test_session_keeps_result_actions_after_admission_closes() -> void:
	var session := MatchSession.new("closed-admission-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
	session.phase = "result"
	session.close_admission()
	assert(session.join(22, 1) == 0)
	assert(session.request_result_action(11, "rematch"))
	assert(session.request_result_action(12, "rematch"))
	assert(session.phase == "countdown")


func _test_dedicated_admission_timeout_and_status_retry_policy() -> void:
	var server := DedicatedServer.new()
	server.token_secret = "dedicated-server-test-secret"
	assert(server._validated_ticket("", "room", 1).is_empty())
	assert(server._validated_ticket("not-a-ticket", "room", 1).is_empty())
	var ticket_payload := {
		"room_id": "room",
		"slot": 1,
		"expires_at": Time.get_unix_time_from_system() + 60,
		"nonce": "n".repeat(32),
	}
	var ticket_body := Marshalls.raw_to_base64(JSON.stringify(ticket_payload).to_utf8_buffer())
	var hmac := HMACContext.new()
	hmac.start(HashingContext.HASH_SHA256, server.token_secret.to_utf8_buffer())
	hmac.update(ticket_body.to_utf8_buffer())
	var valid_ticket := ticket_body + "." + hmac.finish().hex_encode()
	assert(not server._validated_ticket(valid_ticket, "room", 1).is_empty())
	assert(is_equal_approx(DedicatedServer.CONSUME_TIMEOUT_SECONDS, 5.0))
	server.unauthenticated_peer_deadlines[91] = 1000
	assert(not server._is_unauthenticated_peer_expired(91, 999))
	assert(server._is_unauthenticated_peer_expired(91, 1000))
	var before_extend := Time.get_ticks_msec()
	server._extend_unauthenticated_peer_deadline(91)
	assert(int(server.unauthenticated_peer_deadlines[91]) >= before_extend + 5000)
	server._accept_consumed_join(92, "joined-room", 1)
	assert(server.peer_rooms[92] == "joined-room")
	assert((server.sessions["joined-room"] as MatchSession).peer_slots[92] == 1)
	assert(server._room_status_retry_delay_msec(1) == 500)
	assert(server._room_status_retry_delay_msec(2) == 1000)
	assert(server._room_status_retry_delay_msec(6) == 10000)
	assert(server._should_retry_room_status(-1, 0))
	assert(server._should_retry_room_status(HTTPRequest.RESULT_SUCCESS, 503))
	assert(server._should_retry_room_status(HTTPRequest.RESULT_SUCCESS, 429))
	assert(not server._should_retry_room_status(HTTPRequest.RESULT_SUCCESS, 409))
	server.room_status_queue = [
		{"room_id": "delayed", "retry_after_msec": 1000},
		{"room_id": "ready", "retry_after_msec": 0},
		{"room_id": "delayed", "retry_after_msec": 0},
	]
	assert(server._next_ready_room_status_index(500) == 1)
	assert(server._next_ready_room_status_index(1000) == 0)
	server.free()


func _test_state_and_normal_attack() -> void:
	var simulation := MatchSimulation.new()
	assert(int(simulation.state["players"][1]["normal_damage"]) == 5)
	assert(int(simulation.state["players"][2]["normal_damage"]) == 2)
	simulation.configure_loadout(2, 2, "")
	assert(int(simulation.state["players"][2]["normal_damage"]) == 3)
	simulation.configure_loadout(2, 1, "")
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
	assert(int(simulation.state["players"][2]["hp"]) == 95)
	assert(not simulation.handle_event(1, {"type": "attack"}))


func _test_display_name_loadout_validation() -> void:
	var golden_time_ii_session := MatchSession.new("golden-time-ii-loadout")
	assert(golden_time_ii_session.join(11, 1) == 1)
	var golden_time_ii_payload := {"character": 0, "big_skill": "typist_golden_time_ii", "display_name": "GoldenTimeII"}
	assert(MatchProtocol.valid_event(MatchProtocol.make_event(1, "loadout", golden_time_ii_payload), -1))
	assert(golden_time_ii_session.submit_event(11, MatchProtocol.make_event(1, "loadout", golden_time_ii_payload)))
	assert(str(golden_time_ii_session.simulation.state["players"][1]["big_skill_id"]) == "typist_golden_time_ii")

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
	assert(MatchProtocol.valid_event(MatchProtocol.make_event(2, "loadout", {"character": 2, "big_skill": "typist_trident", "small_skill": 1, "skill3": 0, "display_name": "詠唱士"}), -1))
	assert(MatchProtocol.valid_event(MatchProtocol.make_event(2, "loadout", {"character": 2, "big_skill": "chanter_meteor_shower", "small_skill": 0, "skill3": 0, "display_name": "流月雨"}), -1))
	assert(simulation.handle_event(1, {"type": "loadout", "payload": {"character": 2, "big_skill": "typist_trident", "small_skill": 1, "skill3": 0, "display_name": "詠唱士"}}))
	assert(str(simulation.state["players"][1]["small_skill_id"]) == "chanter_small_1")
	assert(str(simulation.state["players"][1]["skill3_id"]) == "chanter_skill3_0")

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
	var trident_shockwave_projectiles := 0
	for projectile in big_simulation.state["skill_projectiles"]:
		if bool(projectile.get("typist_hammer_shockwave", false)):
			trident_shockwave_projectiles += 1
	assert(trident_shockwave_projectiles == 5)
	var skill3_simulation := MatchSimulation.new()
	assert(skill3_simulation.handle_event(1, {"type": "skill3"}))
	_complete_typing(skill3_simulation, 1)
	assert(not skill3_simulation.state["hammer_spins"].is_empty())
	assert(int(skill3_simulation.state["hammer_spins"][0]["presentation_id"]) > 0)
	var golden_time_simulation := MatchSimulation.new()
	golden_time_simulation.configure_loadout(1, 0, "typist_trident", "", 1, 0)
	assert(golden_time_simulation.handle_event(1, {"type": "small_skill"}))
	_complete_typing(golden_time_simulation, 1)
	var golden_time_snapshot := MatchProtocol.snapshot("golden-time-aura", golden_time_simulation.state, "match", "", 1)
	assert(int(golden_time_snapshot["players"][1]["typing_zone_level"]) == 1)
	assert(float(golden_time_snapshot["players"][1]["typing_zone_time"]) > 0.0)


func _test_typist_hammer_shockwave_hitbox() -> void:
	var opaque_pixels := TypistHammerShockwaveHitboxData.opaque_pixel_centers()
	assert(not opaque_pixels.is_empty())
	var projectile := {"position": Vector2(320.0, 240.0), "velocity": Vector2.LEFT * 300.0}
	var opaque_world_position := TypistHammerShockwaveHitboxData.source_pixel_to_world_position(projectile, opaque_pixels[0])
	assert(TypistHammerShockwaveHitboxData.intersects_ellipse(projectile, opaque_world_position, 0.2, 0.2))
	var transparent_corner_position := TypistHammerShockwaveHitboxData.source_pixel_to_world_position(projectile, Vector2(0.5, 0.5))
	assert(not TypistHammerShockwaveHitboxData.intersects_ellipse(projectile, transparent_corner_position, 0.2, 0.2))
	var simulation := MatchSimulation.new()
	simulation.state["players"][2]["position"] = opaque_world_position - Vector2(0.0, -12.0)
	assert(simulation.call("_typist_hammer_shockwave_projectile_hits_player", projectile, 2))
	simulation.state["players"][2]["position"] = transparent_corner_position - Vector2(0.0, -12.0)
	assert(not simulation.call("_typist_hammer_shockwave_projectile_hits_player", projectile, 2))
	var upward_projectile := projectile.duplicate()
	upward_projectile["velocity"] = Vector2.UP * 300.0
	var upward_opaque_world_position := TypistHammerShockwaveHitboxData.source_pixel_to_world_position(upward_projectile, opaque_pixels[0])
	assert(TypistHammerShockwaveHitboxData.intersects_ellipse(upward_projectile, upward_opaque_world_position, 0.2, 0.2))


func _test_arithmetician_interference_points() -> void:
	var owner_attack_simulation := MatchSimulation.new()
	owner_attack_simulation.configure_loadout(1, 1, "", "", 0, 0)
	owner_attack_simulation.state["players"][1]["position"] = Vector2(100, 100)
	owner_attack_simulation.state["players"][1]["facing"] = Vector2.RIGHT
	owner_attack_simulation.state["players"][2]["position"] = Vector2(1200, 100)
	owner_attack_simulation.state["decoys"] = [{"owner_id": 1, "position": Vector2(180, 100)}]
	assert(owner_attack_simulation.handle_event(1, {"type": "attack"}))
	assert(owner_attack_simulation.state["decoys"].size() == 1)
	assert(is_equal_approx(float(owner_attack_simulation.state["players"][1]["arithmetic_interference_multiplier"]), 1.0))
	owner_attack_simulation._destroy_decoy_at_point(1, Vector2(180, 100))
	assert(owner_attack_simulation.state["decoys"].size() == 1)
	owner_attack_simulation._destroy_decoy_at_point(2, Vector2(180, 100))
	assert(owner_attack_simulation.state["decoys"].is_empty())
	assert(owner_attack_simulation.state["arithmetic_point_collections"].size() == 1)
	assert(is_equal_approx(float(owner_attack_simulation.state["arithmetic_point_collections"][0]["amount"]), 0.1))
	assert(is_equal_approx(float(owner_attack_simulation.state["players"][1]["arithmetic_interference_multiplier"]), 1.0))
	owner_attack_simulation.step(0.99, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(owner_attack_simulation.state["arithmetic_point_collections"].size() == 1)
	assert(is_equal_approx(float(owner_attack_simulation.state["players"][1]["arithmetic_interference_multiplier"]), 1.0))
	owner_attack_simulation.state["decoys"] = [{"owner_id": 1, "position": Vector2(180, 100)}]
	owner_attack_simulation._destroy_decoy_at_point(2, Vector2(180, 100))
	assert(owner_attack_simulation.state["arithmetic_point_collections"].size() == 2)
	owner_attack_simulation.step(0.21, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(owner_attack_simulation.state["arithmetic_point_collections"].size() == 1)
	assert(float(owner_attack_simulation.state["arithmetic_point_collections"][0]["wait_time"]) > 0.7)
	assert(is_equal_approx(float(owner_attack_simulation.state["players"][1]["arithmetic_interference_multiplier"]), 1.1))
	owner_attack_simulation.state["arithmetic_point_collections"].clear()

	owner_attack_simulation.state["decoys"] = [{"owner_id": 1, "position": Vector2(180, 100)}]
	owner_attack_simulation._destroy_decoys_in_radius(1, Vector2(180, 100), 10.0)
	assert(owner_attack_simulation.state["decoys"].size() == 1)
	owner_attack_simulation._destroy_decoys_in_radius(2, Vector2(180, 100), 10.0)
	assert(owner_attack_simulation.state["decoys"].is_empty())
	assert(owner_attack_simulation.state["arithmetic_point_collections"].size() == 1)
	owner_attack_simulation.state["arithmetic_point_collections"].clear()

	owner_attack_simulation.state["decoys"] = [{"owner_id": 1, "position": Vector2(180, 100)}]
	owner_attack_simulation._destroy_decoys_near_segment(1, Vector2(100, 100), Vector2(200, 100), 10.0)
	assert(owner_attack_simulation.state["decoys"].size() == 1)
	owner_attack_simulation._destroy_decoys_near_segment(2, Vector2(100, 100), Vector2(200, 100), 10.0)
	assert(owner_attack_simulation.state["decoys"].is_empty())
	assert(owner_attack_simulation.state["arithmetic_point_collections"].size() == 1)
	owner_attack_simulation.state["arithmetic_point_collections"].clear()

	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 1, "", "", 0, 0)
	simulation.state["players"][1]["position"] = Vector2(100, 100)
	simulation.state["players"][2]["position"] = Vector2(30, 100)
	simulation.state["players"][2]["facing"] = Vector2.RIGHT
	simulation.state["decoys"] = [{"owner_id": 1, "position": Vector2(100, 100)}]
	assert(simulation.handle_event(2, {"type": "attack"}))
	assert(simulation.state["decoys"].is_empty())
	assert(simulation.state["arithmetic_point_collections"].size() == 1)
	assert(is_equal_approx(float(simulation.state["players"][1]["arithmetic_interference_multiplier"]), 1.0))

	simulation.state["players"][1]["arithmetic_interference_multiplier"] = 1.5
	simulation.state["players"][1]["position"] = Vector2(100, 100)
	simulation.state["players"][1]["facing"] = Vector2.RIGHT
	simulation.state["players"][1]["attack_cooldown"] = 0.0
	simulation.state["players"][2]["position"] = Vector2(180, 100)
	simulation.state["players"][2]["hp"] = 100
	assert(simulation.handle_event(1, {"type": "attack"}))
	assert(int(simulation.state["players"][2]["hp"]) == 97)
	assert(is_equal_approx(float(simulation.state["players"][1]["attack_cooldown"]), 3.0 / 1.5))

	simulation.state["players"][1]["arithmetic_interference_multiplier"] = 2.0
	simulation.state["players"][1]["position"] = Vector2(100, 100)
	simulation.state["players"][2]["position"] = Vector2(1200, 100)
	simulation.step(1.0, {1: {"move": Vector2.RIGHT}, 2: {"move": Vector2.ZERO}})
	assert(is_equal_approx(float(simulation.state["players"][1]["position"].x), 408.0))

func _test_arithmetician_skills() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 1, "typist_trident")
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	_complete_arithmetic(simulation, 1)
	assert(simulation.state["decoys"].size() == 80)
	assert(is_equal_approx(float(simulation.state["players"][1]["small_cooldown"]), 2.0))
	assert(is_equal_approx(float(simulation.state["players"][1]["buff_time"]), 40.0))
	assert(is_equal_approx(float(simulation.state["players"][1]["buff_speed_multiplier"]), 1.1))
	assert(int(simulation.state["players"][1]["attack_damage_buff"]) == 5)
	assert(simulation.state["arithmetic_flashes"].size() == 1)
	simulation._destroy_decoy_at_point(2, Vector2(simulation.state["decoys"][0]["position"]))
	assert(is_equal_approx(float(simulation.state["players"][1]["arithmetic_interference_multiplier"]), 1.0))
	assert(simulation.state["arithmetic_point_collections"].size() == 1)
	var flash_snapshot := MatchProtocol.snapshot("arithmetician-test", simulation.state, "match", "", 1)
	assert(flash_snapshot["arithmetic_flashes"].size() == 1)
	assert(flash_snapshot["arithmetic_point_collections"].size() == 1)
	assert(is_equal_approx(float(flash_snapshot["arithmetic_point_collections"][0]["amount"]), 0.1))
	assert(is_equal_approx(float(flash_snapshot["players"][1]["arithmetic_interference_multiplier"]), 1.0))

	simulation.state["players"][1]["arithmetic_interference_multiplier"] = 1.0
	simulation.state["arithmetic_point_collections"].clear()
	for expected in [[0, 10, 20.0, Vector2(10.0, 500.0)], [59, 19, 20.0, Vector2(10.0, 500.0)], [60, 20, 30.0, Vector2(20.0, 700.0)], [69, 29, 30.0, Vector2(20.0, 700.0)], [70, 30, 30.0, Vector2(20.0, 700.0)], [79, 39, 30.0, Vector2(20.0, 700.0)], [80, 45, 40.0, Vector2(20.0, 1000.0)], [89, 54, 40.0, Vector2(20.0, 1000.0)], [90, 70, 40.0, Vector2(20.0, 1000.0)], [100, 80, 40.0, Vector2(20.0, 1000.0)]]:
		simulation.state["players"][1]["position"] = Vector2(840, 387)
		simulation._spawn_decoys(1, int(expected[0]))
		assert(simulation.state["decoys"].size() == int(expected[1]))
		for decoy in simulation.state["decoys"]:
			var offset := Vector2(decoy["position"]) - Vector2(840, 387)
			assert(offset.length() >= Vector2(expected[3]).x - 0.01)
			assert(offset.length() <= Vector2(expected[3]).y + 0.01)
			assert(is_equal_approx(float(decoy["lifetime"]), float(expected[2])))
			assert(float(decoy["noise_timer"]) >= 5.0 and float(decoy["noise_timer"]) <= 10.0)

	simulation._spawn_decoys(1, 60)
	var first_decoy: Dictionary = simulation.state["decoys"][0]
	var first_position := Vector2(first_decoy["position"])
	var offset_angle := float(first_decoy["movement_offset_angle"])
	first_decoy["noise_timer"] = 0.01
	simulation.state["decoys"][0] = first_decoy
	simulation.step(0.02, {1: {"move": Vector2.RIGHT}, 2: {"move": Vector2.ZERO}})
	first_decoy = simulation.state["decoys"][0]
	assert(bool(first_decoy["is_moving"]))
	assert(Vector2(first_decoy["facing"]).is_equal_approx(Vector2.RIGHT.rotated(offset_angle)))
	assert(Vector2(first_decoy["position"]).is_equal_approx(simulation._clamp_to_arena(first_position + Vector2.RIGHT.rotated(offset_angle) * 6.16)))
	assert(float(first_decoy["noise_time"]) > 0.0)
	var big_simulation := MatchSimulation.new()
	big_simulation.configure_loadout(1, 1, "typist_trident")
	assert(big_simulation.handle_event(1, {"type": "big_skill"}))
	_complete_arithmetic(big_simulation, 1)
	assert(is_equal_approx(float(big_simulation.state["players"][1]["big_cooldown"]), 15.0))
	assert(is_equal_approx(float(big_simulation.state["players"][1]["invisible_time"]), 20.0))
	assert(is_equal_approx(float(big_simulation.state["players"][1]["buff_speed_multiplier"]), 1.25))
	assert(int(big_simulation.state["players"][1]["attack_damage_buff"]) == 1)
	big_simulation.step(0.01, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(float(big_simulation.state["players"][1]["invisible_flicker"]) > 2.5 - (1.0 / 60.0))
	big_simulation.step(2.3, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(float(big_simulation.state["players"][1]["invisible_flicker"]) < 2.5 - (1.0 / 60.0))
	big_simulation.step(0.21, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(float(big_simulation.state["players"][1]["invisible_flicker"]) > 2.5 - (1.0 / 60.0))
	big_simulation._spawn_skill(1, 0, {"tier": "big"})
	assert(is_equal_approx(float(big_simulation.state["players"][1]["invisible_time"]), 10.0))

	var skill3_simulation := MatchSimulation.new()
	skill3_simulation.configure_loadout(1, 1, "typist_trident", "", 0, 0)
	assert(str(skill3_simulation.state["players"][1]["skill3_id"]) == "arithmetic_hack_vision")
	assert(skill3_simulation.handle_event(1, {"type": "skill3"}))
	assert(str(skill3_simulation.state["challenges"][1]["skill"]) == "skill3_arithmetic_hack_vision")
	var hack_vision_expression := str(skill3_simulation.state["challenges"][1]["prompt"]).trim_suffix(" = ?")
	var hack_vision_candidates := PackedStringArray(["33 * 44 + 16 * 6 + 29", "28 * 47 + 15 * 7 + 34", "36 * 42 + 18 * 5 + 27", "31 * 46 + 14 * 8 + 25", "27 * 53 + 17 * 6 + 32", "34 * 41 + 19 * 5 + 28", "29 * 48 + 16 * 7 + 31", "37 * 39 + 13 * 8 + 26", "32 * 45 + 17 * 6 + 35"])
	assert(hack_vision_expression in hack_vision_candidates)
	assert(str(skill3_simulation.state["challenges"][1]["answer"]) == str(skill3_simulation._evaluate_arithmetic(hack_vision_expression)))
	assert(is_equal_approx(float(skill3_simulation.state["challenges"][1]["limit"]), 15.0))
	_complete_arithmetic(skill3_simulation, 1)
	assert(skill3_simulation.state["skill_projectiles"].size() == 1)
	assert(bool(skill3_simulation.state["skill_projectiles"][0]["hack_vision"]))
	assert(is_equal_approx(float(skill3_simulation.state["players"][1]["skill3_cooldown"]), 12.0))
	for tick in 70:
		skill3_simulation.step(0.05, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(float(skill3_simulation.state["players"][2]["hack_vision_time"]) > 89.0)
	assert(int(skill3_simulation.state["players"][2]["hack_vision_owner_id"]) == 1)
	assert(skill3_simulation.handle_event(2, {"type": "attack"}))
	assert(skill3_simulation.state["arithmetic_point_collections"].size() == 1)
	assert(is_equal_approx(float(skill3_simulation.state["arithmetic_point_collections"][0]["amount"]), 0.5))
	skill3_simulation.state["arithmetic_point_collections"].clear()
	skill3_simulation.state["players"][2]["attack_cooldown"] = 0.0
	skill3_simulation.state["players"][1]["position"] = Vector2(100, 100)
	skill3_simulation.state["players"][2]["position"] = Vector2(180, 100)
	skill3_simulation.state["players"][2]["facing"] = Vector2.LEFT
	assert(skill3_simulation.handle_event(2, {"type": "attack"}))
	assert(skill3_simulation.state["arithmetic_point_collections"].is_empty())
	skill3_simulation.state["players"][2]["attack_cooldown"] = 0.0
	skill3_simulation.state["players"][2]["hack_vision_time"] = 0.0
	assert(skill3_simulation.handle_event(2, {"type": "attack"}))
	assert(skill3_simulation.state["arithmetic_point_collections"].is_empty())
	var hack_snapshot := MatchProtocol.snapshot("arithmetician-skill3", skill3_simulation.state, "match", "", 2)
	assert(int(hack_snapshot["players"][2]["hack_vision_owner_id"]) == 1)

	var unavailable_skill3_simulation := MatchSimulation.new()
	unavailable_skill3_simulation.configure_loadout(1, 1, "typist_trident", "", 0, 1)
	assert(str(unavailable_skill3_simulation.state["players"][1]["skill3_id"]).is_empty())
	assert(not unavailable_skill3_simulation.handle_event(1, {"type": "skill3"}))


func _test_hack_vision_full_homing() -> void:
	var simulation := MatchSimulation.new()
	simulation.state["players"][1]["position"] = Vector2(100, 100)
	simulation.state["players"][2]["position"] = Vector2(400, 100)
	simulation._spawn_hack_vision_projectile(1, 100)
	assert(is_equal_approx(float(simulation.state["skill_projectiles"][0]["lifetime"]), 5.0))

	# Move the target perpendicular to the launch direction. The next update must
	# immediately align the Hack Vision projectile with that new direction.
	simulation.state["players"][2]["position"] = Vector2(140, 700)
	simulation._update_projectiles(0.1)
	var projectile: Dictionary = simulation.state["skill_projectiles"][0]
	assert(Vector2(projectile["velocity"]).normalized().is_equal_approx(Vector2.DOWN))
	assert(is_equal_approx(float(projectile["lifetime"]), 4.9))


func _test_arithmetician_perfect_mapping() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 1, "arithmetic_perfect_mapping")
	simulation.configure_loadout(2, 1, "arithmetic_perfect_mapping")
	assert(str(simulation.state["players"][1]["big_skill_id"]) == "arithmetic_perfect_mapping")
	assert(simulation.handle_event(1, {"type": "big_skill"}))
	var challenge: Dictionary = simulation.state["challenges"][1]
	assert(str(challenge["skill"]) == "big_arithmetic_perfect_mapping")
	assert(is_equal_approx(float(challenge["limit"]), 12.0))
	assert(str(challenge["prompt"]).trim_suffix(" = ?") in MatchSimulation.ARITH_PERFECT_MAPPING)
	_complete_arithmetic(simulation, 1)
	assert(is_equal_approx(float(simulation.state["players"][1]["big_cooldown"]), 10.0))
	assert(simulation.state["perfect_mapping_effects"].size() == 1)
	assert(str(simulation.state["perfect_mapping_effects"][0]["copied_skill"]) != "arithmetic_perfect_mapping")
	var mapping_snapshot := MatchProtocol.snapshot("perfect-mapping", simulation.state, "match", "", 1)
	assert(mapping_snapshot["perfect_mapping_effects"].size() == 1)
	simulation.step(1.21, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(simulation.state["perfect_mapping_effects"].is_empty())

	var golden_time_target_simulation := MatchSimulation.new()
	golden_time_target_simulation.configure_loadout(1, 1, "arithmetic_perfect_mapping")
	golden_time_target_simulation.configure_loadout(2, 0, "typist_golden_time_ii", "", 1, 1)
	assert(golden_time_target_simulation._perfect_mapping_copy_candidates(1).is_empty())
	for golden_time_skill in ["typist_golden_time_i", "typist_golden_time_ii", "typist_golden_time_iii"]:
		assert(not golden_time_target_simulation._is_perfect_mapping_copyable(golden_time_skill))
	golden_time_target_simulation.state["status_text"] = "unchanged"
	golden_time_target_simulation._spawn_perfect_mapping(1, 80)
	assert(golden_time_target_simulation.state["perfect_mapping_effects"].size() == 1)
	var no_selection_effect: Dictionary = golden_time_target_simulation.state["perfect_mapping_effects"][0]
	assert(bool(no_selection_effect["no_selection"]))
	assert(int(no_selection_effect["tile_count"]) == 0)
	assert(str(golden_time_target_simulation.state["status_text"]) == "unchanged")
	var no_selection_snapshot := MatchProtocol.snapshot("perfect-mapping-none", golden_time_target_simulation.state, "match", "", 1)
	assert(bool(no_selection_snapshot["perfect_mapping_effects"][0]["no_selection"]))
	golden_time_target_simulation._update_perfect_mapping_effects(1.21)
	assert(golden_time_target_simulation.state["perfect_mapping_effects"].is_empty())
	assert(golden_time_target_simulation.state["skill_projectiles"].is_empty())
	assert(golden_time_target_simulation.state["magic_zones"].is_empty())

	var no_point_simulation := MatchSimulation.new()
	no_point_simulation.configure_loadout(1, 1, "arithmetic_perfect_mapping")
	no_point_simulation._spawn_copied_skill(1, 80, "arithmetic_small_0")
	assert(not no_point_simulation.state["decoys"].is_empty())
	no_point_simulation._destroy_decoy_at_point(2, Vector2(no_point_simulation.state["decoys"][0]["position"]))
	assert(no_point_simulation.state["arithmetic_point_collections"].is_empty())

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
	assert(big_simulation.state["skill_projectiles"].size() == 128)
	assert(is_equal_approx(float(big_simulation.state["players"][1]["big_cooldown"]), 6.0))
	# The clockwise and counter-clockwise sequences start together at the top
	# and bottom respectively.
	big_simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var clockwise_projectile: Dictionary = big_simulation.state["skill_projectiles"][0]
	var counterclockwise_projectile: Dictionary = big_simulation.state["skill_projectiles"][1]
	assert(Vector2(clockwise_projectile["velocity"]).normalized().is_equal_approx(Vector2.UP))
	assert(Vector2(counterclockwise_projectile["velocity"]).normalized().is_equal_approx(Vector2.DOWN))


func _test_chanter_skill2_specification() -> void:
	for score_and_cycles in [[30, 1], [50, 2], [75, 3], [76, 4]]:
		var simulation := MatchSimulation.new()
		simulation.configure_loadout(1, 2, "typist_trident")
		simulation._spawn_skill(1, int(score_and_cycles[0]), {"tier": "big"})
		assert(simulation.state["skill_projectiles"].size() == int(score_and_cycles[1]) * 32)
		var first_projectile: Dictionary = simulation.state["skill_projectiles"][0]
		var reverse_projectile: Dictionary = simulation.state["skill_projectiles"][1]
		assert(Vector2(first_projectile["velocity"]).normalized().is_equal_approx(Vector2.UP))
		assert(Vector2(reverse_projectile["velocity"]).normalized().is_equal_approx(Vector2.DOWN))
		assert(is_equal_approx(float(first_projectile["delay"]), float(reverse_projectile["delay"])))
		assert(int(first_projectile["damage"]) == 3 + floori(float(score_and_cycles[0]) * 0.05))

	var moving_simulation := MatchSimulation.new()
	moving_simulation.configure_loadout(1, 2, "typist_trident")
	moving_simulation._spawn_skill(1, 30, {"tier": "big"})
	var second_projectile: Dictionary = moving_simulation.state["skill_projectiles"][2]
	var initial_velocity := Vector2(second_projectile["velocity"])
	moving_simulation.step(0.08, {1: {"move": Vector2.DOWN}, 2: {"move": Vector2.ZERO}})
	second_projectile = moving_simulation.state["skill_projectiles"][2]
	var owner_position := Vector2(moving_simulation.state["players"][1]["position"])
	var expected_launch_position := owner_position + initial_velocity.normalized() * (30.0 + 10.0)
	assert(Vector2(second_projectile["velocity"]).is_equal_approx(initial_velocity))
	assert(Vector2(second_projectile["position"]).is_equal_approx(expected_launch_position + initial_velocity * 0.08))
	assert(bool(second_projectile["launched"]))

	var trace_target := moving_simulation._make_trace_target("big")
	assert(trace_target.size() == 121)
	assert(is_equal_approx(trace_target[0].distance_to(Vector2(340, 118)), 10.0))
	assert(is_equal_approx(trace_target[-1].distance_to(Vector2(340, 118)), 108.0))


func _test_chanter_meteor_shower() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 2, "chanter_meteor_shower")
	simulation.state["players"][1]["position"] = Vector2(200, 387)
	simulation.state["players"][2]["position"] = Vector2(600, 387)
	assert(str(simulation.state["players"][1]["big_skill_id"]) == "chanter_big_1")
	assert(simulation.handle_event(1, {"type": "big_skill"}))
	assert(str(simulation.state["challenges"][1]["skill"]) == "big_trace_meteor_shower")
	assert(str(simulation.state["challenges"][1]["prompt"]) == "複合紋章をなぞってください")
	simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var target: PackedVector2Array = simulation.state["challenges"][1]["target"]
	assert(target.size() > 121)
	assert(target[0].is_equal_approx(Vector2(340, 10)))
	assert(simulation.handle_event(1, {"type": "challenge_trace", "payload": target}))
	assert(simulation.state["meteor_impacts"].size() == 20)
	assert(is_equal_approx(float(simulation.state["meteor_impacts"][0]["delay"]), 0.0))
	assert(is_equal_approx(float(simulation.state["meteor_impacts"][1]["delay"]), 0.0))
	assert(is_equal_approx(float(simulation.state["meteor_impacts"][2]["delay"]), 0.65))
	assert(is_equal_approx(float(simulation.state["players"][1]["big_cooldown"]), 8.0))
	for impact_index in simulation.state["meteor_impacts"].size():
		assert(Vector2(simulation.state["meteor_impacts"][impact_index]["position"]).distance_to(Vector2(simulation.state["players"][1]["position"])) > 120.0)
	var landing_impact: Dictionary = simulation.state["meteor_impacts"][0]
	landing_impact["position"] = Vector2(simulation.state["players"][2]["position"])
	simulation.state["meteor_impacts"][0] = landing_impact
	var other_impact: Dictionary = simulation.state["meteor_impacts"][1]
	other_impact["position"] = Vector2(100, 100)
	simulation.state["meteor_impacts"][1] = other_impact
	var snapshot := MatchProtocol.snapshot("meteor-shower", simulation.state, "match", "", 1)
	assert(snapshot["meteor_impacts"].size() == 20)
	simulation.step(1.99, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(int(simulation.state["players"][2]["hp"]) == 100)
	simulation.step(0.02, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(int(simulation.state["players"][2]["hp"]) == 88)
	assert(int(simulation.state["players"][1]["hp"]) == 100)


func _test_chanter_skill1_candidate_and_skill3() -> void:
	var skill1_simulation := MatchSimulation.new()
	skill1_simulation.configure_loadout(1, 2, "typist_trident", "", 1, 0)
	assert(str(skill1_simulation.state["players"][1]["small_skill_id"]) == "chanter_small_1")
	assert(skill1_simulation.handle_event(1, {"type": "small_skill"}))
	skill1_simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var skill1_target: PackedVector2Array = skill1_simulation.state["challenges"][1]["target"]
	assert(skill1_target.size() == 121)
	assert(skill1_simulation.handle_event(1, {"type": "challenge_trace", "payload": skill1_target}))
	assert(skill1_simulation.state["skill_projectiles"].size() == 64)
	assert(is_equal_approx(float(skill1_simulation.state["players"][1]["small_cooldown"]), 3.0))
	assert(Vector2(skill1_simulation.state["skill_projectiles"][0]["velocity"]).normalized().is_equal_approx(Vector2.UP))

	var skill3_simulation := MatchSimulation.new()
	skill3_simulation.configure_loadout(1, 2, "typist_trident", "", 0, 0)
	assert(str(skill3_simulation.state["players"][1]["skill3_id"]) == "chanter_skill3_0")
	assert(skill3_simulation.handle_event(1, {"type": "skill3"}))
	skill3_simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var skill3_target: PackedVector2Array = skill3_simulation.state["challenges"][1]["target"]
	assert(skill3_target.size() == 121)
	assert(skill3_simulation.handle_event(1, {"type": "challenge_trace", "payload": skill3_target}))
	assert(skill3_simulation.state["skill_projectiles"].size() == 256)
	assert(is_equal_approx(float(skill3_simulation.state["players"][1]["skill3_cooldown"]), 8.0))
	var top: Dictionary = skill3_simulation.state["skill_projectiles"][0]
	var bottom: Dictionary = skill3_simulation.state["skill_projectiles"][1]
	var right: Dictionary = skill3_simulation.state["skill_projectiles"][2]
	var left: Dictionary = skill3_simulation.state["skill_projectiles"][3]
	assert(Vector2(top["velocity"]).normalized().is_equal_approx(Vector2.UP))
	assert(Vector2(bottom["velocity"]).normalized().is_equal_approx(Vector2.DOWN))
	assert(Vector2(right["velocity"]).normalized().is_equal_approx(Vector2.RIGHT))
	assert(Vector2(left["velocity"]).normalized().is_equal_approx(Vector2.LEFT))
	assert(is_equal_approx(float(top["delay"]), float(bottom["delay"])))
	assert(is_equal_approx(float(top["delay"]), float(right["delay"])))
	assert(is_equal_approx(float(top["delay"]), float(left["delay"])))
	var piercing_simulation := MatchSimulation.new()
	piercing_simulation.configure_loadout(1, 2, "typist_trident")
	piercing_simulation.state["players"][1]["position"] = Vector2(100, 100)
	piercing_simulation.state["players"][2]["position"] = Vector2(150, 100)
	piercing_simulation.state["skill_projectiles"] = [{"projectile_id": 1, "owner_id": 1, "position": Vector2(150, 100), "velocity": Vector2.ZERO, "damage": 8, "lifetime": 1.0, "piercing": true, "delay": 0.0, "launched": true, "homing": false, "homing_time": 0.0}]
	piercing_simulation._update_projectiles(0.1)
	assert(int(piercing_simulation.state["players"][2]["hp"]) == 92)
	assert(bool(piercing_simulation.state["skill_projectiles"][0]["hit_target"]))
	piercing_simulation._update_projectiles(0.1)
	assert(int(piercing_simulation.state["players"][2]["hp"]) == 92)
	assert(piercing_simulation.state["skill_projectiles"].size() == 1)

	var lunar_eclipse_simulation := MatchSimulation.new()
	lunar_eclipse_simulation.configure_loadout(1, 2, "typist_trident", "", 0, 1)
	assert(str(lunar_eclipse_simulation.state["players"][1]["skill3_id"]) == "chanter_lunar_eclipse")
	assert(lunar_eclipse_simulation.handle_event(1, {"type": "skill3"}))
	lunar_eclipse_simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(str(lunar_eclipse_simulation.state["challenges"][1]["skill"]) == "skill3_trace_lunar_eclipse")
	var lunar_target: PackedVector2Array = lunar_eclipse_simulation.state["challenges"][1]["target"]
	assert(lunar_target.size() == 121)
	assert(lunar_eclipse_simulation.handle_event(1, {"type": "challenge_trace", "payload": lunar_target}))
	assert(lunar_eclipse_simulation.state["lunar_eclipses"].size() == 1)
	assert(is_equal_approx(float(lunar_eclipse_simulation.state["players"][1]["skill3_cooldown"]), 10.0))


func _test_lunar_eclipse_rules() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 2, "typist_trident", "", 0, 1)
	simulation.state["players"][2]["position"] = Vector2(420, MatchSimulation.ARENA.get_center().y)
	assert(simulation.handle_event(1, {"type": "skill3"}))
	simulation.step(0.4, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	var target: PackedVector2Array = simulation.state["challenges"][1]["target"]
	assert(simulation.handle_event(1, {"type": "challenge_trace", "payload": target}))
	var eclipse: Dictionary = simulation.state["lunar_eclipses"][0]
	assert(Vector2(eclipse["origin"]).is_equal_approx(Vector2(200, MatchSimulation.ARENA.get_center().y)))
	assert(Vector2(eclipse["center"]).is_equal_approx(Vector2(500, MatchSimulation.ARENA.get_center().y)))
	assert(is_equal_approx(float(eclipse["duration"]), 4.5))
	assert(is_equal_approx(float(eclipse["next_laser_hit_time"]), 2.0))
	assert(Vector2(simulation.call("_lunar_eclipse_center", Vector2(1600, 400), Vector2.RIGHT)).is_equal_approx(Vector2(MatchSimulation.ARENA.end.x, 400)))
	assert(is_equal_approx(float(simulation.call("_distance_to_arena_boundary", Vector2(230, MatchSimulation.ARENA.get_center().y), Vector2.RIGHT)), 1450.0))
	var owner_position := Vector2(simulation.state["players"][1]["position"])
	assert(not simulation.handle_event(1, {"type": "attack"}))
	assert(not simulation.handle_event(1, {"type": "small_skill"}))
	simulation.step(0.5, {1: {"move": Vector2.DOWN}, 2: {"move": Vector2.ZERO}})
	assert(Vector2(simulation.state["players"][1]["position"]).is_equal_approx(owner_position))
	assert(int(simulation.state["players"][2]["hp"]) == 100)
	simulation.step(0.5, {1: {"move": Vector2.DOWN}, 2: {"move": Vector2.ZERO}})
	assert(Vector2(simulation.state["players"][2]["position"]).is_equal_approx(Vector2(eclipse["center"])))
	assert(int(simulation.state["players"][2]["hp"]) == 100)
	var damage := 4 + floori(100.0 * 0.13)
	simulation.step(1.0, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(int(simulation.state["players"][2]["hp"]) == 100 - damage)
	simulation.step(2.0, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(int(simulation.state["players"][2]["hp"]) == 100 - damage * 3)
	simulation.step(0.5, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(simulation.state["lunar_eclipses"].is_empty())

	var boundary_simulation := MatchSimulation.new()
	boundary_simulation.configure_loadout(1, 2, "typist_trident", "", 0, 1)
	boundary_simulation.call("_spawn_lunar_eclipse", 1, 45)
	var boundary_eclipse: Dictionary = boundary_simulation.state["lunar_eclipses"][0]
	assert(is_equal_approx(float(boundary_eclipse["visual_radius"]), 204.0))
	assert(is_equal_approx(float(boundary_eclipse["pull_amount"]), 13.0))
	assert(int(boundary_eclipse["damage"]) == 9)
	var pull_center := Vector2(boundary_eclipse["center"])
	var near_position := pull_center + Vector2(100, 0)
	var boundary_target: Dictionary = boundary_simulation.state["players"][2]
	boundary_target["position"] = near_position
	boundary_simulation.state["players"][2] = boundary_target
	boundary_simulation.call("_pull_lunar_eclipse_target", 2, pull_center, 13.0)
	var near_pull_distance := near_position.distance_to(Vector2(boundary_simulation.state["players"][2]["position"]))
	var far_position := Vector2(MatchSimulation.ARENA.end.x - MatchSimulation.PLAYER_RADIUS, MatchSimulation.ARENA.end.y - MatchSimulation.PLAYER_RADIUS)
	boundary_target = boundary_simulation.state["players"][2]
	boundary_target["position"] = far_position
	boundary_simulation.state["players"][2] = boundary_target
	boundary_simulation.call("_pull_lunar_eclipse_target", 2, pull_center, 13.0)
	var far_pull_distance := far_position.distance_to(Vector2(boundary_simulation.state["players"][2]["position"]))
	assert(far_position.distance_to(pull_center) > float(boundary_eclipse["visual_radius"]))
	assert(far_pull_distance > 0.0 and far_pull_distance <= 1.01)
	assert(near_pull_distance > far_pull_distance)
	var maximum_pull_simulation := MatchSimulation.new()
	maximum_pull_simulation.configure_loadout(1, 2, "typist_trident", "", 0, 1)
	maximum_pull_simulation.call("_spawn_lunar_eclipse", 1, 100)
	var maximum_pull_eclipse: Dictionary = maximum_pull_simulation.state["lunar_eclipses"][0]
	assert(is_equal_approx(float(maximum_pull_eclipse["pull_amount"]), 22.0))
	assert(float(maximum_pull_eclipse["pull_amount"]) * 10.0 < MatchSimulation.PLAYER_SPEED)
	var snapshot := MatchProtocol.snapshot("lunar-eclipse", boundary_simulation.state, "match", "", 1)
	assert(snapshot["lunar_eclipses"].size() == 1)
	assert(int(snapshot["lunar_eclipses"][0]["presentation_id"]) > 0)


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

func _test_damage_does_not_interrupt_focus() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(2, 0, "typist_trident")
	simulation.state["players"][1]["position"] = Vector2(100, 100)
	simulation.state["players"][1]["facing"] = Vector2.RIGHT
	simulation.state["players"][2]["position"] = Vector2(180, 100)
	assert(simulation.handle_event(2, {"type": "small_skill"}))
	for index in 3:
		simulation.handle_event(1, {"type": "attack"})
		simulation.state["players"][1]["attack_cooldown"] = 0.0
	assert(simulation.state["challenges"].has(2))
	assert(bool(simulation.state["players"][2]["focused"]))

func _test_damage_does_not_interrupt_simultaneous_challenges() -> void:
	var simulation := MatchSimulation.new()
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	assert(simulation.handle_event(2, {"type": "small_skill"}))
	assert(simulation.state["challenges"].size() == 2)
	assert(bool(simulation.state["players"][1]["focused"]))
	assert(bool(simulation.state["players"][2]["focused"]))
	simulation.call("_apply_damage", 1, 30, "test")
	assert(simulation.state["challenges"].has(1))
	assert(simulation.state["challenges"].has(2))
	_complete_arithmetic(simulation, 2)
	assert(simulation.state["challenges"].has(1))
	assert(not simulation.state["challenges"].has(2))

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
	assert(not (snapshot["players"][1] as Dictionary).has("interrupt_gauge"))
	assert(is_equal_approx(MatchProtocol.TICK_SECONDS, 1.0 / 60.0))


func _test_chanter_skill3_event_driven_presentation() -> void:
	var simulation := MatchSimulation.new()
	simulation.configure_loadout(1, 2, "typist_trident", "", 0, 0)
	simulation.call("_spawn_chanter_skill3_volley", 1, 100)
	var server_projectiles: Array = simulation.state["skill_projectiles"]
	assert(server_projectiles.size() == 256)
	for projectile in server_projectiles:
		assert(bool(projectile.get("client_predicted", false)))
		assert(int(projectile.get("presentation_id", -1)) == 0)
	var visual_presentations := simulation.take_visual_presentations()
	assert(visual_presentations.size() == 1)
	assert(str(visual_presentations[0]["kind"]) == "chanter_skill3_volley")
	assert(int(visual_presentations[0]["state"]["cycle_count"]) == 4)
	assert(int(visual_presentations[0]["state"]["projectile_count"]) == 256)
	assert((MatchProtocol.snapshot("event-driven-volley", simulation.state, "match", "", 1)["skill_projectiles"] as Array).is_empty())

	var session := MatchSession.new("event-driven-volley")
	session.simulation.configure_loadout(1, 2, "typist_trident", "", 0, 0)
	session.simulation.call("_spawn_chanter_skill3_volley", 1, 75)
	session.call("_collect_presentations")
	var queued_presentations := session.take_presentations()
	assert(queued_presentations.size() == 1)
	assert(str(queued_presentations[0]["kind"]) == "chanter_skill3_volley")
	assert(int(queued_presentations[0]["state"]["cycle_count"]) == 3)
	assert(int(queued_presentations[0]["state"]["projectile_count"]) == 192)

	var capped_simulation := MatchSimulation.new()
	capped_simulation.configure_loadout(1, 2, "typist_trident", "", 0, 0)
	for index in MatchSimulation.MAX_PROJECTILES - 20:
		capped_simulation.state["skill_projectiles"].append({})
	capped_simulation.call("_spawn_chanter_skill3_volley", 1, 100)
	var capped_presentations := capped_simulation.take_visual_presentations()
	assert(capped_simulation.state["skill_projectiles"].size() == MatchSimulation.MAX_PROJECTILES)
	assert(capped_presentations.size() == 1)
	assert(int(capped_presentations[0]["state"]["projectile_count"]) == 20)


func _test_visual_snapshot_interpolation() -> void:
	var previous := {
		"players": {1: {"position": Vector2(0, 0), "facing": Vector2.RIGHT}},
		"skill_projectiles": [{"projectile_id": 7, "owner_id": 1, "position": Vector2(10, 0), "velocity": Vector2.RIGHT, "lifetime": 2.0}],
		"magic_zones": [{"presentation_id": 8, "owner_id": 1, "position": Vector2.ZERO, "spawned": false}],
		"arithmetic_point_collections": [{"presentation_id": 9, "owner_id": 1, "position": Vector2(10, 20), "amount": 0.1, "wait_time": 1.0}],
		"shockwaves": [], "trident_impacts": [], "decoys": [], "hammer_spins": [],
	}
	var current := {
		"players": {1: {"position": Vector2(20, 0), "facing": Vector2.DOWN}},
		"skill_projectiles": [{"projectile_id": 7, "owner_id": 1, "position": Vector2(30, 0), "velocity": Vector2.DOWN, "lifetime": 1.0}],
		"magic_zones": [{"presentation_id": 8, "owner_id": 1, "position": Vector2(600, 400), "spawned": true}],
		"arithmetic_point_collections": [{"presentation_id": 9, "owner_id": 1, "position": Vector2(30, 40), "amount": 0.1, "wait_time": 0.5}],
		"shockwaves": [], "trident_impacts": [], "decoys": [], "hammer_spins": [],
	}
	var blended := MatchProtocol.interpolate_visual_state(previous, current, 0.5)
	assert(Vector2(blended["players"][1]["position"]).is_equal_approx(Vector2(10, 0)))
	assert(Vector2(blended["skill_projectiles"][0]["position"]).is_equal_approx(Vector2(20, 0)))
	assert(Vector2(blended["magic_zones"][0]["position"]).is_equal_approx(Vector2(600, 400)))
	assert(Vector2(blended["arithmetic_point_collections"][0]["position"]).is_equal_approx(Vector2(20, 30)))
	assert(is_equal_approx(float(blended["arithmetic_point_collections"][0]["wait_time"]), 0.75))
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


func _test_session_knockout_finish_phase() -> void:
	var session := MatchSession.new("finish-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
	session.phase = "match"
	session.simulation.call("_apply_damage", 2, 100, "test")
	assert(bool(session.simulation.state["match_over"]))
	assert(int(session.simulation.state["players"][2]["hp"]) == 0)
	session.step(MatchProtocol.TICK_SECONDS)
	assert(session.phase == "finish")
	assert(is_equal_approx(float(session.make_snapshot()["finish_remaining"]), MatchSession.FINISH_DURATION))
	assert(not session.submit_input(11, MatchProtocol.make_input(1, Vector2.RIGHT)))
	assert(not session.submit_event(11, MatchProtocol.make_event(1, "small_skill")))
	session.step(MatchSession.FINISH_DURATION)
	assert(session.phase == "result")
	var timeout_session := MatchSession.new("timeout-room")
	timeout_session.phase = "match"
	timeout_session.simulation.state["time_remaining"] = 0.0
	timeout_session.step(MatchProtocol.TICK_SECONDS)
	assert(timeout_session.phase == "result")


func _test_session_result_actions() -> void:
	var loadout_session := MatchSession.new("loadout-preservation-room")
	loadout_session.simulation.configure_loadout(1, 0, "typist_trident", "Player", 1, 1)
	loadout_session.call("_reset_simulation_preserving_loadouts")
	assert(str(loadout_session.simulation.state["players"][1]["small_skill_id"]) == "typist_golden_time_i")
	assert(str(loadout_session.simulation.state["players"][1]["skill3_id"]) == "typist_golden_time_iii")

	var session := MatchSession.new("result-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
	session.simulation.configure_loadout(1, 1, "typist_trident")
	session.phase = "match"
	assert(session.submit_input(11, MatchProtocol.make_input(100, Vector2.RIGHT)))
	assert(session.submit_event(11, MatchProtocol.make_event(100, "attack")))
	session.phase = "result"
	session.simulation.state["match_over"] = true
	assert(not session.request_result_action(999, "rematch"))
	assert(session.request_result_action(11, "rematch"))
	assert(session.phase == "result")
	assert(bool(session.make_snapshot()["rematch_ready"][1]))
	assert(not bool(session.make_snapshot()["rematch_ready"][2]))
	assert(session.request_result_action(12, "rematch"))
	assert(session.phase == "countdown")
	assert(int(session.make_snapshot()["round_id"]) == 1)
	assert(not session.submit_event(11, MatchProtocol.make_event(1, "small_skill")))
	session.step(MatchSession.READY_DURATION)
	assert(session.phase == "match")
	assert(not bool(session.simulation.state["match_over"]))
	assert(str(session.simulation.state["players"][1]["character_id"]) == "arithmetic")
	assert(session.submit_input(11, MatchProtocol.make_input(1, Vector2.RIGHT)))
	assert(session.submit_event(11, MatchProtocol.make_event(1, "attack")))
	var rematch_start_position := Vector2(session.simulation.state["players"][1]["position"])
	session.step(0.3)
	assert(Vector2(session.simulation.state["players"][1]["position"]).x > rematch_start_position.x)
	session.phase = "result"
	session.simulation.state["match_over"] = true
	assert(session.request_result_action(12, "lobby"))
	assert(session.phase == "result")
	var returned_snapshot := session.make_snapshot(2)
	var remaining_snapshot := session.make_snapshot(1)
	assert(str(returned_snapshot["phase"]) == "lobby")
	assert(str(remaining_snapshot["phase"]) == "result")
	assert(bool(remaining_snapshot["result_lobby_slots"][2]))
	assert(not bool(remaining_snapshot["rematch_ready"][1]))
	assert(not bool(remaining_snapshot["rematch_ready"][2]))
	assert(not session.request_result_action(11, "rematch"))
	assert(session.request_result_action(11, "lobby"))
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
