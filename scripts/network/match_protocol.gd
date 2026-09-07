## Dedicated-match wire contract. This class has no UI or Input dependency.
class_name MatchProtocol
extends RefCounted

const TICK_RATE := 60.0
const SNAPSHOT_RATE := 20.0
const MAX_ROOMS := 10
const ROOM_CAPACITY := 2
const MAX_INPUT_SEQUENCE_GAP := 120
const MAX_EVENT_SEQUENCE_GAP := 120
const MAX_CHALLENGE_TEXT_LENGTH := 64
const MAX_TRACE_POINTS := 512
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
			return payload is Dictionary and int(payload.get("character", -1)) in [0, 1, 2] and str(payload.get("big_skill", "")) in ["typist_trident", "typist_keycap_ii"]
		_:
			return payload == null

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

static func snapshot(room_id: String, state: Dictionary, phase: String, status: String) -> Dictionary:
	var challenge: Dictionary = state.get("challenge", {}).duplicate(true)
	challenge.erase("answer")
	return {
		"room_id": room_id,
		"phase": phase,
		"players": state["players"].duplicate(true),
		"time_remaining": state["time_remaining"],
		"match_over": state["match_over"],
		"winner_id": state["winner_id"],
		"status_text": status,
		"challenge": challenge,
		"skill_projectiles": state.get("skill_projectiles", []).duplicate(true),
		"magic_zones": state.get("magic_zones", []).duplicate(true),
		"shockwaves": state.get("shockwaves", []).duplicate(true),
		"trident_impacts": state.get("trident_impacts", []).duplicate(true),
		"decoys": state.get("decoys", []).duplicate(true),
		"hammer_spins": state.get("hammer_spins", []).duplicate(true),
	}
