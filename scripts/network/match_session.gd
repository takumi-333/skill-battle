## Owns one room only.  DedicatedServer owns transport and selects recipients.
class_name MatchSession
extends RefCounted

var room_id: String
var simulation := MatchSimulation.new()
var peers: Dictionary = {} # slot -> peer ID
var peer_slots: Dictionary = {} # peer ID -> slot
var inputs := {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}}
var input_sequences := {1: -1, 2: -1}
var input_received_ticks := {1: -999999, 2: -999999}
var simulation_tick := 0
var pending_presentations: Array[Dictionary] = []
var known_presentation_ids: Dictionary = {}
const INPUT_STALE_TICKS := 15
const READY_DURATION := 1.0
const FINISH_DURATION := 2.0
var event_sequences := {1: -1, 2: -1}
var round_id := 0
var ready := {1: false, 2: false}
var rematch_ready := {1: false, 2: false}
var result_lobby_slots := {1: false, 2: false}
var phase := "lobby"
var status := "対戦相手を待っています。"
var countdown_remaining := 0.0
var finish_remaining := 0.0
# Closed Lobby admission must not also discard the result screen state for the
# peers that already belong to this session.
var admission_closed := false
var terminal_closed := false

func _init(id: String) -> void:
	room_id = id

func join(peer_id: int, requested_slot: int) -> int:
	# A result or a closed room is never a new matchmaking lobby.
	if terminal_closed or admission_closed or phase != "lobby" or requested_slot < 1 or requested_slot > 2 or peers.has(requested_slot):
		return 0
	peers[requested_slot] = peer_id
	peer_slots[peer_id] = requested_slot
	status = "両者の準備を待っています。" if peers.size() == 2 else "対戦相手を待っています。"
	return requested_slot

func leave(peer_id: int) -> bool:
	if not peer_slots.has(peer_id):
		return false
	var slot: int = peer_slots[peer_id]
	var was_active_match := phase in ["match", "finish"]
	peer_slots.erase(peer_id)
	peers.erase(slot)
	ready[slot] = false
	rematch_ready[slot] = false
	if was_active_match:
		phase = "result"
		if not bool(simulation.state["match_over"]):
			simulation.finish_by_disconnect(slot)
		status = "対戦相手との接続が切れました。"
	else:
		if phase == "countdown":
			phase = "lobby"
			countdown_remaining = 0.0
		status = "対戦相手を待っています。"
	return true

func submit_input(peer_id: int, input: Dictionary) -> bool:
	if phase != "match" or not peer_slots.has(peer_id):
		return false
	var slot: int = peer_slots[peer_id]
	if not MatchProtocol.valid_input(input, int(input_sequences[slot])):
		return false
	input_sequences[slot] = int(input["sequence"])
	inputs[slot] = input
	input_received_ticks[slot] = simulation_tick
	return true

func submit_event(peer_id: int, event: Dictionary) -> bool:
	if not peer_slots.has(peer_id):
		return false
	var slot: int = peer_slots[peer_id]
	if not MatchProtocol.valid_event(event, int(event_sequences[slot])):
		return false
	var event_type := str(event["type"])
	if event_type == "loadout":
		if phase != "lobby":
			return false
	elif phase != "match":
		return false
	event_sequences[slot] = int(event["sequence"])
	var accepted := simulation.handle_event(slot, event)
	if accepted:
		_collect_presentations()
	return accepted

func set_ready(peer_id: int, is_ready: bool) -> void:
	if phase != "lobby" or not peer_slots.has(peer_id):
		return
	ready[peer_slots[peer_id]] = is_ready

func start(requesting_peer_id: int) -> bool:
	if peers.size() != MatchProtocol.ROOM_CAPACITY or phase != "lobby" or not bool(ready[1]) or not bool(ready[2]):
		return false
	if requesting_peer_id != 0 and int(peer_slots.get(requesting_peer_id, 0)) != 1:
		return false
	_start_countdown()
	return true


func request_result_action(peer_id: int, action: String) -> bool:
	if terminal_closed or phase != "result" or not peer_slots.has(peer_id) or action not in ["rematch", "lobby"]:
		return false
	if action == "rematch":
		if bool(result_lobby_slots[1]) or bool(result_lobby_slots[2]):
			return false
		rematch_ready[peer_slots[peer_id]] = true
		if not bool(rematch_ready[1]) or not bool(rematch_ready[2]):
			status = "両者の再戦選択を待っています。"
			return true
		_reset_simulation_preserving_loadouts()
		ready = {1: false, 2: false}
		rematch_ready = {1: false, 2: false}
		_start_countdown()
	else:
		result_lobby_slots[peer_slots[peer_id]] = true
		rematch_ready = {1: false, 2: false}
		if bool(result_lobby_slots[1]) and bool(result_lobby_slots[2]):
			_reset_simulation_preserving_loadouts()
			ready = {1: false, 2: false}
			result_lobby_slots = {1: false, 2: false}
			phase = "lobby"
			status = "キャラクターを選択して準備完了してください。"
		else:
			status = "相手がロビーに戻りました。"
	return true


