## Server-authoritative match rules. This class deliberately has no UI, Input,
## Node, drawing, or multiplayer dependency. It owns every game-result value.
class_name MatchSimulation
extends RefCounted

const TypistHammerShockwaveHitboxData = preload("res://scripts/data/typist_hammer_shockwave_hitbox.gd")

const ARENA := Rect2(0, 0, 1680, 774)
const PLAYER_SPEED := 280.0
const PLAYER_RADIUS := 30.0
const NORMAL_RANGE := 122.0
const NORMAL_HALF_ANGLE_DOT := 0.57 # cos(55 degrees)
const MATCH_DURATION := 90.0
const FOCUS_SPEED_MULTIPLIER := 0.5
const NORMAL_COOLDOWN := 3.0
const NORMAL_DURATION := 0.28
const TYPING_COOLDOWN := 2.0
const ARITHMETIC_BIG_COOLDOWN := 15.0
const ARITHMETICIAN_PERFECT_MAPPING_COOLDOWN := 10.0
const CHANTER_SKILL1B_COOLDOWN := 3.0
const BIG_COOLDOWN := 5.0
const CHANTER_SKILL2_COOLDOWN := 6.0
const CHANTER_METEOR_SHOWER_COOLDOWN := 8.0
const CHANTER_SKILL3_COOLDOWN := 8.0
const CHANTER_LUNAR_ECLIPSE_COOLDOWN := 10.0
const SKILL3_COOLDOWN := 3.0
const TYPIST_GOLDEN_TIME_I_COOLDOWN := 50.0
const TYPIST_GOLDEN_TIME_II_COOLDOWN := 60.0
const TYPIST_GOLDEN_TIME_III_COOLDOWN := 70.0
const TYPIST_GOLDEN_TIME_SCORE_MULTIPLIER := 1.25
const TYPIST_GOLDEN_TIME_MISS_PENALTY := 0.9
const ARITHMETICIAN_HACK_VISION_COOLDOWN := 12.0
const CHALLENGE_MISS_TIME_PENALTY := 1.8
const PROJECTILE_RADIUS := 10.0
const MAX_PROJECTILES := 320
const TRACE_MIN_ELAPSED := 0.35
const TRACE_MIN_POINTS := 8
const TRACE_MIN_LENGTH := 80.0
const TRACE_MAX_SEGMENT_LENGTH := 180.0
const CHANTER_ZONE_WARNING_DURATION := 0.5
const CHANTER_ZONE_DAMAGE_INTERVAL := 0.5
const CHANTER_ZONE_RADIUS := 80.0
const CHANTER_TARGET_HITBOX_RADIUS_X := 20.0
const CHANTER_TARGET_HITBOX_RADIUS_Y := 30.0
const CHANTER_TARGET_HITBOX_OFFSET := Vector2(0.0, -12.0)
const METEOR_PAIR_COUNT := 10
const METEORS_PER_PAIR := 2
const METEOR_PAIR_INTERVAL := 0.65
const METEOR_FALL_DURATION := 2.0
const METEOR_RIPPLE_DURATION := 0.75
const METEOR_DAMAGE_RADIUS := 110.0
const METEOR_OWNER_SAFE_RADIUS := 120.0
const METEOR_TARGET_MIN_DISTANCE := 80.0
const METEOR_TARGET_MAX_DISTANCE := 260.0
const LUNAR_ECLIPSE_LASER_START_TIME := 2.0
const LUNAR_ECLIPSE_LASER_DURATION := 2.5
const LUNAR_ECLIPSE_DURATION := LUNAR_ECLIPSE_LASER_START_TIME + LUNAR_ECLIPSE_LASER_DURATION
const LUNAR_ECLIPSE_LASER_DAMAGE_INTERVAL := 0.5
const LUNAR_ECLIPSE_LASER_LAST_HIT_TIME := LUNAR_ECLIPSE_LASER_START_TIME + LUNAR_ECLIPSE_LASER_DAMAGE_INTERVAL * 2.0
const LUNAR_ECLIPSE_PULL_INTERVAL := 0.1
const LUNAR_ECLIPSE_LASER_HALF_WIDTH := 150.0
const ARITHMETICIAN_DECOY_MIN_NOISE_INTERVAL := 5.0
const ARITHMETICIAN_DECOY_MAX_NOISE_INTERVAL := 10.0
const ARITHMETICIAN_DECOY_NOISE_DURATION := 0.12
const ARITHMETICIAN_FLASH_DURATION := 0.2
const ARITHMETICIAN_INVISIBILITY_FLICKER_INTERVAL := 2.5
const ARITHMETICIAN_DECOY_HIT_RADIUS := 30.0
const ARITHMETICIAN_DECOY_INTERFERENCE_POINTS := 0.1
const ARITHMETICIAN_POINT_COLLECTION_WAIT := 1.0
const ARITHMETICIAN_POINT_COLLECTION_SPEED := 620.0
const ARITHMETICIAN_POINT_COLLECTION_ARRIVAL_DISTANCE := 18.0

const SMALL_WORDS := ["Track", "Chase", "Trace", "Trail", "Stalk"]
const BIG_WORDS := ["Hammer Down", "Smash the Earth", "Break the Ground", "Slam the Hammer", "Crush the Floor"]
const BIG_II_WORDS := ["Pursuit", "Track Down", "Follow the Trail", "Lock On", "On the Trail"]
const SKILL3_WORDS := ["Spin the Hammer, Scatter All", "Hammer Spin Sends Foes Flying", "Circle the Hammer, Crush All"]
const GOLDEN_TIME_I_WORDS := ["Zone Mode", "In the zone", "Typing Mode", "Typing Time", "Focus type"]
const GOLDEN_TIME_II_WORDS := ["Enter the Zone", "Stay in the Zone", "Zone Control", "Hold the Zone", "Zone Master"]
const GOLDEN_TIME_III_WORDS := ["Master the Typing Zone", "Control the Golden Zone", "Own the Entire Zone", "Keep the Zone Alive", "Rule the Typing Zone"]
const ARITH_SMALL := ["12 + 3 * 8", "15 + 4 * 9", "18 + 5 * 14", "21 + 6 * 7"]
const ARITH_BIG := ["22 + 4 * 16", "4 + 8 * 9 + 12", "16 + 17 + 18 + 19", "164 + 255"]
const ARITH_PERFECT_MAPPING := ["28 + 7 * 18", "9 + 12 * 11 + 16", "24 + 25 + 26 + 27", "212 + 187", "31 + 8 * 15", "14 + 9 * 13 + 21", "29 + 30 + 31 + 32", "238 + 176", "26 + 6 * 19", "11 + 14 * 9 + 17", "18 + 20 + 22 + 24", "257 + 168", "33 + 5 * 17", "15 + 11 * 12 + 19", "27 + 28 + 29 + 30"]
const ARITH_HACK_VISION := ["33 * 44 + 16 * 6 + 29", "28 * 47 + 15 * 7 + 34", "36 * 42 + 18 * 5 + 27", "31 * 46 + 14 * 8 + 25", "27 * 53 + 17 * 6 + 32", "34 * 41 + 19 * 5 + 28", "29 * 48 + 16 * 7 + 31", "37 * 39 + 13 * 8 + 26", "32 * 45 + 17 * 6 + 35"]

var state: Dictionary
var _challenge_nonce := 0
var _next_projectile_id := 1
var _next_trident_impact_id := 1
var _next_meteor_impact_id := 1
var _next_presentation_id := 1
var _trace_evaluator := TraceEvaluator.new()
var _pending_visual_presentations: Array[Dictionary] = []

func _init() -> void:
	reset()

func reset() -> void:
	_pending_visual_presentations.clear()
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
		"meteor_impacts": [],
		"decoys": [],
		"arithmetic_flashes": [],
		"arithmetic_point_collections": [],
		"perfect_mapping_effects": [],
		"hammer_spins": [],
		"lunar_eclipses": [],
	}
	configure_loadout(1, 0, "typist_trident")
	configure_loadout(2, 1, "typist_trident")

