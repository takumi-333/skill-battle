## Dedicated-match wire contract. This class has no UI or Input dependency.
class_name MatchProtocol
extends RefCounted

const TICK_RATE := 60.0
const TICK_SECONDS := 1.0 / TICK_RATE
const SNAPSHOT_RATE := 20.0
const MAX_ROOMS := 10
const ROOM_CAPACITY := 2
const MAX_INPUT_SEQUENCE_GAP := 120
const MAX_EVENT_SEQUENCE_GAP := 120
const MAX_CHALLENGE_TEXT_LENGTH := 64
const MAX_TRACE_POINTS := 512
const MAX_DISPLAY_NAME_LENGTH := 20
const EVENT_TYPES := ["attack", "small_skill", "big_skill", "skill3", "challenge_character", "challenge_submit", "challenge_trace", "challenge_cancel", "loadout"]

static func make_input(sequence: int, move: Vector2) -> Dictionary:
	return {"sequence": sequence, "move": move.limit_length(1.0)}

static func valid_input(value: Variant, previous_sequence: int) -> bool:
	if not value is Dictionary:
		return false
	var sequence := int(value.get("sequence", -1))
	var move: Variant = value.get("move", null)
	return sequence > previous_sequence and sequence <= previous_sequence + MAX_INPUT_SEQUENCE_GAP and move is Vector2 and (move as Vector2).length_squared() <= 1.01

static func make_event(sequence: int, event_type: String, payload: Variant = null) -> Dictionary:
	return {"sequence": sequence, "type": event_type, "payload": payload}

static func valid_event(value: Variant, previous_sequence: int) -> bool:
	if not value is Dictionary:
		return false
	var sequence := int(value.get("sequence", -1))
	var event_type := str(value.get("type", ""))
	if sequence <= previous_sequence or sequence > previous_sequence + MAX_EVENT_SEQUENCE_GAP or not event_type in EVENT_TYPES:
		return false
	var payload: Variant = value.get("payload", null)
	match event_type:
		"challenge_character":
			return payload is String and (payload as String).length() == 1
		"challenge_submit":
			return payload is String and (payload as String).length() <= MAX_CHALLENGE_TEXT_LENGTH
		"challenge_trace":
			return payload is PackedVector2Array and (payload as PackedVector2Array).size() <= MAX_TRACE_POINTS
		"loadout":
			return payload is Dictionary and int(payload.get("character", -1)) in [0, 1, 2] and str(payload.get("big_skill", "")) in ["typist_trident", "typist_keycap_ii", "typist_golden_time_ii", "arithmetic_perfect_mapping", "chanter_meteor_shower"] and int(payload.get("small_skill", 0)) in [0, 1] and int(payload.get("skill3", 0)) in [0, 1] and valid_display_name(payload.get("display_name", ""))
		_:
			return payload == null