func _reset_simulation_preserving_loadouts() -> void:
	var loadouts := {}
	for slot in [1, 2]:
		var player: Dictionary = simulation.state["players"][slot]
		loadouts[slot] = {
			"character": _character_index(str(player.get("character_id", "blade"))),
			"big_skill": str(player.get("big_skill_id", "typist_trident")),
			"small_skill": 1 if str(player.get("small_skill_id", "")) in ["chanter_small_1", "typist_golden_time_i"] else 0,
			"skill3": 0 if str(player.get("skill3_id", "")) in ["typist_hammer_spin", "arithmetic_hack_vision", "chanter_skill3_0"] else 1,
			"display_name": str(player.get("name", "")),
		}
	simulation.reset()
	for slot in [1, 2]:
		var loadout: Dictionary = loadouts[slot]
		simulation.configure_loadout(slot, int(loadout["character"]), str(loadout["big_skill"]), str(loadout["display_name"]), int(loadout["small_skill"]), int(loadout["skill3"]))


func close_terminal() -> void:
	terminal_closed = true
	admission_closed = true


func close_admission() -> void:
	"""Prevent a new Lobby reservation joining this session, but retain its peers.

	The Lobby can therefore mark a completed room CLOSED while its two existing
	clients still choose rematch or return to the in-session lobby.
	"""
	admission_closed = true


func _character_index(character_id: String) -> int:
	match character_id:
		"arithmetic": return 1
		"chanter": return 2
		_: return 0

func step(delta: float) -> void:
	if phase == "countdown":
		countdown_remaining = maxf(0.0, countdown_remaining - delta)
		if countdown_remaining <= 0.0:
			phase = "match"
			status = "FIGHT"
		return
	if phase == "finish":
		finish_remaining = maxf(0.0, finish_remaining - delta)
		if finish_remaining <= 0.0:
			phase = "result"
			status = "試合終了"
		return
	if phase != "match":
		return
	simulation_tick += 1
	var active_inputs := inputs.duplicate(true)
	for slot in [1, 2]:
		if simulation_tick - int(input_received_ticks[slot]) > INPUT_STALE_TICKS:
			active_inputs[slot] = {"move": Vector2.ZERO}
	simulation.step(delta, active_inputs)
	_collect_presentations()
	if bool(simulation.state["match_over"]):
		if _is_knockout():
			phase = "finish"
			finish_remaining = FINISH_DURATION
			status = "決着！"
		else:
			phase = "result"
			status = "試合終了"

func make_snapshot(recipient_slot := 0, server_tick := 0) -> Dictionary:
	var recipient_phase := phase
	if phase == "result" and recipient_slot in [1, 2] and bool(result_lobby_slots[recipient_slot]):
		recipient_phase = "lobby"
	var value := MatchProtocol.snapshot(room_id, simulation.state, recipient_phase, status, recipient_slot, server_tick, input_sequences)
	value["ready"] = ready.duplicate()
	value["round_id"] = round_id
	value["rematch_ready"] = rematch_ready.duplicate()
	value["result_lobby_slots"] = result_lobby_slots.duplicate()
	value["connected_slots"] = peers.keys()
	value["countdown_remaining"] = countdown_remaining
	value["finish_remaining"] = finish_remaining
	return value


func _is_knockout() -> bool:
	var players: Dictionary = simulation.state["players"]
	return int(players[1]["hp"]) <= 0 or int(players[2]["hp"]) <= 0


func _start_countdown() -> void:
	round_id += 1
	phase = "countdown"
	countdown_remaining = READY_DURATION
	finish_remaining = 0.0
	status = "READY"
	inputs = {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}}
	input_sequences = {1: -1, 2: -1}
	event_sequences = {1: -1, 2: -1}
	input_received_ticks = {1: -999999, 2: -999999}

func take_presentations() -> Array[Dictionary]:
	var value := pending_presentations.duplicate(true)
	pending_presentations.clear()
	return value

func _collect_presentations() -> void:
	for kind in ["skill_projectiles", "magic_zones", "shockwaves", "trident_impacts", "decoys", "arithmetic_flashes", "arithmetic_point_collections", "hammer_spins", "lunar_eclipses"]:
		for entity in simulation.state.get(kind, []):
			var item: Dictionary = entity
			var presentation_id := int(item.get("presentation_id", 0))
			if presentation_id <= 0 or known_presentation_ids.has(presentation_id):
				continue
			known_presentation_ids[presentation_id] = true
			pending_presentations.append({"presentation_id": presentation_id, "kind": kind, "state": _presentation_state(item)})

func _presentation_state(source: Dictionary) -> Dictionary:
	var result := {}
	for key in ["presentation_id", "owner_id", "visual_id", "position", "velocity", "facing", "origin", "center", "score", "angle", "lifetime", "delay", "duration", "elapsed", "released", "active_duration", "spawned", "chip", "key_cap", "amount", "wait_time"]:
		if source.has(key):
			result[key] = source[key]
	return result
