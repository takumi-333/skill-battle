## Server-authoritative match rules. This class deliberately has no UI, Input,
## Node, drawing, or multiplayer dependency. It owns every game-result value.
class_name MatchSimulation
extends RefCounted

const ARENA := Rect2(0, 0, 2520, 1160)
const PLAYER_SPEED := 280.0
const PLAYER_RADIUS := 30.0
const NORMAL_RANGE := 122.0
const NORMAL_HALF_ANGLE_DOT := 0.57 # cos(55 degrees)
const MATCH_DURATION := 90.0
const FOCUS_SPEED_MULTIPLIER := 0.5
const NORMAL_COOLDOWN := 0.5
const NORMAL_DURATION := 0.28
const TYPING_COOLDOWN := 2.0
const BIG_COOLDOWN := 5.0
const SKILL3_COOLDOWN := 3.0
const TYPING_INTERRUPT_GAUGE := 30.0
const BIG_INTERRUPT_GAUGE := 50.0
const CHALLENGE_MISS_TIME_PENALTY := 1.8
const PROJECTILE_RADIUS := 10.0
const MAX_PROJECTILES := 64

const SMALL_WORDS := ["Track", "Chase", "Trace", "Trail", "Stalk"]
const BIG_WORDS := ["Hammer Down", "Smash the Earth", "Break the Ground", "Slam the Hammer", "Crush the Floor"]
const BIG_II_WORDS := ["Pursuit", "Track Down", "Follow the Trail", "Lock On", "On the Trail"]
const SKILL3_WORDS := ["Spin the Hammer, Scatter All", "Hammer Spin Sends Foes Flying", "Circle the Hammer, Crush All"]
const ARITH_SMALL := ["12 + 3 * 8", "15 + 4 * 9", "18 + 5 * 14", "21 + 6 * 7"]
const ARITH_BIG := ["22 + 4 * 16", "4 + 8 * 9 + 12", "16 + 17 + 18 + 19", "164 + 255"]

var state: Dictionary
var _challenge_nonce := 0
var _next_projectile_id := 1
var _next_trident_impact_id := 1
var _trace_evaluator := TraceEvaluator.new()

func _init() -> void:
	reset()

func reset() -> void:
	var initial := MatchState.new()
	state = {
		"players": initial.players.duplicate(true),
		"time_remaining": MATCH_DURATION,
		"match_over": false,
		"winner_id": 0,
		"status_text": "対戦準備中",
		"challenges": {},
		"skill_projectiles": [],
		"magic_zones": [],
		"shockwaves": [],
		"trident_impacts": [],
		"decoys": [],
		"hammer_spins": [],
	}
	configure_loadout(1, 0, "typist_trident")
	configure_loadout(2, 1, "typist_trident")

func configure_loadout(slot: int, character: int, big_skill: String) -> void:
	if not state["players"].has(slot):
		return
	var player: Dictionary = state["players"][slot]
	var ids := ["blade", "arithmetic", "chanter"]
	var visuals := ["typist", "arithmetician", "chanter"]
	var names := ["打鍵士", "算術士", "詠唱者"]
	var colors := [Color("ef6b73"), Color("7498ff"), Color("b98aff")]
	player["character_id"] = ids[character]
	player["visual_id"] = visuals[character]
	player["name"] = names[character]
	player["color"] = colors[character]
	player["normal_damage"] = [12, 10, 11][character]
	player["small_skill_id"] = "%s_small_0" % ids[character]
	player["big_skill_id"] = big_skill if character == 0 else "%s_big_0" % ids[character]
	player["skill3_id"] = "typist_hammer_spin" if character == 0 else ""
	player["position"] = Vector2(300, 390) if slot == 1 else Vector2(2260, 390)
	player["facing"] = Vector2.RIGHT if slot == 1 else Vector2.LEFT
	player["attack_facing"] = player["facing"]
	state["players"][slot] = player

func handle_event(slot: int, event: Dictionary) -> bool:
	if bool(state["match_over"]):
		return false
	var event_type := str(event["type"])
	var payload: Variant = event.get("payload", null)
	match event_type:
		"loadout":
			var setup: Dictionary = payload
			configure_loadout(slot, int(setup["character"]), str(setup["big_skill"]))
			return true
		"attack":
			return _try_normal_attack(slot)
		"small_skill":
			return _start_challenge(slot, "small")
		"big_skill":
			return _start_challenge(slot, "big")
		"skill3":
			return _start_challenge(slot, "skill3")
		"challenge_character":
			return _receive_challenge_character(slot, str(payload))
		"challenge_submit":
			return _submit_challenge(slot, str(payload))
		"challenge_trace":
			return _submit_trace(slot, payload as PackedVector2Array)
		"challenge_cancel":
			return _cancel_challenge(slot)
	return false