func configure_loadout(slot: int, character: int, big_skill: String, display_name: String = "", small_skill_index: int = 0, skill3_index: int = 0) -> void:
	if not state["players"].has(slot):
		return
	var player: Dictionary = state["players"][slot]
	var ids := ["blade", "arithmetic", "chanter"]
	var visuals := ["typist", "arithmetician", "chanter"]
	var names := ["打鍵士", "算術士", "詠唱者"]
	var colors := [Color("ef6b73"), Color("7498ff"), Color("b98aff")]
	player["character_id"] = ids[character]
	player["visual_id"] = visuals[character]
	var sanitized_display_name := display_name.strip_edges()
	player["name"] = sanitized_display_name if not sanitized_display_name.is_empty() else names[character]
	player["has_display_name"] = not sanitized_display_name.is_empty()
	player["color"] = colors[character]
	player["normal_damage"] = [5, 2, 3][character]
	player["arithmetic_interference_multiplier"] = 1.0
	player["hack_vision_time"] = 0.0
	player["hack_vision_owner_id"] = 0
	player["small_skill_id"] = "typist_golden_time_i" if character == 0 and small_skill_index == 1 else ("%s_small_%d" % [ids[character], small_skill_index if character == 2 and small_skill_index in [0, 1] else 0])
	player["big_skill_id"] = big_skill if character == 0 or (character == 1 and big_skill == "arithmetic_perfect_mapping") else ("chanter_big_1" if character == 2 and big_skill in ["chanter_meteor_shower", "chanter_big_1"] else "%s_big_0" % ids[character])
	player["skill3_id"] = "typist_golden_time_iii" if character == 0 and skill3_index == 1 else ("typist_hammer_spin" if character == 0 else ("arithmetic_hack_vision" if character == 1 and skill3_index == 0 else ("chanter_skill3_0" if character == 2 and skill3_index == 0 else ("chanter_lunar_eclipse" if character == 2 and skill3_index == 1 else ""))))
	player["typing_zone_time"] = 0.0
	player["typing_zone_level"] = 0
	player["position"] = Vector2(200, ARENA.get_center().y) if slot == 1 else Vector2(1480, ARENA.get_center().y)
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
			configure_loadout(slot, int(setup["character"]), str(setup["big_skill"]), str(setup.get("display_name", "")), int(setup.get("small_skill", 0)), int(setup.get("skill3", 0)))
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
	_update_meteor_impacts(delta)
	_update_hammer_spins(delta)
	_update_lunar_eclipses(delta)
	_update_decoys(delta)
	_update_arithmetic_flashes(delta)
	_update_arithmetic_point_collections(delta)
	_update_perfect_mapping_effects(delta)
	if float(state["time_remaining"]) <= 0.0 and not bool(state["match_over"]):
		_finish_by_hp()

func finish_by_disconnect(leaving_slot: int) -> void:
	state["match_over"] = true
	state["winner_id"] = 2 if leaving_slot == 1 else 1
	state["status_text"] = "対戦相手との接続が切れました。"
	state["arithmetic_point_collections"].clear()

func _update_player(slot: int, delta: float, input: Dictionary) -> void:
	var player: Dictionary = state["players"][slot]
	for key in ["attack_cooldown", "attack_time", "hit_time", "small_cooldown", "big_cooldown", "skill3_cooldown", "buff_time", "invisible_time", "invisible_flicker", "hack_vision_time", "typing_zone_time"]:
		player[key] = maxf(0.0, float(player.get(key, 0.0)) - delta)
	if float(player["buff_time"]) <= 0.0:
		player["buff_speed_multiplier"] = 1.0
		player["attack_damage_buff"] = 0
	if float(player["invisible_time"]) > 0.0 and float(player["invisible_flicker"]) <= 0.0:
		player["invisible_flicker"] = ARITHMETICIAN_INVISIBILITY_FLICKER_INTERVAL
	if float(player.get("hack_vision_time", 0.0)) <= 0.0:
		player["hack_vision_owner_id"] = 0
		player["hack_vision_suppress_interference_points"] = false
	if float(player.get("typing_zone_time", 0.0)) <= 0.0:
		player["typing_zone_level"] = 0
	var move: Vector2 = input.get("move", Vector2.ZERO)
	player["is_moving"] = false
	if float(player["attack_time"]) <= 0.0 and not _is_trident_active(slot) and not _is_lunar_eclipse_active(slot) and move.length_squared() > 0.0:
		var direction := move.normalized()
		player["facing"] = direction
		var focus_multiplier := FOCUS_SPEED_MULTIPLIER if bool(player["focused"]) else 1.0
		var speed := PLAYER_SPEED * focus_multiplier * float(player.get("buff_speed_multiplier", 1.0)) * _arithmetic_movement_multiplier(player) * _hammer_speed_multiplier(slot)
		var next_position := _clamp_to_arena(Vector2(player["position"]) + direction * speed * delta)
		if not _players_overlap(next_position, Vector2(state["players"][_other(slot)]["position"])):
			player["position"] = next_position
			player["is_moving"] = true
	state["players"][slot] = player

func _try_normal_attack(slot: int) -> bool:
	var player: Dictionary = state["players"][slot]
	if bool(player["focused"]) or _is_lunar_eclipse_active(slot) or _typing_zone_level(player) > 0 or float(player["attack_cooldown"]) > 0.0:
		return false
	player["attack_cooldown"] = _normal_attack_cooldown(player)
	player["attack_time"] = NORMAL_DURATION
	var facing: Vector2 = Vector2(player["facing"])
	if facing.length_squared() <= 0.0:
		facing = Vector2.RIGHT
	player["facing"] = facing.normalized()
	player["attack_facing"] = player["facing"]
	state["players"][slot] = player
	_destroy_decoys_in_normal_attack(slot, Vector2(player["position"]), Vector2(player["facing"]))
	var target_slot := _other(slot)
	var target: Dictionary = state["players"][target_slot]
	var offset: Vector2 = Vector2(target["position"]) - Vector2(player["position"])
	if offset.length() <= NORMAL_RANGE and offset.length_squared() > 0.0 and Vector2(player["facing"]).dot(offset.normalized()) >= NORMAL_HALF_ANGLE_DOT:
		_apply_damage(target_slot, _normal_attack_damage(player), "%sの斬撃" % str(player["name"]))
		state["status_text"] = "%sの斬撃が%sに命中！" % [str(player["name"]), str(target["name"])]
	else:
		if _award_hack_vision_miss(slot):
			state["status_text"] = "%sの空振りを解析。妨害ポイント +0.5" % str(player["name"])
		else:
			state["status_text"] = "%sは斬撃を振った。" % str(player["name"])
	return true

func _award_hack_vision_miss(attacker: int) -> bool:
	var affected: Dictionary = state["players"][attacker]
	if float(affected.get("hack_vision_time", 0.0)) <= 0.0:
		return false
	if bool(affected.get("hack_vision_suppress_interference_points", false)):
		return false
	var owner := int(affected.get("hack_vision_owner_id", 0))
	if owner == attacker or not state["players"].has(owner):
		return false
	var source: Dictionary = state["players"][owner]
	if str(source.get("character_id", "")) != "arithmetic":
		return false
	state["arithmetic_point_collections"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "position": Vector2(affected["position"]), "amount": 0.5, "wait_time": 0.0})
	return true