static func valid_display_name(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty() and (value as String).length() <= MAX_DISPLAY_NAME_LENGTH

## RPC/JSON deserialization returns an untyped Array even when every element
## is a Dictionary. Copy valid entries into a genuinely typed container before
## assigning them to client-side Array[Dictionary] state.
static func dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for entry in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result

const PLAYER_SNAPSHOT_KEYS := [
	"name", "has_display_name", "character_id", "visual_id", "is_moving", "position", "facing", "attack_facing", "color", "hp",
	"attack_cooldown", "attack_time", "hit_time", "focused", "challenge_elapsed", "skill_cooldown",
	"skill_successes", "score_total", "best_score", "challenge_count", "challenge_score_total", "challenge_best_score",
	"challenge_errors", "challenge_total_time", "buff_time", "invisible_time", "invisible_flicker", "small_skill_id",
	"big_skill_id", "skill3_id", "small_cooldown", "big_cooldown", "skill3_cooldown", "typing_zone_level", "typing_zone_time", "arithmetic_interference_multiplier", "hack_vision_time", "hack_vision_owner_id", "hack_vision_suppress_interference_points", "equation_lock_time", "equation_lock_owner_id",
]
const INTERPOLATED_VECTOR_KEYS := ["position", "velocity", "facing", "attack_facing", "origin", "center"]
const INTERPOLATED_NUMBER_KEYS := ["angle", "elapsed", "lifetime", "delay", "radius", "damage_flash", "pulse_time", "flash_time", "noise_time", "hit_timer", "keycap_timer", "homing_time", "next_damage_time", "wait_time", "typing_zone_time"]

static func snapshot(room_id: String, state: Dictionary, phase: String, status: String, recipient_slot := 0, server_tick := 0, input_acknowledgements: Dictionary = {}) -> Dictionary:
	var challenges: Dictionary = {}
	if recipient_slot > 0:
		var challenge: Dictionary = state.get("challenges", {}).get(recipient_slot, {}).duplicate(true)
		challenge.erase("answer")
		if not challenge.is_empty():
			challenges[recipient_slot] = challenge
	return {
		"room_id": room_id,
		"server_tick": server_tick,
		"input_acknowledgements": input_acknowledgements.duplicate(),
		"phase": phase,
		"players": snapshot_players(state["players"]),
		"time_remaining": state["time_remaining"],
		"match_over": state["match_over"],
		"winner_id": state["winner_id"],
		"status_text": status,
		"challenges": challenges,
		"skill_projectiles": snapshot_skill_projectiles(state.get("skill_projectiles", [])),
		"magic_zones": state.get("magic_zones", []).duplicate(true),
		"shockwaves": state.get("shockwaves", []).duplicate(true),
		"trident_impacts": state.get("trident_impacts", []).duplicate(true),
		"meteor_impacts": state.get("meteor_impacts", []).duplicate(true),
		"decoys": state.get("decoys", []).duplicate(true),
		"arithmetic_flashes": state.get("arithmetic_flashes", []).duplicate(true),
		"arithmetic_point_collections": state.get("arithmetic_point_collections", []).duplicate(true),
		"perfect_mapping_effects": state.get("perfect_mapping_effects", []).duplicate(true),
		"hammer_spins": state.get("hammer_spins", []).duplicate(true),
		"lunar_eclipses": state.get("lunar_eclipses", []).duplicate(true),
	}

static func snapshot_skill_projectiles(source: Variant) -> Array:
	var result: Array = []
	if not source is Array:
		return result
	for entry in source:
		if entry is Dictionary and bool((entry as Dictionary).get("client_predicted", false)):
			continue
		result.append((entry as Dictionary).duplicate(true) if entry is Dictionary else entry)
	return result

static func snapshot_players(source: Dictionary) -> Dictionary:
	var result := {}
	for slot in source.keys():
		var player: Dictionary = source[slot]
		var value := {}
		for key in PLAYER_SNAPSHOT_KEYS:
			if player.has(key):
				value[key] = player[key]
		result[slot] = value
	return result

static func interpolate_visual_state(previous: Dictionary, current: Dictionary, ratio: float) -> Dictionary:
	var value := current.duplicate(true)
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	value["players"] = _interpolate_players(previous.get("players", {}), current.get("players", {}), clamped_ratio)
	for entity_key in ["skill_projectiles", "magic_zones", "shockwaves", "trident_impacts", "meteor_impacts", "decoys", "arithmetic_flashes", "arithmetic_point_collections", "perfect_mapping_effects", "hammer_spins", "lunar_eclipses"]:
		value[entity_key] = _interpolate_entities(previous.get(entity_key, []), current.get(entity_key, []), clamped_ratio)
	return value

static func _interpolate_players(previous: Dictionary, current: Dictionary, ratio: float) -> Dictionary:
	var result := {}
	for slot in current.keys():
		var incoming: Dictionary = current[slot]
		var older: Dictionary = previous.get(slot, {})
		result[slot] = _interpolate_dictionary(older, incoming, ratio) if not older.is_empty() else incoming.duplicate(true)
	return result

static func _interpolate_entities(previous: Array, current: Array, ratio: float) -> Array:
	var result: Array = []
	for index in current.size():
		var incoming: Dictionary = current[index]
		var older: Dictionary = _matching_entity(previous, incoming, index)
		result.append(_interpolate_dictionary(older, incoming, ratio) if not older.is_empty() else incoming.duplicate(true))
	return result

static func _matching_entity(previous: Array, incoming: Dictionary, fallback_index: int) -> Dictionary:
	for key in ["presentation_id", "projectile_id", "impact_id"]:
		if incoming.has(key):
			for entry in previous:
				if entry is Dictionary and int((entry as Dictionary).get(key, -1)) == int(incoming[key]):
					return entry as Dictionary
	if fallback_index < previous.size() and previous[fallback_index] is Dictionary:
		var candidate: Dictionary = previous[fallback_index]
		if int(candidate.get("owner_id", -1)) == int(incoming.get("owner_id", -1)):
			return candidate
	return {}

static func _interpolate_dictionary(previous: Dictionary, current: Dictionary, ratio: float) -> Dictionary:
	var result := current.duplicate(true)
	for key in INTERPOLATED_VECTOR_KEYS:
		# A zone is hidden while unspawned and receives its target position only
		# when it appears. Blending that transition makes it look as if it flies
		# in from the hidden Vector2.ZERO placeholder.
		if key == "position" and not bool(previous.get("spawned", true)) and bool(current.get("spawned", true)):
			continue
		if previous.get(key, null) is Vector2 and current.get(key, null) is Vector2:
			var blended := Vector2(previous[key]).lerp(Vector2(current[key]), ratio)
			if key in ["facing", "attack_facing"] and blended.length_squared() > 0.0001:
				blended = blended.normalized()
			result[key] = blended
	for key in INTERPOLATED_NUMBER_KEYS:
		if previous.has(key) and current.has(key) and previous[key] is float and current[key] is float:
			result[key] = lerp_angle_shortest(float(previous[key]), float(current[key]), ratio) if key == "angle" else lerpf(float(previous[key]), float(current[key]), ratio)
	return result

static func lerp_angle_shortest(from: float, to: float, ratio: float) -> float:
	return wrapf(from + wrapf(to - from, -PI, PI) * clampf(ratio, 0.0, 1.0), 0.0, TAU)