func step(delta: float, inputs: Dictionary) -> void:
	if bool(state["match_over"]):
		return
	state["time_remaining"] = maxf(0.0, float(state["time_remaining"]) - delta)
	for slot in [1, 2]:
		_update_player(slot, delta, inputs.get(slot, {"move": Vector2.ZERO}))
	_update_challenges(delta)
	_update_projectiles(delta)
	_update_zones(delta)
	_update_shockwaves(delta)
	_update_trident_impacts(delta)
	_update_hammer_spins(delta)
	_update_decoys(delta)
	if float(state["time_remaining"]) <= 0.0 and not bool(state["match_over"]):
		_finish_by_hp()

func finish_by_disconnect(leaving_slot: int) -> void:
	state["match_over"] = true
	state["winner_id"] = 2 if leaving_slot == 1 else 1
	state["status_text"] = "対戦相手との接続が切れました。"

func _update_player(slot: int, delta: float, input: Dictionary) -> void:
	var player: Dictionary = state["players"][slot]
	for key in ["attack_cooldown", "attack_time", "hit_time", "small_cooldown", "big_cooldown", "skill3_cooldown", "buff_time", "invisible_time", "invisible_flicker"]:
		player[key] = maxf(0.0, float(player.get(key, 0.0)) - delta)
	if float(player["buff_time"]) <= 0.0:
		player["buff_speed_multiplier"] = 1.0
		player["attack_damage_buff"] = 0
	var move: Vector2 = input.get("move", Vector2.ZERO)
	player["is_moving"] = false
	if float(player["attack_time"]) <= 0.0 and not _is_trident_active(slot) and move.length_squared() > 0.0:
		var direction := move.normalized()
		player["facing"] = direction
		var focus_multiplier := FOCUS_SPEED_MULTIPLIER if bool(player["focused"]) else 1.0
		var speed := PLAYER_SPEED * focus_multiplier * float(player.get("buff_speed_multiplier", 1.0)) * _hammer_speed_multiplier(slot)
		var next_position := _clamp_to_arena(Vector2(player["position"]) + direction * speed * delta)
		if not _players_overlap(next_position, Vector2(state["players"][_other(slot)]["position"])):
			player["position"] = next_position
			player["is_moving"] = true
	state["players"][slot] = player

func _try_normal_attack(slot: int) -> bool:
	var player: Dictionary = state["players"][slot]
	if bool(player["focused"]) or float(player["attack_cooldown"]) > 0.0:
		return false
	player["attack_cooldown"] = NORMAL_COOLDOWN
	player["attack_time"] = NORMAL_DURATION
	var facing: Vector2 = Vector2(player["facing"])
	if facing.length_squared() <= 0.0:
		facing = Vector2.RIGHT
	player["facing"] = facing.normalized()
	player["attack_facing"] = player["facing"]
	state["players"][slot] = player
	var target_slot := _other(slot)
	var target: Dictionary = state["players"][target_slot]
	var offset: Vector2 = Vector2(target["position"]) - Vector2(player["position"])
	if offset.length() <= NORMAL_RANGE and offset.length_squared() > 0.0 and Vector2(player["facing"]).dot(offset.normalized()) >= NORMAL_HALF_ANGLE_DOT:
		_apply_damage(target_slot, int(player["normal_damage"]) + int(player.get("attack_damage_buff", 0)), "%sの斬撃" % str(player["name"]))
		state["status_text"] = "%sの斬撃が%sに命中！" % [str(player["name"]), str(target["name"])]
	else:
		state["status_text"] = "%sは斬撃を振った。" % str(player["name"])
	return true