func _start_challenge(slot: int, tier: String) -> bool:
	var challenges: Dictionary = state["challenges"]
	if challenges.has(slot):
		return false
	var player: Dictionary = state["players"][slot]
	if bool(player["focused"]):
		return false
	var character_id := str(player["character_id"])
	if _is_lunar_eclipse_active(slot):
		return false
	if tier == "skill3" and character_id != "blade" and not (character_id == "arithmetic" and str(player.get("skill3_id", "")) == "arithmetic_hack_vision") and not (character_id == "chanter" and str(player.get("skill3_id", "")) in ["chanter_skill3_0", "chanter_lunar_eclipse"]):
		return false
	var cooldown_key := "skill3_cooldown" if tier == "skill3" else ("big_cooldown" if tier == "big" else "small_cooldown")
	if float(player.get(cooldown_key, 0.0)) > 0.0:
		return false
	_challenge_nonce += 1
	var challenge := _make_challenge(slot, tier)
	player["focused"] = true
	player["challenge_elapsed"] = 0.0
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
		if tier == "skill3" and str(player.get("skill3_id", "")) == "typist_golden_time_iii":
			values = GOLDEN_TIME_III_WORDS
			limit = 8.0
			skill = "skill3_typing_golden_time_iii"
		elif tier == "skill3":
			values = SKILL3_WORDS
			limit = 20.0
			skill = "skill3_typing"
		elif tier == "big" and str(player.get("big_skill_id", "")) == "typist_golden_time_ii":
			values = GOLDEN_TIME_II_WORDS
			limit = 5.0
			skill = "big_typing_golden_time_ii"
		elif tier == "big" and str(player.get("big_skill_id", "")) == "typist_keycap_ii":
			values = BIG_II_WORDS
			limit = 7.0
			skill = "big_typing_keycap_ii"
		elif tier == "big":
			values = BIG_WORDS
			limit = 8.0
			skill = "big_typing"
		elif str(player.get("small_skill_id", "")) == "typist_golden_time_i":
			values = GOLDEN_TIME_I_WORDS
			limit = 3.0
			skill = "small_typing_golden_time_i"
		else:
			values = SMALL_WORDS
			skill = "small_typing"
	elif character_id == "arithmetic":
		challenge_type = "arithmetic"
		var uses_perfect_mapping := tier == "big" and str(player.get("big_skill_id", "")) == "arithmetic_perfect_mapping"
		values = ARITH_HACK_VISION if tier == "skill3" else (ARITH_PERFECT_MAPPING if uses_perfect_mapping else (ARITH_BIG if tier == "big" else ARITH_SMALL))
		limit = 15.0 if tier == "skill3" else (12.0 if uses_perfect_mapping else (10.0 if tier == "big" else 7.0))
		skill = "skill3_arithmetic_hack_vision" if tier == "skill3" else ("big_arithmetic_perfect_mapping" if uses_perfect_mapping else ("big_arithmetic" if tier == "big" else "small_arithmetic"))
	else:
		challenge_type = "tracing"
		limit = 0.0
		skill = "skill3_trace_lunar_eclipse" if tier == "skill3" and str(player.get("skill3_id", "")) == "chanter_lunar_eclipse" else ("skill3_trace" if tier == "skill3" else ("big_trace_meteor_shower" if tier == "big" and str(player.get("big_skill_id", "")) == "chanter_big_1" else ("big_trace" if tier == "big" else "small_trace")))
	if challenge_type == "typing" and _typing_zone_level(player) >= 2:
		limit *= TYPIST_GOLDEN_TIME_SCORE_MULTIPLIER
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
		var lunar_eclipse := str(player.get("skill3_id", "")) == "chanter_lunar_eclipse" and tier == "skill3"
		var meteor_shower := tier == "big" and str(player.get("big_skill_id", "")) == "chanter_big_1"
		prompt = "複合紋章をなぞってください" if meteor_shower else ("星形をなぞってください" if tier == "big" or lunar_eclipse else ("渦巻きをなぞってください" if tier == "skill3" or str(player.get("small_skill_id", "")) == "chanter_small_1" else "円をなぞってください"))
		target = _make_meteor_trace_target() if meteor_shower else (_make_lunar_eclipse_trace_target() if lunar_eclipse else _make_trace_target(tier, str(player.get("small_skill_id", ""))))
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
	_apply_typing_zone_input(slot, character)
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
	if not _valid_trace_submission(challenge, trace):
		_end_challenge(slot, false, 0, "なぞり入力が無効です。")
		return true
	challenge["trace"] = trace
	_set_challenge(slot, challenge)
	var result := _trace_evaluator.evaluate(challenge["target"], trace)
	if not bool(result.get("ng", true)) and int(result.get("score", 0)) >= 45:
		_end_challenge(slot, true, int(result["score"]), "")
	else:
		_end_challenge(slot, false, 0, "なぞりに失敗した。")
	return true

func _valid_trace_submission(challenge: Dictionary, trace: PackedVector2Array) -> bool:
	if float(challenge.get("elapsed", 0.0)) < TRACE_MIN_ELAPSED or trace.size() < TRACE_MIN_POINTS:
		return false
	var length := 0.0
	for index in range(1, trace.size()):
		var segment := trace[index].distance_to(trace[index - 1])
		if segment > TRACE_MAX_SEGMENT_LENGTH:
			return false
		length += segment
	return length >= TRACE_MIN_LENGTH

func _cancel_challenge(slot: int) -> bool:
	if _challenge_for(slot).is_empty():
		return false
	_end_challenge(slot, false, 0, "課題を中止した。")
	return true

func _challenge_miss(owner: int, challenge: Dictionary) -> void:
	var player: Dictionary = state["players"][owner]
	player["challenge_errors"] = int(player.get("challenge_errors", 0)) + 1
	challenge["elapsed"] = minf(float(challenge["limit"]), float(challenge["elapsed"]) + _typing_challenge_miss_penalty(player))
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
	if tier == "skill3":
		player["skill3_cooldown"] = _golden_time_cooldown(str(challenge.get("skill", ""))) if str(challenge.get("skill", "")) == "skill3_typing_golden_time_iii" else (ARITHMETICIAN_HACK_VISION_COOLDOWN if str(player.get("character_id", "")) == "arithmetic" else (CHANTER_LUNAR_ECLIPSE_COOLDOWN if str(player.get("skill3_id", "")) == "chanter_lunar_eclipse" else (CHANTER_SKILL3_COOLDOWN if str(player.get("character_id", "")) == "chanter" else SKILL3_COOLDOWN)))
	elif tier == "big":
		if str(player.get("character_id", "")) == "arithmetic":
			player["big_cooldown"] = ARITHMETICIAN_PERFECT_MAPPING_COOLDOWN if str(player.get("big_skill_id", "")) == "arithmetic_perfect_mapping" else ARITHMETIC_BIG_COOLDOWN
		else:
			player["big_cooldown"] = _golden_time_cooldown(str(challenge.get("skill", ""))) if str(challenge.get("skill", "")) == "big_typing_golden_time_ii" else (7.0 if str(player.get("big_skill_id", "")) == "typist_keycap_ii" else (CHANTER_METEOR_SHOWER_COOLDOWN if str(player.get("big_skill_id", "")) == "chanter_big_1" else (CHANTER_SKILL2_COOLDOWN if str(player.get("character_id", "")) == "chanter" else BIG_COOLDOWN)))
	else:
		player["small_cooldown"] = _golden_time_cooldown(str(challenge.get("skill", ""))) if str(challenge.get("skill", "")) == "small_typing_golden_time_i" else (CHANTER_SKILL1B_COOLDOWN if str(player.get("small_skill_id", "")) == "chanter_small_1" else TYPING_COOLDOWN)
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
		if str(challenge.get("skill", "")).contains("golden_time"):
			_activate_typing_zone(owner, _typing_zone_level_for_skill(str(challenge["skill"])), score)
		elif tier == "skill3":
			state["hammer_spins"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "score": score, "angle": 0.0, "lifetime": _hammer_duration(score), "hit_timer": 0.0, "keycap_timer": 0.5})
		elif tier == "big" and str(player.get("big_skill_id", "")) == "typist_trident":
			state["trident_impacts"].append({"impact_id": _next_trident_impact_id, "presentation_id": _take_presentation_id(), "owner_id": owner, "origin": Vector2(player["position"]), "facing": Vector2(player["facing"]), "score": score, "elapsed": 0.0, "strike_duration": 1.0, "duration": 1.9, "released": false})
			_next_trident_impact_id += 1
		else:
			var interval := 0.3 if tier == "big" else 0.5
			var typed := str(challenge.get("typed", ""))
			for index in typed.length():
				_spawn_projectile(owner, score, false, 0.0, float(index) * interval, typed[index])
	elif character_id == "arithmetic":
		if tier == "small":
			_spawn_decoys(owner, score)
		elif tier == "skill3":
			_spawn_hack_vision_projectile(owner, score)
		elif str(challenge.get("skill", "")) == "big_arithmetic_perfect_mapping":
			_spawn_perfect_mapping(owner, score)
		else:
			player = state["players"][owner]
			player["buff_time"] = lerpf(10.0, 20.0, float(score) / 100.0)
			player["buff_speed_multiplier"] = 1.25
			player["attack_damage_buff"] = 1
			player["invisible_time"] = player["buff_time"]
			player["invisible_flicker"] = 0.0
			state["players"][owner] = player
	else:
		if tier == "skill3":
			if str(player.get("skill3_id", "")) == "chanter_lunar_eclipse":
				_spawn_lunar_eclipse(owner, score)
			else:
				_spawn_chanter_skill3_volley(owner, score)
		elif tier == "small" and str(player.get("small_skill_id", "")) == "chanter_small_1":
			_spawn_chanter_clockwise_volley(owner, score)
		elif tier == "small":
			for index in 3:
				_spawn_zone(owner, score, float(index) * 1.5, 2.0 if index < 2 else 2.5)
		elif str(player.get("big_skill_id", "")) == "chanter_big_1":
			_spawn_meteor_shower(owner, score)
		else:
			for cycle in _chanter_skill2_cycle_count(score):
				for shot in 16:
					var shot_delay := float(cycle * 16 + shot) * 0.08
					_spawn_projectile(owner, score, true, -PI / 2.0 + TAU * float(shot) / 16.0, shot_delay, "", true)
					_spawn_projectile(owner, score, true, PI / 2.0 - TAU * float(shot) / 16.0, shot_delay, "", true)

func _perfect_mapping_copy_candidates(owner: int) -> Array[String]:
	var target := _other(owner)
	if not state["players"].has(target):
		return []
	var player: Dictionary = state["players"][target]
	var candidates: Array[String] = []
	for skill_id in [str(player.get("small_skill_id", "")), str(player.get("big_skill_id", "")), str(player.get("skill3_id", ""))]:
		if _is_perfect_mapping_copyable(skill_id):
			candidates.append(skill_id)
	return candidates

