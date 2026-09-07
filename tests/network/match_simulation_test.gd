extends SceneTree

func _init() -> void:
	_test_state_and_normal_attack()
	_test_typist_skills()
	_test_arithmetician_skills()
	_test_chanter_skills()
	_test_focus_interruption()
	_test_session_event_deduplication()
	_test_session_ready_start()
	_test_session_result_actions()
	_test_delayed_keycap_targets_from_launch_position()
	_test_decoy_flash_expires()
	_test_snapshot_dictionary_array_conversion()
	print("server-authoritative match simulation tests passed")
	quit()

func _test_state_and_normal_attack() -> void:
	var simulation := MatchSimulation.new()
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

func _test_typist_skills() -> void:
	var simulation := MatchSimulation.new()
	assert(simulation.handle_event(1, {"type": "small_skill"}))
	_complete_typing(simulation, 1)
	assert(simulation.state["challenge"].is_empty())
	assert(not simulation.state["skill_projectiles"].is_empty())
	var big_simulation := MatchSimulation.new()
	assert(big_simulation.handle_event(1, {"type": "big_skill"}))
	_complete_typing(big_simulation, 1)
	big_simulation.step(1.1, {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}})
	assert(not big_simulation.state["trident_impacts"].is_empty() or not big_simulation.state["skill_projectiles"].is_empty())
	var skill3_simulation := MatchSimulation.new()
	assert(skill3_simulation.handle_event(1, {"type": "skill3"}))
	_complete_typing(skill3_simulation, 1)
	assert(not skill3_simulation.state["hammer_spins"].is_empty())

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
	var target: PackedVector2Array = simulation.state["challenge"]["target"]
	assert(simulation.handle_event(1, {"type": "challenge_trace", "payload": target}))
	assert(simulation.state["challenge"].is_empty())
	assert(simulation.state["magic_zones"].size() == 3)
	var big_simulation := MatchSimulation.new()
	big_simulation.configure_loadout(1, 2, "typist_trident")
	assert(big_simulation.handle_event(1, {"type": "big_skill"}))
	var big_target: PackedVector2Array = big_simulation.state["challenge"]["target"]
	assert(big_simulation.handle_event(1, {"type": "challenge_trace", "payload": big_target}))
	assert(not big_simulation.state["skill_projectiles"].is_empty())

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
	assert(simulation.state["challenge"].is_empty())

func _test_session_event_deduplication() -> void:
	var session := MatchSession.new("test-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
	session.phase = "match"
	assert(session.submit_event(11, MatchProtocol.make_event(1, "small_skill")))
	assert(not session.submit_event(11, MatchProtocol.make_event(1, "small_skill")))

func _test_session_ready_start() -> void:
	var session := MatchSession.new("ready-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
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
	assert(session.phase == "match")


func _test_session_result_actions() -> void:
	var session := MatchSession.new("result-room")
	assert(session.join(11, 1) == 1)
	assert(session.join(12, 2) == 2)
	session.simulation.configure_loadout(1, 1, "typist_trident")
	session.phase = "result"
	session.simulation.state["match_over"] = true
	assert(not session.request_result_action(999, "rematch"))
	assert(session.request_result_action(11, "rematch"))
	assert(session.phase == "match")
	assert(not bool(session.simulation.state["match_over"]))
	assert(str(session.simulation.state["players"][1]["character_id"]) == "arithmetic")
	session.phase = "result"
	session.simulation.state["match_over"] = true
	assert(session.request_result_action(12, "lobby"))
	assert(session.phase == "lobby")
	assert(not bool(session.make_snapshot()["ready"][1]))
	assert(not bool(session.make_snapshot()["ready"][2]))


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
	var answer := str(simulation.state["challenge"]["answer"])
	for character in answer:
		assert(simulation.handle_event(slot, {"type": "challenge_character", "payload": character}))

func _complete_arithmetic(simulation: MatchSimulation, slot: int) -> void:
	var answer := str(simulation.state["challenge"]["answer"])
	assert(simulation.handle_event(slot, {"type": "challenge_submit", "payload": answer}))