func _start_challenge(slot: int, tier: String) -> bool:
	var challenges: Dictionary = state["challenges"]
	if challenges.has(slot):
		return false
	var player: Dictionary = state["players"][slot]
	if bool(player["focused"]):
		return false
	var character_id := str(player["character_id"])
	if tier == "skill3" and character_id != "blade":
		return false
	var cooldown_key := "skill3_cooldown" if tier == "skill3" else ("big_cooldown" if tier == "big" else "small_cooldown")
	if float(player.get(cooldown_key, 0.0)) > 0.0:
		return false
	_challenge_nonce += 1
	var challenge := _make_challenge(slot, tier)
	player["focused"] = true
	player["challenge_elapsed"] = 0.0
	player["interrupt_gauge_max"] = BIG_INTERRUPT_GAUGE if tier == "big" else TYPING_INTERRUPT_GAUGE
	player["interrupt_gauge"] = player["interrupt_gauge_max"]
	player["interrupt_gauge_display"] = player["interrupt_gauge_max"]
	state["players"][slot] = player
	challenges[slot] = challenge
	state["challenges"] = challenges
	state["status_text"] = "%sが%sの集中を開始！" % [str(player["name"]), {"small": "スキル1", "big": "スキル2", "skill3": "スキル3"}[tier]]
	return true

func _make_challenge(slot: int, tier: String) -> Dictionary:
	var player: Dictionary = state["players"][slot]
	var character_id := str(player["character_id"])
	var values: Array = []
	var challenge_type := "typing"
	var skill := tier
	var limit := 6.0
	if character_id == "blade":
		if tier == "skill3":
			values = SKILL3_WORDS
			limit = 20.0
			skill = "skill3_typing"
		elif tier == "big" and str(player.get("big_skill_id", "")) == "typist_keycap_ii":
			values = BIG_II_WORDS
			limit = 7.0
			skill = "big_typing_keycap_ii"
		elif tier == "big":
			values = BIG_WORDS
			limit = 8.0
			skill = "big_typing"
		else:
			values = SMALL_WORDS
			skill = "small_typing"
	elif character_id == "arithmetic":
		challenge_type = "arithmetic"
		values = ARITH_BIG if tier == "big" else ARITH_SMALL
		limit = 10.0 if tier == "big" else 7.0
		skill = "big_arithmetic" if tier == "big" else "small_arithmetic"
	else:
		challenge_type = "tracing"
		limit = 0.0
		skill = "big_trace" if tier == "big" else "small_trace"
	var prompt := ""
	var answer := ""
	var target := PackedVector2Array()
	if challenge_type == "typing":
		prompt = str(values[_challenge_nonce % values.size()])
		answer = prompt
	elif challenge_type == "arithmetic":
		prompt = str(values[_challenge_nonce % values.size()])
		answer = str(_evaluate_arithmetic(prompt))
		prompt += " = ?"
	else:
		prompt = "星形をなぞってください" if tier == "big" else "円をなぞってください"
		target = _make_trace_target(tier == "big")
	return {"id": _challenge_nonce, "owner": slot, "tier": tier, "skill": skill, "type": challenge_type, "prompt": prompt, "answer": answer, "elapsed": 0.0, "limit": limit, "typed": "", "target": target, "trace": PackedVector2Array(), "miss_sequence": 0}

func _receive_challenge_character(slot: int, character: String) -> bool:
	var challenge: Dictionary = _challenge_for(slot)
	if challenge.is_empty() or str(challenge["type"]) != "typing":
		return false
	var typed := str(challenge["typed"])
	var answer := str(challenge["answer"])
	if typed.length() >= answer.length() or character != answer.substr(typed.length(), 1):
		_challenge_miss(slot, challenge)
		return true
	challenge["typed"] = typed + character
	_set_challenge(slot, challenge)
	if str(challenge["typed"]).length() >= answer.length():
		_end_challenge(slot, true, _score_challenge(challenge), "")
	return true

func _submit_challenge(slot: int, submitted: String) -> bool:
	var challenge: Dictionary = _challenge_for(slot)
	if challenge.is_empty() or str(challenge["type"]) != "arithmetic":
		return false
	if submitted.strip_edges() == str(challenge["answer"]):
		_end_challenge(slot, true, _score_challenge(challenge), "")
	else:
		_challenge_miss(slot, challenge)
	return true

func _submit_trace(slot: int, trace: PackedVector2Array) -> bool:
	var challenge: Dictionary = _challenge_for(slot)
	if challenge.is_empty() or str(challenge["type"]) != "tracing":
		return false
	challenge["trace"] = trace
	_set_challenge(slot, challenge)
	var result := _trace_evaluator.evaluate(challenge["target"], trace)
	if not bool(result.get("ng", true)) and int(result.get("score", 0)) >= 45:
		_end_challenge(slot, true, int(result["score"]), "")
	else:
		_end_challenge(slot, false, 0, "なぞりに失敗した。")
	return true