func _is_perfect_mapping_copyable(skill_id: String) -> bool:
	return skill_id in ["blade_small_0", "typist_keycap_ii", "typist_trident", "typist_hammer_spin", "arithmetic_small_0", "arithmetic_big_0", "arithmetic_hack_vision", "chanter_small_0", "chanter_small_1", "chanter_big_0", "chanter_big_1", "chanter_skill3_0", "chanter_lunar_eclipse"]

func _spawn_perfect_mapping(owner: int, score: int) -> void:
	var candidates := _perfect_mapping_copy_candidates(owner)
	if candidates.is_empty():
		state["perfect_mapping_effects"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "copied_skill": "", "tile_count": 0, "no_selection": true, "score": score, "elapsed": 0.0, "duration": 1.2})
		return
	var copied_skill: String = candidates[randi_range(0, candidates.size() - 1)]
	state["perfect_mapping_effects"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "copied_skill": copied_skill, "tile_count": candidates.size(), "no_selection": false, "score": score, "elapsed": 0.0, "duration": 1.2})

func _spawn_copied_skill(owner: int, score: int, copied_skill: String) -> void:
	var player: Dictionary = state["players"][owner]
	if copied_skill == "blade_small_0" or copied_skill == "typist_keycap_ii":
		var words := SMALL_WORDS if copied_skill == "blade_small_0" else BIG_II_WORDS
		var word: String = str(words[randi_range(0, words.size() - 1)])
		var interval := 0.5 if copied_skill == "blade_small_0" else 0.3
		for index in range(word.length()):
			_spawn_projectile(owner, score, false, 0.0, float(index) * interval, word[index])
	elif copied_skill == "typist_trident":
		state["trident_impacts"].append({"impact_id": _next_trident_impact_id, "presentation_id": _take_presentation_id(), "owner_id": owner, "origin": Vector2(player["position"]), "facing": Vector2(player["facing"]), "score": score, "elapsed": 0.0, "strike_duration": 1.0, "duration": 1.9, "released": false})
		_next_trident_impact_id += 1
	elif copied_skill == "typist_hammer_spin":
		state["hammer_spins"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "score": score, "angle": 0.0, "lifetime": _hammer_duration(score), "hit_timer": 0.0, "keycap_timer": 0.5})
	elif copied_skill == "arithmetic_small_0":
		_spawn_decoys(owner, score, true)
	elif copied_skill == "arithmetic_big_0":
		player["buff_time"] = lerpf(10.0, 20.0, float(score) / 100.0)
		player["buff_speed_multiplier"] = 1.25
		player["attack_damage_buff"] = 1
		player["invisible_time"] = player["buff_time"]
		player["invisible_flicker"] = 0.0
		state["players"][owner] = player
	elif copied_skill == "arithmetic_hack_vision":
		_spawn_hack_vision_projectile(owner, score, true)
	elif copied_skill == "chanter_small_0":
		for index in 3:
			_spawn_zone(owner, score, float(index) * 1.5, 2.0 if index < 2 else 2.5)
	elif copied_skill == "chanter_small_1":
		_spawn_chanter_clockwise_volley(owner, score)
	elif copied_skill == "chanter_big_0":
		for cycle in _chanter_skill2_cycle_count(score):
			for shot in 16:
				var shot_delay := float(cycle * 16 + shot) * 0.08
				_spawn_projectile(owner, score, true, -PI / 2.0 + TAU * float(shot) / 16.0, shot_delay, "", true)
				_spawn_projectile(owner, score, true, PI / 2.0 - TAU * float(shot) / 16.0, shot_delay, "", true)
	elif copied_skill == "chanter_big_1":
		_spawn_meteor_shower(owner, score)
	elif copied_skill == "chanter_skill3_0":
		_spawn_chanter_skill3_volley(owner, score)
	elif copied_skill == "chanter_lunar_eclipse":
		_spawn_lunar_eclipse(owner, score)

func _chanter_skill2_cycle_count(score: int) -> int:
	if score <= 30:
		return 1
	if score <= 50:
		return 2
	if score <= 75:
		return 3
	return 4

func _spawn_chanter_clockwise_volley(owner: int, score: int) -> void:
	for cycle in _chanter_skill2_cycle_count(score):
		for shot in 16:
			_spawn_projectile(owner, score, true, -PI / 2.0 + TAU * float(shot) / 16.0, float(cycle * 16 + shot) * 0.08, "", true)

func _spawn_chanter_skill3_volley(owner: int, score: int) -> void:
	var player: Dictionary = state["players"][owner]
	var cycle_count := _chanter_skill2_cycle_count(score)
	var projectile_count_before: int = state["skill_projectiles"].size()
	for cycle in cycle_count:
		for shot in 16:
			var shot_delay := float(cycle * 16 + shot) * 0.08
			var angle := TAU * float(shot) / 16.0
			_spawn_projectile(owner, score, true, -PI / 2.0 + angle, shot_delay, "", true, true)
			_spawn_projectile(owner, score, true, PI / 2.0 + angle, shot_delay, "", true, true)
			_spawn_projectile(owner, score, true, -angle, shot_delay, "", true, true)
			_spawn_projectile(owner, score, true, PI - angle, shot_delay, "", true, true)
	var projectile_count: int = state["skill_projectiles"].size() - projectile_count_before
	if projectile_count <= 0:
		return
	_pending_visual_presentations.append({
		"presentation_id": _take_presentation_id(),
		"kind": "chanter_skill3_volley",
		"state": {
			"owner_id": owner,
			"score": score,
			"cycle_count": cycle_count,
			"projectile_count": projectile_count,
			"facing": Vector2(player["facing"]),
		},
	})

func _spawn_meteor_shower(owner: int, score: int) -> void:
	var target := _other(owner)
	if not state["players"].has(target):
		return
	for pair_index in METEOR_PAIR_COUNT:
		for meteor_index in METEORS_PER_PAIR:
			state["meteor_impacts"].append({"impact_id": _next_meteor_impact_id, "owner_id": owner, "position": _meteor_landing_position(owner, target), "delay": float(pair_index) * METEOR_PAIR_INTERVAL, "elapsed": 0.0, "fall_duration": METEOR_FALL_DURATION, "ripple_duration": METEOR_RIPPLE_DURATION, "damage": 4 + floori(float(score) * 0.08), "landed": false})
			_next_meteor_impact_id += 1

func _meteor_landing_position(owner: int, target: int) -> Vector2:
	var target_position := Vector2(state["players"][target]["position"])
	var owner_position := Vector2(state["players"][owner]["position"])
	for _attempt in 12:
		var candidate := _clamp_to_arena(target_position + Vector2.from_angle(randf() * TAU) * randf_range(METEOR_TARGET_MIN_DISTANCE, METEOR_TARGET_MAX_DISTANCE))
		if candidate.distance_to(owner_position) > METEOR_OWNER_SAFE_RADIUS:
			return candidate
	var away_from_owner := (target_position - owner_position).normalized()
	if away_from_owner.length_squared() <= 0.001:
		away_from_owner = Vector2.RIGHT
	return _clamp_to_arena(target_position + away_from_owner * METEOR_TARGET_MAX_DISTANCE)

func _spawn_projectile(owner: int, score: int, big: bool, angle_offset: float, delay: float, chip: String = "", fixed_direction: bool = false, client_predicted: bool = false) -> void:
	if state["skill_projectiles"].size() >= MAX_PROJECTILES:
		return
	var player: Dictionary = state["players"][owner]
	var facing := Vector2(player["facing"]).rotated(angle_offset)
	# Chanter's large-skill projectiles are radial shots. They must retain the
	# direction assigned above instead of using the delayed, target-seeking
	# launch path for typist projectiles.
	state["skill_projectiles"].append({"projectile_id": _next_projectile_id, "presentation_id": 0 if client_predicted else _take_presentation_id(), "owner_id": owner, "position": Vector2(player["position"]) + facing * (PLAYER_RADIUS + PROJECTILE_RADIUS), "velocity": facing * (300.0 if big else 550.0), "damage": 3 + floori(float(score) * 0.05) if fixed_direction else ((50 if big else 5) + (roundi(float(score) * 0.2) if big else floori(float(score) * 0.1))), "lifetime": 5.0 if big else 2.0, "piercing": big, "delay": delay, "chip": chip, "launched": big and not fixed_direction, "homing": not big and score >= 80, "homing_time": 0.7 if not big and score >= 80 else 0.0, "initial_angle": facing.angle(), "key_cap": not big, "fixed_direction": fixed_direction, "client_predicted": client_predicted})
	_next_projectile_id += 1


func take_visual_presentations() -> Array[Dictionary]:
	var presentations := _pending_visual_presentations.duplicate(true)
	_pending_visual_presentations.clear()
	return presentations


func _typing_zone_level(player: Dictionary) -> int:
	return int(player.get("typing_zone_level", 0)) if float(player.get("typing_zone_time", 0.0)) > 0.0 else 0


