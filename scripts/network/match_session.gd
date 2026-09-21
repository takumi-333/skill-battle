## Owns one room only.  DedicatedServer owns transport and selects recipients.
class_name MatchSession
extends RefCounted

var room_id: String
var simulation := MatchSimulation.new()
var match_mode := MatchProtocol.DEFAULT_MATCH_MODE
var peers: Dictionary = {} # slot -> peer ID
var peer_slots: Dictionary = {} # peer ID -> slot
var inputs: Dictionary = {}
var input_sequences: Dictionary = {}
var input_received_ticks: Dictionary = {}
var simulation_tick := 0
var pending_presentations: Array[Dictionary] = []
var known_presentation_ids: Dictionary = {}
const INPUT_STALE_TICKS := 15
const READY_DURATION := 1.0
const FINISH_DURATION := 2.0
var event_sequences: Dictionary = {}
var round_id := 0
var ready: Dictionary = {}
var rematch_ready: Dictionary = {}
var result_lobby_slots: Dictionary = {}
var phase := "lobby"
var status := "対戦相手を待っています。"
var countdown_remaining := 0.0
var finish_remaining := 0.0
# Closed Lobby admission must not also discard the result screen state for the
# peers that already belong to this session.
var admission_closed := false
var terminal_closed := false

func _init(id: String, mode: String = MatchProtocol.DEFAULT_MATCH_MODE) -> void:
	room_id = id
	match_mode = MatchProtocol.normalized_match_mode(mode)
	simulation.set_match_mode(match_mode)
	_reset_round_inputs()
	_reset_ready_states()
	_reset_rematch_ready()
	_reset_result_lobby_slots()

func slots() -> Array[int]:
	return MatchProtocol.slots_for_mode(match_mode)

func join(peer_id: int, requested_slot: int) -> int:
	# A result or a closed room is never a new matchmaking lobby.
	if terminal_closed or admission_closed or phase != "lobby" or requested_slot not in slots() or peers.has(requested_slot):
		return 0
	peers[requested_slot] = peer_id
	peer_slots[peer_id] = requested_slot
	status = "全参加者の入室を待っています" if peers.size() == slots().size() else "対戦参加者を待っています"
	if match_mode == "duel":
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
		if not bool(simulation.state["match_over"]):
			simulation.finish_by_disconnect(slot)
		if match_mode == "free_for_all" and not bool(simulation.state["match_over"]):
			phase = "match"
			status = "参加者が切断しました。残りのプレイヤーで試合を続行します。"
		else:
			phase = "result"
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
	if peers.size() != slots().size() or phase != "lobby" or slots().any(func(slot: int) -> bool: return not bool(ready[slot])):
		return false
	if requesting_peer_id != 0 and int(peer_slots.get(requesting_peer_id, 0)) != 1:
		return false
	_start_countdown()
	return true


func request_result_action(peer_id: int, action: String) -> bool:
	if terminal_closed or phase != "result" or not peer_slots.has(peer_id) or action not in ["rematch", "lobby"]:
		return false
	if action == "rematch":
		if slots().any(func(slot: int) -> bool: return bool(result_lobby_slots[slot])):
			return false
		rematch_ready[peer_slots[peer_id]] = true
		if slots().any(func(slot: int) -> bool: return not bool(rematch_ready[slot])):
			status = "両者の再戦選択を待っています。"
			return true
		_reset_simulation_preserving_loadouts()
		_reset_ready_states()
		_reset_rematch_ready()
		_start_countdown()
	else:
		result_lobby_slots[peer_slots[peer_id]] = true
		_reset_rematch_ready()
		if slots().all(func(slot: int) -> bool: return bool(result_lobby_slots[slot])):
			_reset_simulation_preserving_loadouts()
			_reset_ready_states()
			_reset_result_lobby_slots()
			phase = "lobby"
			status = "キャラクターを選択して準備完了してください。"
		else:
			status = "相手がロビーに戻りました。"
	return true


func _reset_simulation_preserving_loadouts() -> void:
	var loadouts := {}
	for slot in slots():
		var player: Dictionary = simulation.state["players"][slot]
		loadouts[slot] = {
			"character": _character_index(str(player.get("character_id", "blade"))),
			"big_skill": str(player.get("big_skill_id", "typist_trident")),
			"small_skill": 1 if str(player.get("small_skill_id", "")) in ["chanter_small_1", "typist_golden_time_i"] else 0,
			"skill3": 0 if str(player.get("skill3_id", "")) in ["typist_hammer_spin", "arithmetic_hack_vision", "chanter_skill3_0"] else 1,
			"display_name": str(player.get("name", "")),
		}
	simulation.reset(match_mode)
	for slot in slots():
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
	for slot in slots():
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
	if phase == "result" and recipient_slot in slots() and bool(result_lobby_slots[recipient_slot]):
		recipient_phase = "lobby"
	var value := MatchProtocol.snapshot(room_id, simulation.state, recipient_phase, status, recipient_slot, server_tick, input_sequences)
	value["ready"] = ready.duplicate()
	value["round_id"] = round_id
	value["rematch_ready"] = rematch_ready.duplicate()
	value["result_lobby_slots"] = result_lobby_slots.duplicate()
	value["connected_slots"] = peers.keys()
	value["countdown_remaining"] = countdown_remaining
	value["finish_remaining"] = finish_remaining
	value["match_mode"] = match_mode
	value["room_capacity"] = slots().size()
	return value


func _is_knockout() -> bool:
	var players: Dictionary = simulation.state["players"]
	return slots().any(func(slot: int) -> bool: return int(players[slot]["hp"]) <= 0)


func _start_countdown() -> void:
	round_id += 1
	phase = "countdown"
	countdown_remaining = READY_DURATION
	finish_remaining = 0.0
	status = "READY"
	_reset_round_inputs()

func _reset_round_inputs() -> void:
	inputs.clear()
	input_sequences.clear()
	event_sequences.clear()
	input_received_ticks.clear()
	for slot in slots():
		inputs[slot] = {"move": Vector2.ZERO}
		input_sequences[slot] = -1
		event_sequences[slot] = -1
		input_received_ticks[slot] = -999999

func _reset_ready_states() -> void:
	ready.clear()
	for slot in slots():
		ready[slot] = false

func _reset_rematch_ready() -> void:
	rematch_ready.clear()
	for slot in slots():
		rematch_ready[slot] = false

func _reset_result_lobby_slots() -> void:
	result_lobby_slots.clear()
	for slot in slots():
		result_lobby_slots[slot] = false

func take_presentations() -> Array[Dictionary]:
	var value := pending_presentations.duplicate(true)
	pending_presentations.clear()
	return value

func _collect_presentations() -> void:
	for presentation in simulation.take_visual_presentations():
		pending_presentations.append(presentation)
	for kind in ["skill_projectiles", "magic_zones", "shockwaves", "trident_impacts", "meteor_impacts", "decoys", "arithmetic_flashes", "arithmetic_point_collections", "hammer_spins", "lunar_eclipses"]:
		for entity in simulation.state.get(kind, []):
			var item: Dictionary = entity
			if bool(item.get("client_predicted", false)):
				continue
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