func _cancel_challenge(slot: int) -> bool:
	if _challenge_for(slot).is_empty():
		return false
	_end_challenge(slot, false, 0, "課題を中止した。")
	return true

func _challenge_miss(owner: int, challenge: Dictionary) -> void:
	var player: Dictionary = state["players"][owner]
	player["challenge_errors"] = int(player.get("challenge_errors", 0)) + 1
	challenge["elapsed"] = minf(float(challenge["limit"]), float(challenge["elapsed"]) + CHALLENGE_MISS_TIME_PENALTY)
	challenge["miss_sequence"] = int(challenge.get("miss_sequence", 0)) + 1
	player["challenge_elapsed"] = challenge["elapsed"]
	state["players"][owner] = player
	_set_challenge(owner, challenge)
	state["status_text"] = "課題入力を間違えた。残り時間が減少した。"

func _update_challenges(delta: float) -> void:
	var owners: Array = state["challenges"].keys()
	for value in owners:
		var owner := int(value)
		var challenge: Dictionary = _challenge_for(owner)
		if challenge.is_empty():
			continue
		challenge["elapsed"] = float(challenge["elapsed"]) + delta
		var player: Dictionary = state["players"][owner]
		player["challenge_elapsed"] = challenge["elapsed"]
		state["players"][owner] = player
		_set_challenge(owner, challenge)
		if float(challenge["limit"]) > 0.0 and float(challenge["elapsed"]) >= float(challenge["limit"]):
			_end_challenge(owner, false, 0, "時間切れ。課題は失敗した。")

func _end_challenge(owner: int, success: bool, score: int, message: String) -> void:
	var challenge: Dictionary = _challenge_for(owner)
	if challenge.is_empty():
		return
	var player: Dictionary = state["players"][owner]
	var tier := str(challenge["tier"])
	player["focused"] = false
	player["challenge_total_time"] = float(player.get("challenge_total_time", 0.0)) + float(challenge["elapsed"])
	player["challenge_elapsed"] = 0.0
	player["interrupt_gauge"] = 0.0
	player["interrupt_gauge_max"] = 0.0
	if tier == "skill3":
		player["skill3_cooldown"] = SKILL3_COOLDOWN
	elif tier == "big":
		player["big_cooldown"] = 7.0 if str(player.get("big_skill_id", "")) == "typist_keycap_ii" else BIG_COOLDOWN
	else:
		player["small_cooldown"] = TYPING_COOLDOWN
	if success:
		player["skill_successes"] = int(player.get("skill_successes", 0)) + 1
		player["score_total"] = int(player.get("score_total", 0)) + score
		player["best_score"] = maxi(int(player.get("best_score", 0)), score)
		player["challenge_count"] = int(player.get("challenge_count", 0)) + 1
		player["challenge_score_total"] = int(player.get("challenge_score_total", 0)) + score
		player["challenge_best_score"] = maxi(int(player.get("challenge_best_score", 0)), score)
	state["players"][owner] = player
	state["challenges"].erase(owner)
	if success:
		_spawn_skill(owner, score, challenge)
		state["status_text"] = "%sの%sが発動！ スコア %d点" % [str(player["name"]), {"small": "スキル1", "big": "スキル2", "skill3": "スキル3"}[tier], score]
	else:
		state["status_text"] = message

func _challenge_for(slot: int) -> Dictionary:
	return state["challenges"].get(slot, {})

func _set_challenge(slot: int, challenge: Dictionary) -> void:
	state["challenges"][slot] = challenge

func _spawn_skill(owner: int, score: int, challenge: Dictionary) -> void:
	var player: Dictionary = state["players"][owner]
	var character_id := str(player["character_id"])
	var tier := str(challenge["tier"])
	if character_id == "blade":
		if tier == "skill3":
			state["hammer_spins"].append({"owner_id": owner, "score": score, "angle": 0.0, "lifetime": _hammer_duration(score), "hit_timer": 0.0, "keycap_timer": 0.5})
		elif tier == "big" and str(player.get("big_skill_id", "")) == "typist_trident":
			state["trident_impacts"].append({"impact_id": _next_trident_impact_id, "owner_id": owner, "origin": Vector2(player["position"]), "facing": Vector2(player["facing"]), "score": score, "elapsed": 0.0, "strike_duration": 1.0, "duration": 1.9, "released": false})
			_next_trident_impact_id += 1
		else:
			var interval := 0.3 if tier == "big" else 0.5
			var typed := str(challenge.get("typed", ""))
			for index in typed.length():
				_spawn_projectile(owner, score, false, 0.0, float(index) * interval, typed[index])
	elif character_id == "arithmetic":
		if tier == "small":
			_spawn_decoys(owner, score)
		else:
			player = state["players"][owner]
			player["buff_time"] = lerpf(10.0, 20.0, float(score) / 100.0)
			player["buff_speed_multiplier"] = 1.25
			player["attack_damage_buff"] = 10
			player["invisible_time"] = player["buff_time"]
			state["players"][owner] = player
	else:
		if tier == "small":
			for index in 3:
				_spawn_zone(owner, score, float(index) * 1.5, 2.0 if index < 2 else 2.5)
		else:
			for index in 16:
				_spawn_projectile(owner, score, true, TAU * float(index) / 16.0, float(index) * 0.08)