func _typing_challenge_miss_penalty(player: Dictionary) -> float:
	return TYPIST_GOLDEN_TIME_MISS_PENALTY if _typing_zone_level(player) > 0 else CHALLENGE_MISS_TIME_PENALTY


func _typing_zone_level_for_skill(skill: String) -> int:
	if skill.ends_with("golden_time_iii"):
		return 3
	if skill.ends_with("golden_time_ii"):
		return 2
	return 1


func _golden_time_cooldown(skill: String) -> float:
	match _typing_zone_level_for_skill(skill):
		2: return TYPIST_GOLDEN_TIME_II_COOLDOWN
		3: return TYPIST_GOLDEN_TIME_III_COOLDOWN
		_: return TYPIST_GOLDEN_TIME_I_COOLDOWN


func _typing_zone_duration(level: int, score: int) -> float:
	if level == 1:
		return 30.0 if score <= 30 else (45.0 if score <= 70 else 60.0)
	if level == 2:
		return 40.0 if score <= 30 else (50.0 if score <= 70 else 75.0)
	return 50.0 if score <= 30 else (60.0 if score <= 70 else 90.0)


func _activate_typing_zone(owner: int, level: int, score: int) -> void:
	var player: Dictionary = state["players"][owner]
	player["typing_zone_level"] = level
	player["typing_zone_time"] = _typing_zone_duration(level, score)
	state["players"][owner] = player


func _apply_typing_zone_input(owner: int, character: String) -> void:
	var player: Dictionary = state["players"][owner]
	var level := _typing_zone_level(player)
	if level <= 0 or state["skill_projectiles"].size() >= MAX_PROJECTILES:
		return
	var target := _other(owner)
	var direction := (Vector2(state["players"][target]["position"]) - Vector2(player["position"])).normalized()
	if direction.length_squared() <= 0.0:
		direction = Vector2(player.get("facing", Vector2.RIGHT))
	state["skill_projectiles"].append({"projectile_id": _next_projectile_id, "presentation_id": _take_presentation_id(), "owner_id": owner, "position": Vector2(player["position"]) + direction * (PLAYER_RADIUS + PROJECTILE_RADIUS), "velocity": direction * 550.0, "damage": 3, "lifetime": 2.0, "piercing": false, "delay": 0.0, "chip": character, "launched": true, "homing": level >= 2, "homing_time": 2.0 if level >= 2 else 0.0, "initial_angle": direction.angle(), "key_cap": true})
	_next_projectile_id += 1
	if level >= 3:
		state["shockwaves"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "origin": Vector2(player["position"]), "delay": 0.0, "elapsed": 0.0, "radius": 0.0, "duration": 1.0, "speed": 200.0, "damage": 1, "knockback": 0.0, "hit": false})

func _spawn_hack_vision_projectile(owner: int, score: int, suppress_interference_points: bool = false) -> void:
	var player: Dictionary = state["players"][owner]
	var target := _other(owner)
	var direction := (Vector2(state["players"][target]["position"]) - Vector2(player["position"])).normalized()
	if direction.length_squared() <= 0.0:
		direction = Vector2(player["facing"])
	state["skill_projectiles"].append({"projectile_id": _next_projectile_id, "presentation_id": _take_presentation_id(), "owner_id": owner, "position": Vector2(player["position"]) + direction * (PLAYER_RADIUS + PROJECTILE_RADIUS), "velocity": direction * 420.0, "damage": 0, "lifetime": 5.0, "piercing": false, "delay": 0.0, "chip": "", "launched": true, "homing": true, "homing_time": 5.0, "initial_angle": direction.angle(), "key_cap": false, "hack_vision": true, "hack_duration": float(score) * 0.9, "suppress_interference_points": suppress_interference_points})
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
		if bool(projectile.get("fixed_direction", false)) and not bool(projectile["launched"]):
			var fixed_source := Vector2(state["players"][owner]["position"])
			var fixed_direction := Vector2(projectile["velocity"]).normalized()
			projectile["position"] = fixed_source + fixed_direction * (PLAYER_RADIUS + PROJECTILE_RADIUS)
			projectile["launched"] = true
		elif not bool(projectile["launched"]):
			var source := Vector2(state["players"][owner]["position"])
			var direction := (Vector2(state["players"][target]["position"]) - source).normalized()
			projectile["position"] = source + direction * (PLAYER_RADIUS + PROJECTILE_RADIUS)
			projectile["velocity"] = direction * 550.0
			projectile["launched"] = true
		if bool(projectile["homing"]) and float(projectile["homing_time"]) > 0.0:
			var desired := (Vector2(state["players"][target]["position"]) - Vector2(projectile["position"])).normalized()
			if bool(projectile.get("hack_vision", false)):
				# Hack Vision is a guaranteed-homing interference projectile: its heading
				# always matches the target's current direction.
				projectile["velocity"] = desired * Vector2(projectile["velocity"]).length()
			else:
				projectile["velocity"] = Vector2(projectile["velocity"]).lerp(desired * Vector2(projectile["velocity"]).length(), minf(1.0, 0.6 * delta))
			projectile["homing_time"] = maxf(0.0, float(projectile["homing_time"]) - delta)
		projectile["position"] = Vector2(projectile["position"]) + Vector2(projectile["velocity"]) * delta
		projectile["lifetime"] = float(projectile["lifetime"]) - delta
		var destroyed_decoy := _destroy_decoys_in_typist_hammer_shockwave_projectile(owner, projectile) if bool(projectile.get("typist_hammer_shockwave", false)) else _destroy_decoy_at_point(owner, Vector2(projectile["position"]), PROJECTILE_RADIUS)
		if not bool(projectile.get("hack_vision", false)) and destroyed_decoy:
			if not bool(projectile["piercing"]):
				state["skill_projectiles"].remove_at(index)
				continue
		var hit_target := _typist_hammer_shockwave_projectile_hits_player(projectile, target) if bool(projectile.get("typist_hammer_shockwave", false)) else _point_hits_player(Vector2(projectile["position"]), target, PROJECTILE_RADIUS)
		if hit_target:
			if bool(projectile.get("hack_vision", false)):
				var target_player: Dictionary = state["players"][target]
				target_player["hack_vision_time"] = maxf(float(target_player.get("hack_vision_time", 0.0)), float(projectile.get("hack_duration", 0.0)))
				target_player["hack_vision_owner_id"] = owner
				target_player["hack_vision_suppress_interference_points"] = bool(projectile.get("suppress_interference_points", false))
				state["players"][target] = target_player
				state["status_text"] = "%sの視界にノイズが走った！" % str(target_player["name"])
			elif not bool(projectile.get("hit_target", false)):
				_apply_damage(target, int(projectile["damage"]), "スキル弾")
				projectile["hit_target"] = true
			if not bool(projectile["piercing"]):
				state["skill_projectiles"].remove_at(index)
				continue
		if float(projectile["lifetime"]) <= 0.0 or not ARENA.grow(40.0).has_point(Vector2(projectile["position"])):
			state["skill_projectiles"].remove_at(index)
		else:
			state["skill_projectiles"][index] = projectile

func _spawn_decoys(owner: int, score: int, suppress_interference_points: bool = false) -> void:
	var decoys: Array = state["decoys"]
	decoys.clear()
	var player: Dictionary = state["players"][owner]
	var count := _arithmetic_decoy_count(score)
	var lifetime := _arithmetic_decoy_lifetime(score)
	var radius_range := _arithmetic_decoy_radius_range(score)
	for index in count:
		var position_angle := randf_range(0.0, TAU)
		var radius := randf_range(radius_range.x, radius_range.y)
		var movement_offset_angle := TAU * float(randi_range(0, 7)) / 8.0
		decoys.append({"presentation_id": _take_presentation_id(), "owner_id": owner, "visual_id": "arithmetician", "facing": Vector2(player["facing"]).rotated(movement_offset_angle), "position": _clamp_to_arena(Vector2(player["position"]) + Vector2.from_angle(position_angle) * radius), "owner_position": Vector2(player["position"]), "movement_offset_angle": movement_offset_angle, "is_moving": false, "animation_phase": randf_range(0.0, 1.0), "lifetime": lifetime, "noise_timer": randf_range(ARITHMETICIAN_DECOY_MIN_NOISE_INTERVAL, ARITHMETICIAN_DECOY_MAX_NOISE_INTERVAL), "noise_time": 0.0, "noise_phase": randf_range(0.0, TAU), "flash_time": ARITHMETICIAN_FLASH_DURATION, "suppress_interference_points": suppress_interference_points})
	player["buff_time"] = lifetime
	player["buff_speed_multiplier"] = 1.1
	player["attack_damage_buff"] = 5
	state["players"][owner] = player
	state["arithmetic_flashes"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "center": Vector2(player["position"]), "lifetime": ARITHMETICIAN_FLASH_DURATION, "duration": ARITHMETICIAN_FLASH_DURATION})

