## Headless ENet authority. Start with --headless --path . --scene res://scenes/server_main.tscn.
class_name DedicatedServer
extends Node

const DEFAULT_PORT := 7000
const TOKEN_SECRET_ENV := "SKILL_BATTLE_TOKEN_SECRET"
const SERVER_PORT_ENV := "SKILL_BATTLE_SERVER_PORT"
const MONITOR_URL_ENV := "SKILL_BATTLE_LOBBY_INTERNAL_URL"
const MONITOR_TOKEN_ENV := "SKILL_BATTLE_INTERNAL_API_TOKEN"
const HEARTBEAT_INTERVAL := 5.0
const MAX_FRAME_SECONDS := 0.25
const MAX_CATCH_UP_TICKS := 5
const SERVER_PROTOCOL_REVISION := "fixed-tick-sync-20260907"
@export var port := DEFAULT_PORT
@export var token_secret := ""

var sessions: Dictionary = {}
var peer_rooms: Dictionary = {}
var simulation_elapsed := 0.0
var snapshot_elapsed := 0.0
var server_tick := 0
var monitoring_elapsed := HEARTBEAT_INTERVAL
var started_at_msec := 0
var accepted_inputs := 0
var accepted_events := 0
var rejected_events := 0
var monitoring_url := ""
var monitoring_token := ""
var monitoring_request: HTTPRequest
var monitoring_in_flight := false
var monitoring_queue: Array = []

func _ready() -> void:
	if token_secret.is_empty():
		token_secret = OS.get_environment(TOKEN_SECRET_ENV)
	if token_secret.is_empty():
		push_error("%s must be set; refusing to start dedicated server." % TOKEN_SECRET_ENV)
		get_tree().quit(2)
		return
	var configured_port := OS.get_environment(SERVER_PORT_ENV)
	if configured_port.is_valid_int():
		port = configured_port.to_int()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MatchProtocol.MAX_ROOMS * MatchProtocol.ROOM_CAPACITY)
	if error != OK:
		push_error("Cannot listen on UDP %d: %s" % [port, error_string(error)])
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	started_at_msec = Time.get_ticks_msec()
	monitoring_url = OS.get_environment(MONITOR_URL_ENV).trim_suffix("/")
	monitoring_token = OS.get_environment(MONITOR_TOKEN_ENV)
	if not monitoring_url.is_empty() and not monitoring_token.is_empty():
		monitoring_request = HTTPRequest.new()
		add_child(monitoring_request)
		monitoring_request.request_completed.connect(_on_monitoring_request_completed)
	else:
		print("Dedicated Server monitoring is disabled (internal Lobby URL/token is not configured).")
	print("Dedicated Server listening on UDP %d (protocol=%s)" % [port, SERVER_PROTOCOL_REVISION])

func _process(delta: float) -> void:
	var bounded_delta := minf(delta, MAX_FRAME_SECONDS)
	simulation_elapsed += bounded_delta
	var catch_up_ticks := 0
	while simulation_elapsed >= MatchProtocol.TICK_SECONDS and catch_up_ticks < MAX_CATCH_UP_TICKS:
		for session in sessions.values():
			(session as MatchSession).step(MatchProtocol.TICK_SECONDS)
		simulation_elapsed -= MatchProtocol.TICK_SECONDS
		server_tick += 1
		catch_up_ticks += 1
	if simulation_elapsed >= MatchProtocol.TICK_SECONDS:
		# Do not let a stalled process accumulate an unbounded simulation debt.
		simulation_elapsed = 0.0
	snapshot_elapsed += bounded_delta
	if snapshot_elapsed >= 1.0 / MatchProtocol.SNAPSHOT_RATE:
		snapshot_elapsed = fmod(snapshot_elapsed, 1.0 / MatchProtocol.SNAPSHOT_RATE)
		broadcast_snapshots()
	monitoring_elapsed += bounded_delta
	if monitoring_elapsed >= HEARTBEAT_INTERVAL:
		monitoring_elapsed = 0.0
		_queue_heartbeat()
	_flush_monitoring()