func _spawn_projectile(owner: int, score: int, big: bool, angle_offset: float, delay: float, chip: String = "") -> void:
	if state["skill_projectiles"].size() >= MAX_PROJECTILES:
		return
	var player: Dictionary = state["players"][owner]
	var facing := Vector2(player["facing"]).rotated(angle_offset)
	state["skill_projectiles"].append({"projectile_id": _next_projectile_id, "owner_id": owner, "position": Vector2(player["position"]) + facing * (PLAYER_RADIUS + PROJECTILE_RADIUS), "velocity": facing * (300.0 if big else 550.0), "damage": (50 if big else 5) + (roundi(float(score) * 0.2) if big else floori(float(score) * 0.1)), "lifetime": 5.0 if big else 2.0, "piercing": big, "delay": delay, "chip": chip, "launched": false, "homing": not big and score >= 80, "homing_time": 0.7 if not big and score >= 80 else 0.0, "initial_angle": facing.angle(), "key_cap": not big})
	_next_projectile_id += 1

func _update_projectiles(delta: float) -> void:
	for index in range(state["skill_projectiles"].size() - 1, -1, -1):
		var projectile: Dictionary = state["skill_projectiles"][index]
		projectile["delay"] = maxf(0.0, float(projectile["delay"]) - delta)
		if float(projectile["delay"]) > 0.0:
			state["skill_projectiles"][index] = projectile
			continue
		var owner := int(projectile["owner_id"])
		var target := _other(owner)
		if not bool(projectile["launched"]):
			var source := Vector2(state["players"][owner]["position"])
			var direction := (Vector2(state["players"][target]["position"]) - source).normalized()
			projectile["position"] = source + direction * (PLAYER_RADIUS + PROJECTILE_RADIUS)
			projectile["velocity"] = direction * 550.0
			projectile["launched"] = true
		if bool(projectile["homing"]) and float(projectile["homing_time"]) > 0.0:
			var desired := (Vector2(state["players"][target]["position"]) - Vector2(projectile["position"])).normalized()
			projectile["velocity"] = Vector2(projectile["velocity"]).lerp(desired * Vector2(projectile["velocity"]).length(), minf(1.0, 0.6 * delta))
			projectile["homing_time"] = maxf(0.0, float(projectile["homing_time"]) - delta)
		projectile["position"] = Vector2(projectile["position"]) + Vector2(projectile["velocity"]) * delta
		projectile["lifetime"] = float(projectile["lifetime"]) - delta
		if _point_hits_player(Vector2(projectile["position"]), target, PROJECTILE_RADIUS):
			_apply_damage(target, int(projectile["damage"]), "スキル弾")
			if not bool(projectile["piercing"]):
				state["skill_projectiles"].remove_at(index)
				continue
		if float(projectile["lifetime"]) <= 0.0 or not ARENA.grow(40.0).has_point(Vector2(projectile["position"])):
			state["skill_projectiles"].remove_at(index)
		else:
			state["skill_projectiles"][index] = projectile

func _spawn_decoys(owner: int, score: int) -> void:
	var decoys: Array = state["decoys"]
	decoys.clear()
	var count := clampi(5 + score / 20, 5, 10)
	var player: Dictionary = state["players"][owner]
	var lifetime := 20.0 if score < 60 else (30.0 if score < 80 else 40.0)
	for index in count:
		var angle := TAU * float(index) / float(count)
		decoys.append({"owner_id": owner, "visual_id": "arithmetician", "facing": Vector2(player["facing"]).rotated(angle), "position": _clamp_to_arena(Vector2(player["position"]) + Vector2.from_angle(angle) * (90.0 + 25.0 * index)), "owner_position": Vector2(player["position"]), "movement_offset_angle": angle, "is_moving": false, "animation_phase": float(index) / count, "lifetime": lifetime, "noise_timer": 5.0, "noise_time": 0.0, "noise_phase": angle, "flash_time": 0.25})
	player["buff_time"] = lifetime
	player["buff_speed_multiplier"] = 1.1
	player["attack_damage_buff"] = 5
	state["players"][owner] = player