func _arithmetic_decoy_count(score: int) -> int:
	if score <= 59:
		return 10 + maxi(score - 50, 0)
	if score <= 69:
		return 20 + score - 60
	if score <= 79:
		return 30 + score - 70
	if score <= 89:
		return 45 + score - 80
	return 70 + score - 90

func _arithmetic_decoy_lifetime(score: int) -> float:
	return 20.0 if score <= 59 else (30.0 if score <= 79 else 40.0)

func _arithmetic_decoy_radius_range(score: int) -> Vector2:
	if score <= 59:
		return Vector2(10.0, 500.0)
	if score <= 79:
		return Vector2(20.0, 700.0)
	return Vector2(20.0, 1000.0)

func _arithmetic_movement_multiplier(player: Dictionary) -> float:
	if str(player.get("character_id", "")) != "arithmetic":
		return 1.0
	var a := float(player.get("arithmetic_interference_multiplier", 1.0))
	return 1.0 + (a - 1.0) * 0.1

func _normal_attack_cooldown(player: Dictionary) -> float:
	if str(player.get("character_id", "")) != "arithmetic":
		return NORMAL_COOLDOWN
	return NORMAL_COOLDOWN / maxf(float(player.get("arithmetic_interference_multiplier", 1.0)), 0.1)

func _normal_attack_damage(player: Dictionary) -> int:
	var attack_power := float(player.get("normal_damage", 0)) + float(player.get("attack_damage_buff", 0))
	if str(player.get("character_id", "")) == "arithmetic":
		attack_power *= float(player.get("arithmetic_interference_multiplier", 1.0))
	return roundi(attack_power)

func _destroy_decoys_in_normal_attack(attacker: int, attacker_position: Vector2, facing: Vector2) -> void:
	for index in range(state["decoys"].size() - 1, -1, -1):
		var decoy: Dictionary = state["decoys"][index]
		if int(decoy.get("owner_id", 0)) == attacker:
			continue
		var offset := Vector2(decoy["position"]) - attacker_position
		if offset.length() <= NORMAL_RANGE and offset.length_squared() > 0.0 and facing.dot(offset.normalized()) >= NORMAL_HALF_ANGLE_DOT:
			_destroy_decoy_at_index(index)

func _destroy_decoy_at_point(attacker: int, point: Vector2, padding: float = 0.0) -> bool:
	for index in range(state["decoys"].size() - 1, -1, -1):
		var decoy: Dictionary = state["decoys"][index]
		if int(decoy.get("owner_id", 0)) != attacker and Vector2(decoy["position"]).distance_to(point) <= ARITHMETICIAN_DECOY_HIT_RADIUS + padding:
			_destroy_decoy_at_index(index)
			return true
	return false

func _destroy_decoys_in_radius(attacker: int, center: Vector2, radius: float) -> void:
	for index in range(state["decoys"].size() - 1, -1, -1):
		var decoy: Dictionary = state["decoys"][index]
		if int(decoy.get("owner_id", 0)) != attacker and Vector2(decoy["position"]).distance_to(center) <= radius + ARITHMETICIAN_DECOY_HIT_RADIUS:
			_destroy_decoy_at_index(index)

func _destroy_decoys_in_typist_hammer_shockwave_projectile(attacker: int, projectile: Dictionary) -> bool:
	var destroyed := false
	for index in range(state["decoys"].size() - 1, -1, -1):
		var decoy: Dictionary = state["decoys"][index]
		if int(decoy.get("owner_id", 0)) != attacker and TypistHammerShockwaveHitboxData.intersects_circle(projectile, Vector2(decoy["position"]), ARITHMETICIAN_DECOY_HIT_RADIUS):
			_destroy_decoy_at_index(index)
			destroyed = true
	return destroyed


func _destroy_decoys_near_segment(attacker: int, start: Vector2, end: Vector2, padding: float) -> void:
	for index in range(state["decoys"].size() - 1, -1, -1):
		var decoy: Dictionary = state["decoys"][index]
		if int(decoy.get("owner_id", 0)) != attacker and _point_hits_segment(Vector2(decoy["position"]), start, end, padding + ARITHMETICIAN_DECOY_HIT_RADIUS):
			_destroy_decoy_at_index(index)

func _destroy_decoy_at_index(index: int) -> void:
	var decoy: Dictionary = state["decoys"][index]
	state["decoys"].remove_at(index)
	if bool(decoy.get("suppress_interference_points", false)):
		return
	var owner := int(decoy.get("owner_id", 0))
	if not state["players"].has(owner):
		return
	var player: Dictionary = state["players"][owner]
	if str(player.get("character_id", "")) != "arithmetic":
		return
	state["arithmetic_point_collections"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "position": Vector2(decoy["position"]), "amount": ARITHMETICIAN_DECOY_INTERFERENCE_POINTS, "wait_time": ARITHMETICIAN_POINT_COLLECTION_WAIT})

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
		decoy["noise_timer"] = float(decoy.get("noise_timer", ARITHMETICIAN_DECOY_MIN_NOISE_INTERVAL)) - delta
		decoy["noise_time"] = maxf(0.0, float(decoy.get("noise_time", 0.0)) - delta)
		if float(decoy["noise_timer"]) <= 0.0:
			decoy["noise_timer"] = randf_range(ARITHMETICIAN_DECOY_MIN_NOISE_INTERVAL, ARITHMETICIAN_DECOY_MAX_NOISE_INTERVAL)
			decoy["noise_time"] = ARITHMETICIAN_DECOY_NOISE_DURATION
		decoy["lifetime"] = float(decoy["lifetime"]) - delta
		if float(decoy["lifetime"]) <= 0.0:
			state["decoys"].remove_at(index)
		else:
			state["decoys"][index] = decoy

func _update_arithmetic_flashes(delta: float) -> void:
	for index in range(state["arithmetic_flashes"].size() - 1, -1, -1):
		var flash: Dictionary = state["arithmetic_flashes"][index]
		flash["lifetime"] = maxf(0.0, float(flash["lifetime"]) - delta)
		if float(flash["lifetime"]) <= 0.0:
			state["arithmetic_flashes"].remove_at(index)
		else:
			state["arithmetic_flashes"][index] = flash

func _update_perfect_mapping_effects(delta: float) -> void:
	for index in range(state["perfect_mapping_effects"].size() - 1, -1, -1):
		var effect: Dictionary = state["perfect_mapping_effects"][index]
		effect["elapsed"] = float(effect.get("elapsed", 0.0)) + delta
		if float(effect["elapsed"]) >= float(effect.get("duration", 1.2)):
			if not bool(effect.get("no_selection", false)):
				_spawn_copied_skill(int(effect["owner_id"]), int(effect.get("score", 0)), str(effect["copied_skill"]))
			state["perfect_mapping_effects"].remove_at(index)
		else:
			state["perfect_mapping_effects"][index] = effect

func _update_arithmetic_point_collections(delta: float) -> void:
	for index in range(state["arithmetic_point_collections"].size() - 1, -1, -1):
		var collection: Dictionary = state["arithmetic_point_collections"][index]
		var owner := int(collection.get("owner_id", 0))
		if not state["players"].has(owner):
			state["arithmetic_point_collections"].remove_at(index)
			continue
		var previous_wait_time := float(collection.get("wait_time", 0.0))
		var wait_time := maxf(0.0, previous_wait_time - delta)
		collection["wait_time"] = wait_time
		if wait_time > 0.0:
			state["arithmetic_point_collections"][index] = collection
			continue
		var player: Dictionary = state["players"][owner]
		var target := Vector2(player["position"]) + Vector2(0.0, -18.0)
		var flight_delta := maxf(0.0, delta - previous_wait_time)
		collection["position"] = Vector2(collection["position"]).move_toward(target, ARITHMETICIAN_POINT_COLLECTION_SPEED * flight_delta)
		if Vector2(collection["position"]).distance_to(target) > ARITHMETICIAN_POINT_COLLECTION_ARRIVAL_DISTANCE:
			state["arithmetic_point_collections"][index] = collection
			continue
		player["arithmetic_interference_multiplier"] = snappedf(float(player.get("arithmetic_interference_multiplier", 1.0)) + float(collection.get("amount", 0.0)), 0.1)
		state["players"][owner] = player
		state["arithmetic_point_collections"].remove_at(index)

func _spawn_zone(owner: int, score: int, delay: float, duration: float) -> void:
	state["magic_zones"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "position": Vector2.ZERO, "lifetime": 0.0, "active_duration": duration, "delay": delay, "elapsed": 0.0, "warning_duration": CHANTER_ZONE_WARNING_DURATION, "growth_frame_duration": 1.0 / 60.0, "damage_interval": CHANTER_ZONE_DAMAGE_INTERVAL, "next_damage_time": CHANTER_ZONE_WARNING_DURATION, "damage": 1 + roundi(float(score) * 0.06), "spawned": false})