@rpc("any_peer", "reliable")
func join_room(room_id: String, requested_slot: int, token: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_rooms.has(peer_id) or not _valid_token(token, room_id, requested_slot):
		_rejected_event("join_rejected", room_id, {"peer_id": peer_id, "requested_slot": requested_slot, "reason": "invalid_or_expired_token"})
		rpc_id(peer_id, "join_rejected", "入室トークンが無効または期限切れです。")
		return
	var session: MatchSession = sessions.get(room_id)
	if session == null:
		if sessions.size() >= MatchProtocol.MAX_ROOMS:
			_rejected_event("join_rejected", room_id, {"peer_id": peer_id, "requested_slot": requested_slot, "reason": "room_limit"})
			rpc_id(peer_id, "join_rejected", "サーバーのルーム上限に達しています。")
			return
		session = MatchSession.new(room_id)
		sessions[room_id] = session
	var assigned := session.join(peer_id, requested_slot)
	if assigned == 0:
		_rejected_event("join_rejected", room_id, {"peer_id": peer_id, "requested_slot": requested_slot, "reason": "slot_unavailable"})
		rpc_id(peer_id, "join_rejected", "このルームの席は利用できません。")
		return
	peer_rooms[peer_id] = room_id
	_queue_monitoring_event("join_accepted", room_id, {"peer_id": peer_id, "slot": assigned})
	rpc_id(peer_id, "joined_room", room_id, assigned)
	_broadcast_session(session)

@rpc("any_peer", "unreliable")
func submit_match_input(input: Dictionary) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var room_id: String = peer_rooms.get(peer_id, "")
	var session: MatchSession = sessions.get(room_id)
	if session != null and session.submit_input(peer_id, input):
		accepted_inputs += 1

@rpc("any_peer", "reliable")
func submit_match_event(event: Dictionary) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var room_id: String = peer_rooms.get(peer_id, "")
	var session: MatchSession = sessions.get(room_id)
	if session == null:
		_rejected_event("match_event_rejected", room_id, {"peer_id": peer_id, "event_type": str(event.get("type", "")), "reason": "room_missing"})
	elif session.submit_event(peer_id, event):
		accepted_events += 1
		_queue_monitoring_event("match_event_accepted", room_id, {"peer_id": peer_id, "event_type": str(event.get("type", ""))})
		_broadcast_session(session)
	else:
		_rejected_event("match_event_rejected", room_id, {"peer_id": peer_id, "event_type": str(event.get("type", "")), "reason": "invalid_or_duplicate"})

@rpc("any_peer", "reliable")
func set_room_ready(is_ready: bool) -> void:
	var session := _sender_session()
	if session != null:
		session.set_ready(multiplayer.get_remote_sender_id(), is_ready)
		var ready_snapshot: Dictionary = session.make_snapshot()["ready"]
		print("[LOBBY_READY] room=%s slot=%d ready=[%s,%s] phase=%s; waiting for host start" % [session.room_id, session.peer_slots.get(multiplayer.get_remote_sender_id(), 0), str(ready_snapshot[1]), str(ready_snapshot[2]), session.phase])
		_queue_monitoring_event("ready_changed", session.room_id, {"peer_id": multiplayer.get_remote_sender_id(), "ready": is_ready})
		_broadcast_session(session)

@rpc("any_peer", "reliable")
func request_match_start() -> void:
	var session := _sender_session()
	var requesting_peer_id := multiplayer.get_remote_sender_id()
	var started := session != null and session.start(requesting_peer_id)
	if session != null:
		print("[MATCH_START_REQUEST] room=%s peer=%d slot=%d accepted=%s phase=%s" % [session.room_id, requesting_peer_id, session.peer_slots.get(requesting_peer_id, 0), str(started), session.phase])
	if started:
		_queue_monitoring_event("match_started", session.room_id, {"peer_id": multiplayer.get_remote_sender_id()})
		_broadcast_session(session)


@rpc("any_peer", "reliable")
func request_result_action(action: String) -> void:
	var session := _sender_session()
	if session != null and session.request_result_action(multiplayer.get_remote_sender_id(), action):
		_queue_monitoring_event("result_action", session.room_id, {"peer_id": multiplayer.get_remote_sender_id(), "action": action})
		_broadcast_session(session)

@rpc("authority", "reliable")
func joined_room(_room_id: String, _slot: int) -> void:
	pass

@rpc("authority", "reliable")
func join_rejected(_message: String) -> void:
	pass

@rpc("authority", "unreliable_ordered")
func receive_dedicated_snapshot(_snapshot: Dictionary) -> void:
	pass

@rpc("authority", "reliable")
func receive_skill_presentation(_presentation: Dictionary) -> void:
	pass

@rpc("authority", "unreliable")
func receive_network_state(_state: Dictionary) -> void:
	pass

@rpc("any_peer", "reliable")
func request_lobby_state() -> void:
	pass

@rpc("any_peer", "reliable")
func receive_remote_lobby_choice(_selection: int, _ready: bool) -> void:
	pass

@rpc("any_peer", "unreliable")
func receive_remote_input(_input_state: Dictionary) -> void:
	pass

@rpc("any_peer", "reliable")
func receive_remote_challenge_input(_character: String) -> void:
	pass

@rpc("any_peer", "reliable")
func receive_remote_challenge_submission(_submitted_text: String) -> void:
	pass

@rpc("authority", "unreliable")
func receive_typist_typing_key_sound() -> void:
	pass

@rpc("any_peer", "reliable")
func receive_remote_trace(_trace_points: PackedVector2Array) -> void:
	pass

@rpc("any_peer", "reliable")
func receive_remote_result_action(_action: String) -> void:
	pass

func broadcast_snapshots() -> void:
	for session in sessions.values():
		_broadcast_session(session as MatchSession)

func _broadcast_session(session: MatchSession) -> void:
	var presentations := session.take_presentations()
	for peer_id in session.peer_slots.keys():
		for presentation in presentations:
			rpc_id(int(peer_id), "receive_skill_presentation", presentation)
		var recipient_slot := int(session.peer_slots[peer_id])
		rpc_id(int(peer_id), "receive_dedicated_snapshot", session.make_snapshot(recipient_slot, server_tick))

func _on_peer_disconnected(peer_id: int) -> void:
	var room_id: String = peer_rooms.get(peer_id, "")
	peer_rooms.erase(peer_id)
	var session: MatchSession = sessions.get(room_id)
	if session == null:
		return
	_queue_monitoring_event("peer_disconnected", room_id, {"peer_id": peer_id})
	session.leave(peer_id)
	_broadcast_session(session)
	if session.peers.is_empty():
		sessions.erase(room_id)
		_queue_monitoring_event("room_closed", room_id, {"reason": "all_peers_disconnected"})

func _sender_session() -> MatchSession:
	return sessions.get(peer_rooms.get(multiplayer.get_remote_sender_id(), "")) as MatchSession

func _valid_token(token: String, room_id: String, slot: int) -> bool:
	var parts := token.split(".")
	if parts.size() != 2:
		return false
	var payload_bytes := Marshalls.base64_to_raw(parts[0])
	var parsed = JSON.parse_string(payload_bytes.get_string_from_utf8())
	if not parsed is Dictionary or str(parsed.get("room_id", "")) != room_id or int(parsed.get("slot", 0)) != slot or int(parsed.get("expires_at", 0)) < Time.get_unix_time_from_system():
		return false
	var hmac := HMACContext.new()
	hmac.start(HashingContext.HASH_SHA256, token_secret.to_utf8_buffer())
	hmac.update(parts[0].to_utf8_buffer())
	return hmac.finish().hex_encode() == parts[1]

func _rejected_event(kind: String, room_id: String, details: Dictionary) -> void:
	rejected_events += 1
	_queue_monitoring_event(kind, room_id, details)

func _queue_heartbeat() -> void:
	if monitoring_request == null:
		return
	var connected_peers := 0
	for session in sessions.values():
		connected_peers += (session as MatchSession).peers.size()
	monitoring_queue.push_front({
		"kind": "heartbeat",
		"room_id": null,
		"details": {
			"uptime_seconds": int((Time.get_ticks_msec() - started_at_msec) / 1000),
			"active_rooms": sessions.size(),
			"connected_peers": connected_peers,
			"accepted_inputs": accepted_inputs,
			"accepted_events": accepted_events,
			"rejected_events": rejected_events,
		},
	})
	accepted_inputs = 0
	accepted_events = 0
	rejected_events = 0

func _queue_monitoring_event(kind: String, room_id: String, details: Dictionary) -> void:
	if monitoring_request == null:
		return
	monitoring_queue.append({"kind": kind, "room_id": room_id, "details": details})
	if monitoring_queue.size() > 256:
		monitoring_queue.pop_front()

func _flush_monitoring() -> void:
	if monitoring_request == null or monitoring_in_flight or monitoring_queue.is_empty():
		return
	var update: Dictionary = monitoring_queue.pop_front()
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"X-Skill-Battle-Internal-Token: %s" % monitoring_token,
	])
	var error := monitoring_request.request(monitoring_url + "/internal/server/updates", headers, HTTPClient.METHOD_POST, JSON.stringify(update))
	if error != OK:
		push_warning("Dedicated Server monitoring update could not be sent: %s" % error_string(error))
		return
	monitoring_in_flight = true

func _on_monitoring_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	monitoring_in_flight = false
	if response_code < 200 or response_code >= 300:
		push_warning("Dedicated Server monitoring update was rejected by Lobby API: HTTP %d" % response_code)