func _update_decoys(delta: float) -> void:
	for index in range(state["decoys"].size() - 1, -1, -1):
		var decoy: Dictionary = state["decoys"][index]
		var owner := int(decoy["owner_id"])
		var player: Dictionary = state["players"][owner]
		var delta_position := Vector2(player["position"]) - Vector2(decoy["owner_position"])
		decoy["position"] = _clamp_to_arena(Vector2(decoy["position"]) + delta_position.rotated(float(decoy["movement_offset_angle"])))
		decoy["owner_position"] = player["position"]
		decoy["facing"] = Vector2(player["facing"]).rotated(float(decoy["movement_offset_angle"]))
		decoy["is_moving"] = delta_position.length_squared() > 0.0
		decoy["flash_time"] = maxf(0.0, float(decoy.get("flash_time", 0.0)) - delta)
		decoy["lifetime"] = float(decoy["lifetime"]) - delta
		if float(decoy["lifetime"]) <= 0.0:
			state["decoys"].remove_at(index)
		else:
			state["decoys"][index] = decoy

func _spawn_zone(owner: int, score: int, delay: float, duration: float) -> void:
	state["magic_zones"].append({"owner_id": owner, "position": Vector2.ZERO, "lifetime": 0.0, "active_duration": duration, "delay": delay, "damage_timer": 0.3, "damage": 8 + roundi(float(score) * 0.06), "spawned": false, "damage_started": false, "damage_flash": 0.0, "pulse_time": 0.0, "damage_applied": false})

func _update_zones(delta: float) -> void:
	for index in range(state["magic_zones"].size() - 1, -1, -1):
		var zone: Dictionary = state["magic_zones"][index]
		zone["delay"] = float(zone["delay"]) - delta
		var target := _other(int(zone["owner_id"]))
		if not bool(zone["spawned"]) and float(zone["delay"]) <= 0.0:
			zone["position"] = state["players"][target]["position"]
			zone["spawned"] = true
			zone["lifetime"] = zone["active_duration"]
		if bool(zone["spawned"]):
			zone["lifetime"] = float(zone["lifetime"]) - delta
			zone["damage_timer"] = float(zone["damage_timer"]) - delta
			if float(zone["damage_timer"]) <= 0.0 and not bool(zone["damage_applied"]):
				if _point_hits_player(Vector2(zone["position"]), target, 80.0):
					_apply_damage(target, int(zone["damage"]), "魔法陣")
				zone["damage_applied"] = true
		if bool(zone["spawned"]) and float(zone["lifetime"]) <= 0.0:
			state["magic_zones"].remove_at(index)
		else:
			state["magic_zones"][index] = zone

func _update_trident_impacts(delta: float) -> void:
	for index in range(state["trident_impacts"].size() - 1, -1, -1):
		var impact: Dictionary = state["trident_impacts"][index]
		impact["elapsed"] = float(impact["elapsed"]) + delta
		if not bool(impact["released"]) and float(impact["elapsed"]) >= float(impact["strike_duration"]):
			_release_trident(impact)
			impact["released"] = true
		if float(impact["elapsed"]) >= float(impact["duration"]):
			state["trident_impacts"].remove_at(index)
		else:
			state["trident_impacts"][index] = impact

func _release_trident(impact: Dictionary) -> void:
	var owner := int(impact["owner_id"])
	var score := int(impact["score"])
	var facing := Vector2(impact["facing"]).normalized()
	var landing := Vector2(impact["origin"]) + facing * (120.0 + float(score) * 0.25)
	var target := _other(owner)
	if _point_hits_player(landing, target, 30.0):
		_apply_damage(target, _trident_landing_damage(score), "三叉震槌の直撃")
	for angle in [-PI / 2.0, -PI / 3.0, 0.0, PI / 3.0, PI / 2.0]:
		_spawn_projectile_from(owner, score, landing, facing.rotated(angle), true)
	if score >= 50:
		for index in 3:
			state["shockwaves"].append({"owner_id": owner, "origin": landing, "delay": float(index) * 0.5, "elapsed": 0.0, "radius": 0.0, "duration": 1.0, "damage": 0 if score < 80 else 12 + roundi(float(score) * 0.2), "knockback": lerpf(18.0, 48.0, float(score) / 100.0), "hit": false})