func _update_zones(delta: float) -> void:
	for index in range(state["magic_zones"].size() - 1, -1, -1):
		var zone: Dictionary = state["magic_zones"][index]
		zone["delay"] = float(zone["delay"]) - delta
		var target := _other(int(zone["owner_id"]))
		if not bool(zone["spawned"]) and float(zone["delay"]) <= 0.0:
			zone["position"] = state["players"][target]["position"]
			zone["spawned"] = true
			zone["lifetime"] = zone["active_duration"]
			zone["elapsed"] = 0.0
		if bool(zone["spawned"]):
			zone["elapsed"] = float(zone.get("elapsed", 0.0)) + delta
			zone["lifetime"] = maxf(0.0, float(zone["lifetime"]) - delta)
			_destroy_decoys_in_radius(int(zone["owner_id"]), Vector2(zone["position"]), CHANTER_ZONE_RADIUS)
			var active_duration := float(zone["active_duration"])
			var next_damage_time := float(zone.get("next_damage_time", CHANTER_ZONE_WARNING_DURATION))
			var damage_interval := float(zone.get("damage_interval", CHANTER_ZONE_DAMAGE_INTERVAL))
			while next_damage_time < active_duration and float(zone["elapsed"]) >= next_damage_time:
				if _point_hits_chanter_zone(Vector2(zone["position"]), target):
					_apply_damage(target, int(zone["damage"]), "月柱・昇華")
				next_damage_time += damage_interval
			zone["next_damage_time"] = next_damage_time
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

func _update_meteor_impacts(delta: float) -> void:
	for index in range(state["meteor_impacts"].size() - 1, -1, -1):
		var impact: Dictionary = state["meteor_impacts"][index]
		var prior_delay := float(impact.get("delay", 0.0))
		impact["delay"] = maxf(0.0, prior_delay - delta)
		impact["elapsed"] = float(impact.get("elapsed", 0.0)) + (delta if prior_delay <= 0.0 else maxf(0.0, delta - prior_delay))
		if not bool(impact.get("landed", false)) and float(impact["elapsed"]) >= float(impact.get("fall_duration", METEOR_FALL_DURATION)):
			impact["landed"] = true
			var owner := int(impact["owner_id"])
			var target := _other(owner)
			if state["players"].has(target) and _point_hits_player(Vector2(impact["position"]), target, METEOR_DAMAGE_RADIUS):
				_apply_damage(target, int(impact["damage"]), "流月雨")
		if float(impact["elapsed"]) >= float(impact.get("fall_duration", METEOR_FALL_DURATION)) + float(impact.get("ripple_duration", METEOR_RIPPLE_DURATION)):
			state["meteor_impacts"].remove_at(index)
		else:
			state["meteor_impacts"][index] = impact

func _release_trident(impact: Dictionary) -> void:
	var owner := int(impact["owner_id"])
	var score := int(impact["score"])
	var facing := Vector2(impact["facing"]).normalized()
	var landing := Vector2(impact["origin"]) + facing * (120.0 + float(score) * 0.25)
	var target := _other(owner)
	_destroy_decoy_at_point(owner, landing, 30.0)
	if _point_hits_player(landing, target, 30.0):
		_apply_damage(target, _trident_landing_damage(score), "三叉震槌の直撃")
	for angle in [-PI / 2.0, -PI / 3.0, 0.0, PI / 3.0, PI / 2.0]:
		_spawn_projectile_from(owner, score, landing, facing.rotated(angle), true)
	if score >= 50:
		for index in 3:
			state["shockwaves"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "origin": landing, "delay": float(index) * 0.5, "elapsed": 0.0, "radius": 0.0, "duration": 1.0, "damage": 0 if score < 80 else 12 + roundi(float(score) * 0.2), "knockback": lerpf(18.0, 48.0, float(score) / 100.0), "hit": false})

func _spawn_projectile_from(owner: int, score: int, position_value: Vector2, facing: Vector2, big: bool) -> void:
	if state["skill_projectiles"].size() >= MAX_PROJECTILES:
		return
	state["skill_projectiles"].append({"projectile_id": _next_projectile_id, "presentation_id": _take_presentation_id(), "owner_id": owner, "position": position_value + facing * (PLAYER_RADIUS + PROJECTILE_RADIUS), "velocity": facing * 300.0, "damage": 50 + roundi(float(score) * 0.2), "lifetime": 5.0, "piercing": big, "delay": 0.0, "chip": "", "launched": true, "homing": false, "homing_time": 0.0, "initial_angle": facing.angle(), "key_cap": false, "typist_hammer_shockwave": true})
	_next_projectile_id += 1

func _update_shockwaves(delta: float) -> void:
	for index in range(state["shockwaves"].size() - 1, -1, -1):
		var wave: Dictionary = state["shockwaves"][index]
		wave["delay"] = float(wave["delay"]) - delta
		if float(wave["delay"]) <= 0.0:
			wave["elapsed"] = float(wave["elapsed"]) + delta
			wave["radius"] = float(wave.get("speed", 150.0)) * float(wave["elapsed"])
			_destroy_decoys_in_radius(int(wave["owner_id"]), Vector2(wave["origin"]), float(wave["radius"]))
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
		_destroy_decoys_near_segment(owner, Vector2(player["position"]), tip, PLAYER_RADIUS + 12.0)
		var target := _other(owner)
		if float(spin["hit_timer"]) <= 0.0 and _point_hits_segment(Vector2(state["players"][target]["position"]), Vector2(player["position"]), tip, PLAYER_RADIUS + 12.0):
			_apply_damage(target, 10 + floori(float(spin["score"]) * 0.2), "黄金大旋槌")
			spin["hit_timer"] = 0.28
		if int(spin["score"]) >= 60 and float(spin["keycap_timer"]) <= 0.0:
			if state["skill_projectiles"].size() < MAX_PROJECTILES:
				var keycap_facing := Vector2(player["facing"])
				state["skill_projectiles"].append({"projectile_id": _next_projectile_id, "presentation_id": _take_presentation_id(), "owner_id": owner, "position": tip, "velocity": keycap_facing * 800.0, "damage": 10, "lifetime": 3.0, "piercing": false, "delay": 0.0, "chip": "", "launched": true, "homing": false, "homing_time": 0.0, "initial_angle": keycap_facing.angle(), "key_cap": true})
				_next_projectile_id += 1
			spin["keycap_timer"] = 0.5
		if float(spin["lifetime"]) <= 0.0:
			state["hammer_spins"].remove_at(index)
		else:
			state["hammer_spins"][index] = spin

func _spawn_lunar_eclipse(owner: int, score: int) -> void:
	var player: Dictionary = state["players"][owner]
	var origin := Vector2(player["position"])
	var facing := Vector2(player["facing"]).normalized()
	if facing.length_squared() <= 0.0:
		facing = Vector2.RIGHT
	state["lunar_eclipses"].append({"presentation_id": _take_presentation_id(), "owner_id": owner, "origin": origin, "facing": facing, "center": _lunar_eclipse_center(origin, facing), "elapsed": 0.0, "duration": LUNAR_ECLIPSE_DURATION, "score": score, "visual_radius": 150.0 + floori(float(score) * 1.2), "pull_amount": 6.0 + floori(float(score) * 0.16), "next_pull_time": 0.0, "next_laser_hit_time": LUNAR_ECLIPSE_LASER_START_TIME, "damage": 4 + floori(float(score) * 0.13)})

func _update_lunar_eclipses(delta: float) -> void:
	for index in range(state["lunar_eclipses"].size() - 1, -1, -1):
		var eclipse: Dictionary = state["lunar_eclipses"][index]
		eclipse["elapsed"] = float(eclipse["elapsed"]) + delta
		var owner := int(eclipse["owner_id"])
		var target := _other(owner)
		var elapsed := float(eclipse["elapsed"])
		while float(eclipse["next_pull_time"]) <= elapsed and float(eclipse["next_pull_time"]) <= LUNAR_ECLIPSE_DURATION:
			_pull_lunar_eclipse_target(target, Vector2(eclipse["center"]), float(eclipse["pull_amount"]))
			eclipse["next_pull_time"] = float(eclipse["next_pull_time"]) + LUNAR_ECLIPSE_PULL_INTERVAL
		while float(eclipse["next_laser_hit_time"]) <= elapsed and float(eclipse["next_laser_hit_time"]) <= LUNAR_ECLIPSE_LASER_LAST_HIT_TIME:
			if _lunar_eclipse_laser_hits(target, Vector2(eclipse["origin"]), Vector2(eclipse["facing"])):
				_apply_damage(target, int(eclipse["damage"]), "月蝕・潮汐")
			eclipse["next_laser_hit_time"] = float(eclipse["next_laser_hit_time"]) + LUNAR_ECLIPSE_LASER_DAMAGE_INTERVAL
		if elapsed >= float(eclipse["duration"]):
			state["lunar_eclipses"].remove_at(index)
		else:
			state["lunar_eclipses"][index] = eclipse

