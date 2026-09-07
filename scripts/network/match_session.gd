## Owns one room only.  DedicatedServer owns transport and selects recipients.
class_name MatchSession
extends RefCounted

var room_id: String
var simulation := MatchSimulation.new()
var peers: Dictionary = {} # slot -> peer ID
var peer_slots: Dictionary = {} # peer ID -> slot
var inputs := {1: {"move": Vector2.ZERO}, 2: {"move": Vector2.ZERO}}
var input_sequences := {1: -1, 2: -1}
var event_sequences := {1: -1, 2: -1}
var ready := {1: false, 2: false}
var phase := "lobby"
var status := "対戦相手を待っています。"

func _init(id: String) -> void:
	room_id = id

func join(peer_id: int, requested_slot: int) -> int:
	if requested_slot < 1 or requested_slot > 2 or peers.has(requested_slot):
		return 0
	peers[requested_slot] = peer_id
	peer_slots[peer_id] = requested_slot
	status = "両者の準備を待っています。" if peers.size() == 2 else "対戦相手を待っています。"
	return requested_slot

func leave(peer_id: int) -> bool:
	if not peer_slots.has(peer_id):
		return false
	var slot: int = peer_slots[peer_id]
	peer_slots.erase(peer_id)
	peers.erase(slot)
	phase = "result"
	simulation.finish_by_disconnect(slot)
	status = "対戦相手との接続が切れました。"
	return true

func submit_input(peer_id: int, input: Dictionary) -> bool:
	if phase != "match" or not peer_slots.has(peer_id):
		return false
	var slot: int = peer_slots[peer_id]
	if not MatchProtocol.valid_input(input, int(input_sequences[slot])):
		return false
	input_sequences[slot] = int(input["sequence"])
	inputs[slot] = input
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
	return simulation.handle_event(slot, event)

func set_ready(peer_id: int, is_ready: bool) -> void:
	if phase != "lobby" or not peer_slots.has(peer_id):
		return
	ready[peer_slots[peer_id]] = is_ready

func start(requesting_peer_id: int) -> bool:
	if peers.size() != MatchProtocol.ROOM_CAPACITY or phase != "lobby" or not bool(ready[1]) or not bool(ready[2]):
		return false
	if requesting_peer_id != 0 and int(peer_slots.get(requesting_peer_id, 0)) != 1:
		return false
	phase = "match"
	status = "開始！"
	return true


func request_result_action(peer_id: int, action: String) -> bool:
	if phase != "result" or not peer_slots.has(peer_id) or action not in ["rematch", "lobby"]:
		return false
	_reset_simulation_preserving_loadouts()
	ready = {1: false, 2: false}
	if action == "rematch":
		phase = "match"
		status = "再戦開始！"
	else:
		phase = "lobby"
		status = "キャラクターを選択して準備完了してください。"
	return true


func _reset_simulation_preserving_loadouts() -> void:
	var loadouts := {}
	for slot in [1, 2]:
		var player: Dictionary = simulation.state["players"][slot]
		loadouts[slot] = {
			"character": _character_index(str(player.get("character_id", "blade"))),
			"big_skill": str(player.get("big_skill_id", "typist_trident")),
		}
	simulation.reset()
	for slot in [1, 2]:
		var loadout: Dictionary = loadouts[slot]
		simulation.configure_loadout(slot, int(loadout["character"]), str(loadout["big_skill"]))


func _character_index(character_id: String) -> int:
	match character_id:
		"arithmetic": return 1
		"chanter": return 2
		_: return 0

func step(delta: float) -> void:
	if phase != "match":
		return
	simulation.step(delta, inputs)
	if bool(simulation.state["match_over"]):
		phase = "result"
		status = "試合終了"

func make_snapshot() -> Dictionary:
	var value := MatchProtocol.snapshot(room_id, simulation.state, phase, status)
	value["ready"] = ready.duplicate()
	return value