func _spawn_projectile_from(owner: int, score: int, position_value: Vector2, facing: Vector2, big: bool) -> void:
	if state["skill_projectiles"].size() >= MAX_PROJECTILES:
		return
	state["skill_projectiles"].append({"projectile_id": _next_projectile_id, "owner_id": owner, "position": position_value + facing * (PLAYER_RADIUS + PROJECTILE_RADIUS), "velocity": facing * 300.0, "damage": 50 + roundi(float(score) * 0.2), "lifetime": 5.0, "piercing": big, "delay": 0.0, "chip": "", "launched": true, "homing": false, "homing_time": 0.0, "initial_angle": facing.angle(), "key_cap": false})
	_next_projectile_id += 1

func _update_shockwaves(delta: float) -> void:
	for index in range(state["shockwaves"].size() - 1, -1, -1):
		var wave: Dictionary = state["shockwaves"][index]
		wave["delay"] = float(wave["delay"]) - delta
		if float(wave["delay"]) <= 0.0:
			wave["elapsed"] = float(wave["elapsed"]) + delta
			wave["radius"] = 150.0 * float(wave["elapsed"])
			var target := _other(int(wave["owner_id"]))
			if not bool(wave["hit"]) and Vector2(state["players"][target]["position"]).distance_to(Vector2(wave["origin"])) <= float(wave["radius"]) + PLAYER_RADIUS:
				if int(wave["damage"]) > 0:
					_apply_damage(target, int(wave["damage"]), "三叉震槌")
				var player: Dictionary = state["players"][target]
				player["position"] = _clamp_to_arena(Vector2(player["position"]) + (Vector2(player["position"]) - Vector2(wave["origin"])).normalized() * float(wave["knockback"]))
				state["players"][target] = player
				wave["hit"] = true
		if float(wave["delay"]) <= 0.0 and float(wave["elapsed"]) >= float(wave["duration"]):
			state["shockwaves"].remove_at(index)
		else:
			state["shockwaves"][index] = wave

func _update_hammer_spins(delta: float) -> void:
	for index in range(state["hammer_spins"].size() - 1, -1, -1):
		var spin: Dictionary = state["hammer_spins"][index]
		var owner := int(spin["owner_id"])
		spin["lifetime"] = float(spin["lifetime"]) - delta
		spin["angle"] = fmod(float(spin["angle"]) + TAU * 1.35 * delta, TAU)
		spin["hit_timer"] = maxf(0.0, float(spin["hit_timer"]) - delta)
		spin["keycap_timer"] = float(spin["keycap_timer"]) - delta
		var player: Dictionary = state["players"][owner]
		player["facing"] = Vector2.from_angle(float(spin["angle"]))
		state["players"][owner] = player
		var tip := Vector2(player["position"]) + Vector2.from_angle(float(spin["angle"])) * (92.0 + float(spin["score"]) * 0.42)
		var target := _other(owner)
		if float(spin["hit_timer"]) <= 0.0 and _point_hits_segment(Vector2(state["players"][target]["position"]), Vector2(player["position"]), tip, PLAYER_RADIUS + 12.0):
			_apply_damage(target, 10 + floori(float(spin["score"]) * 0.2), "ぶんまわし")
			spin["hit_timer"] = 0.28
		if int(spin["score"]) >= 60 and float(spin["keycap_timer"]) <= 0.0:
			if state["skill_projectiles"].size() < MAX_PROJECTILES:
				var keycap_facing := Vector2(player["facing"])
				state["skill_projectiles"].append({"projectile_id": _next_projectile_id, "owner_id": owner, "position": tip, "velocity": keycap_facing * 800.0, "damage": 10, "lifetime": 3.0, "piercing": false, "delay": 0.0, "chip": "", "launched": true, "homing": false, "homing_time": 0.0, "initial_angle": keycap_facing.angle(), "key_cap": true})
				_next_projectile_id += 1
			spin["keycap_timer"] = 0.5
		if float(spin["lifetime"]) <= 0.0:
			state["hammer_spins"].remove_at(index)
		else:
			state["hammer_spins"][index] = spin