func _pull_lunar_eclipse_target(target: int, center: Vector2, pull_amount: float) -> void:
	var player: Dictionary = state["players"][target]
	var position := Vector2(player["position"])
	var distance := position.distance_to(center)
	if is_zero_approx(distance):
		return
	var max_distance := _lunar_eclipse_farthest_arena_distance(center)
	var distance_ratio := clampf(distance / max_distance, 0.0, 1.0)
	var adjusted_pull_amount := maxf(1.0, ceilf(pull_amount * (1.0 - distance_ratio)))
	player["position"] = _clamp_to_arena(position.move_toward(center, adjusted_pull_amount))
	state["players"][target] = player

func _lunar_eclipse_farthest_arena_distance(center: Vector2) -> float:
	var max_distance := 0.0
	for corner in [ARENA.position, Vector2(ARENA.end.x, ARENA.position.y), Vector2(ARENA.position.x, ARENA.end.y), ARENA.end]:
		max_distance = maxf(max_distance, center.distance_to(corner))
	return max_distance

func _lunar_eclipse_center(origin: Vector2, facing: Vector2) -> Vector2:
	return origin + facing * minf(300.0, _distance_to_arena_boundary(origin, facing))

func _distance_to_arena_boundary(origin: Vector2, facing: Vector2) -> float:
	var distances: Array[float] = []
	if facing.x > 0.0:
		distances.append((ARENA.end.x - origin.x) / facing.x)
	elif facing.x < 0.0:
		distances.append((ARENA.position.x - origin.x) / facing.x)
	if facing.y > 0.0:
		distances.append((ARENA.end.y - origin.y) / facing.y)
	elif facing.y < 0.0:
		distances.append((ARENA.position.y - origin.y) / facing.y)
	var result := 1000000000.0
	for distance in distances:
		if distance >= 0.0:
			result = minf(result, distance)
	return result

func _lunar_eclipse_laser_hits(target: int, origin: Vector2, facing: Vector2) -> bool:
	var start := origin + facing * 30.0
	var end := start + facing * _distance_to_arena_boundary(start, facing)
	var target_center := Vector2(state["players"][target]["position"]) + CHANTER_TARGET_HITBOX_OFFSET
	var offset := target_center - start
	var along := offset.dot(facing)
	if along < -CHANTER_TARGET_HITBOX_RADIUS_X or along > start.distance_to(end) + CHANTER_TARGET_HITBOX_RADIUS_X:
		return false
	return absf(offset.dot(facing.orthogonal())) <= LUNAR_ECLIPSE_LASER_HALF_WIDTH + CHANTER_TARGET_HITBOX_RADIUS_Y

func _is_lunar_eclipse_active(slot: int) -> bool:
	for eclipse in state["lunar_eclipses"]:
		if int(eclipse["owner_id"]) == slot:
			return true
	return false

func _apply_damage(target_slot: int, damage: int, _attack_name: String) -> void:
	if bool(state["match_over"]):
		return
	var target: Dictionary = state["players"][target_slot]
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	target["hit_time"] = 0.20
	state["players"][target_slot] = target
	if int(target["hp"]) <= 0:
		state["match_over"] = true
		state["winner_id"] = _other(target_slot)
		state["status_text"] = "%sの勝利！" % str(state["players"][_other(target_slot)]["name"])
		state["arithmetic_point_collections"].clear()

func _finish_by_hp() -> void:
	state["match_over"] = true
	state["arithmetic_point_collections"].clear()
	var p1 := int(state["players"][1]["hp"])
	var p2 := int(state["players"][2]["hp"])
	state["winner_id"] = 1 if p1 > p2 else (2 if p2 > p1 else 0)
	state["status_text"] = "時間切れ、引き分け！" if int(state["winner_id"]) == 0 else "%sの勝利！" % str(state["players"][state["winner_id"]]["name"])

func _score_challenge(challenge: Dictionary) -> int:
	var remaining := float(challenge["limit"]) - float(challenge["elapsed"])
	var owner := int(challenge.get("owner", 0))
	if state["players"].has(owner) and _typing_zone_level(state["players"][owner]) > 0:
		remaining = minf(float(challenge["limit"]), remaining * TYPIST_GOLDEN_TIME_SCORE_MULTIPLIER)
	var ratio := clampf(remaining / float(challenge["limit"]), 0.0, 1.0)
	return clampi(roundi(100.0 * (ratio + 0.85 / TAU * sin(TAU * ratio))), 0, 100)

func _evaluate_arithmetic(expression: String) -> int:
	var total := 0
	for add_term in expression.split("+"):
		var product := 1
		for factor in add_term.strip_edges().split("*"):
			product *= int(factor.strip_edges())
		total += product
	return total

func _make_trace_target(tier: String, small_skill_id: String = "") -> PackedVector2Array:
	var center := Vector2(340, 118)
	var points := PackedVector2Array()
	if tier == "small" and small_skill_id != "chanter_small_1":
		for index in 49:
			points.append(center + Vector2.from_angle(float(index) * TAU / 48.0) * 92.0)
		return points
	var turn_count := 3.5 if tier == "skill3" else (1.5 if tier == "small" else 2.5)
	const POINT_COUNT := 121
	for index in POINT_COUNT:
		var progress := float(index) / float(POINT_COUNT - 1)
		var angle := -PI / 2.0 + TAU * turn_count * progress
		var radius := lerpf(10.0, 108.0, progress)
		points.append(center + Vector2.from_angle(angle) * radius)
	return points

func _make_lunar_eclipse_trace_target() -> PackedVector2Array:
	var center := Vector2(340, 118)
	var vertices := PackedVector2Array()
	for index in 5:
		vertices.append(center + Vector2.from_angle(-PI / 2.0 + TAU * float(index) / 5.0) * 108.0)
	var order := [0, 2, 4, 1, 3, 0]
	var points := PackedVector2Array()
	for segment_index in 5:
		var start := vertices[order[segment_index]]
		var end := vertices[order[segment_index + 1]]
		for point_index in 24:
			points.append(start.lerp(end, float(point_index) / 24.0))
	points.append(vertices[order[-1]])
	return points

func _make_meteor_trace_target() -> PackedVector2Array:
	var center := Vector2(340, 118)
	var top := center + Vector2(0, -108)
	var right := center + Vector2(160, 0)
	var bottom := center + Vector2(0, 108)
	var left := center + Vector2(-160, 0)
	var points := PackedVector2Array()
	_append_trace_segment(points, top, right, 24)
	_append_trace_segment(points, right, left, 36)
	_append_trace_segment(points, left, bottom, 24)
	_append_trace_segment(points, bottom, top, 36)
	var circle_start := center + Vector2(0, -72)
	_append_trace_segment(points, top, circle_start, 12)
	for index in 49:
		points.append(center + Vector2.from_angle(-PI / 2.0 + TAU * float(index) / 48.0) * 72.0)
	return points

func _append_trace_segment(points: PackedVector2Array, start: Vector2, end: Vector2, point_count: int) -> void:
	for index in point_count:
		points.append(start.lerp(end, float(index) / float(point_count)))
	points.append(end)

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


func _typist_hammer_shockwave_projectile_hits_player(projectile: Dictionary, slot: int) -> bool:
	var player_center := Vector2(state["players"][slot]["position"]) + CHANTER_TARGET_HITBOX_OFFSET
	return TypistHammerShockwaveHitboxData.intersects_ellipse(projectile, player_center, CHANTER_TARGET_HITBOX_RADIUS_X, CHANTER_TARGET_HITBOX_RADIUS_Y)


func _point_hits_chanter_zone(point: Vector2, slot: int) -> bool:
	# ローカル対戦の is_point_in_player_hitbox() と同じ、足元アンカーから
	# 少し上へずらした縦長楕円を魔方陣半径ぶん拡張する判定に統一する。
	var player_center := Vector2(state["players"][slot]["position"]) + CHANTER_TARGET_HITBOX_OFFSET
	var normalized := point - player_center
	var radius_x := CHANTER_TARGET_HITBOX_RADIUS_X + CHANTER_ZONE_RADIUS
	var radius_y := CHANTER_TARGET_HITBOX_RADIUS_Y + CHANTER_ZONE_RADIUS
	return (normalized.x * normalized.x) / (radius_x * radius_x) + (normalized.y * normalized.y) / (radius_y * radius_y) <= 1.0

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

func _take_presentation_id() -> int:
	var value := _next_presentation_id
	_next_presentation_id += 1
	return value