func _apply_damage(target_slot: int, damage: int, attack_name: String) -> void:
	if bool(state["match_over"]):
		return
	var target: Dictionary = state["players"][target_slot]
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	target["hit_time"] = 0.20
	state["players"][target_slot] = target
	if not _challenge_for(target_slot).is_empty():
		target["interrupt_gauge"] = maxf(0.0, float(target["interrupt_gauge"]) - damage)
		target["interrupt_gauge_display"] = target["interrupt_gauge"]
		state["players"][target_slot] = target
		if float(target["interrupt_gauge"]) <= 0.0:
			_end_challenge(target_slot, false, 0, "%sで中断ゲージが尽きた。課題は失敗した。" % attack_name)
	if int(target["hp"]) <= 0:
		state["match_over"] = true
		state["winner_id"] = _other(target_slot)
		state["status_text"] = "%sの勝利！" % str(state["players"][_other(target_slot)]["name"])

func _finish_by_hp() -> void:
	state["match_over"] = true
	var p1 := int(state["players"][1]["hp"])
	var p2 := int(state["players"][2]["hp"])
	state["winner_id"] = 1 if p1 > p2 else (2 if p2 > p1 else 0)
	state["status_text"] = "時間切れ、引き分け！" if int(state["winner_id"]) == 0 else "%sの勝利！" % str(state["players"][state["winner_id"]]["name"])

func _score_challenge(challenge: Dictionary) -> int:
	var ratio := clampf((float(challenge["limit"]) - float(challenge["elapsed"])) / float(challenge["limit"]), 0.0, 1.0)
	return clampi(roundi(100.0 * (ratio + 0.85 / TAU * sin(TAU * ratio))), 0, 100)

func _evaluate_arithmetic(expression: String) -> int:
	var total := 0
	for add_term in expression.split("+"):
		var product := 1
		for factor in add_term.strip_edges().split("*"):
			product *= int(factor.strip_edges())
		total += product
	return total

func _make_trace_target(big: bool) -> PackedVector2Array:
	var center := Vector2(340, 118)
	var points := PackedVector2Array()
	if not big:
		for index in 49:
			points.append(center + Vector2.from_angle(float(index) * TAU / 48.0) * 92.0)
		return points
	for index in 11:
		var radius := 96.0 if index % 2 == 0 else 39.0
		points.append(center + Vector2.from_angle(-PI / 2.0 + float(index) * TAU / 10.0) * radius)
	return points

func _hammer_duration(score: int) -> float:
	if score <= 30:
		return 3.0
	if score <= 50:
		return lerpf(3.0, 6.0, float(score - 30) / 20.0)
	if score <= 70:
		return lerpf(6.0, 9.0, float(score - 50) / 20.0)
	return lerpf(9.0, 13.0, minf(1.0, float(score - 70) / 30.0))

func _hammer_speed_multiplier(slot: int) -> float:
	for spin in state["hammer_spins"]:
		if int(spin["owner_id"]) == slot:
			var score := int(spin["score"])
			return 0.8 if score <= 30 else (0.9 if score <= 40 else (1.0 if score <= 60 else (1.05 if score < 80 else 1.1)))
	return 1.0

func _trident_landing_damage(score: int) -> int:
	if score < 30:
		return 10
	if score < 40:
		return 40
	if score < 50:
		return 45
	if score < 60:
		return 50
	return score

func _is_trident_active(slot: int) -> bool:
	for impact in state["trident_impacts"]:
		if int(impact["owner_id"]) == slot:
			return true
	return false

func _point_hits_player(point: Vector2, slot: int, padding: float = 0.0) -> bool:
	return point.distance_to(Vector2(state["players"][slot]["position"])) <= PLAYER_RADIUS + padding

func _players_overlap(first: Vector2, second: Vector2) -> bool:
	var offset := first - second
	return (offset.x * offset.x) / (40.0 * 40.0) + (offset.y * offset.y) / (60.0 * 60.0) < 1.0

func _point_hits_segment(point: Vector2, start: Vector2, end: Vector2, padding: float) -> bool:
	var segment := end - start
	var ratio := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_to(start + segment * ratio) <= padding

func _clamp_to_arena(position_value: Vector2) -> Vector2:
	return Vector2(clampf(position_value.x, 30.0, ARENA.size.x - 30.0), clampf(position_value.y, 30.0, ARENA.size.y - 30.0))

func _other(slot: int) -> int:
	return 2 if slot == 1 else 1
