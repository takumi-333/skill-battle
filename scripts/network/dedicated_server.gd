## Headless ENet authority. Start with --headless --path . --scene res://scenes/server_main.tscn.
class_name DedicatedServer
extends Node

const DEFAULT_PORT := 7000
const TOKEN_SECRET_ENV := "SKILL_BATTLE_TOKEN_SECRET"
const SERVER_PORT_ENV := "SKILL_BATTLE_SERVER_PORT"
const SERVER_LISTEN_PORT_ENV := "SKILL_BATTLE_SERVER_LISTEN_PORT"
const MONITOR_URL_ENV := "SKILL_BATTLE_LOBBY_INTERNAL_URL"
const MONITOR_TOKEN_ENV := "SKILL_BATTLE_INTERNAL_API_TOKEN"
const PUBLIC_MODE_ENV := "SKILL_BATTLE_PUBLIC_MODE"
const REQUIRE_CONSUME_ENV := "SKILL_BATTLE_REQUIRE_LOBBY_CONSUME"
const HEARTBEAT_INTERVAL := 5.0
const CONSUME_TIMEOUT_SECONDS := 5.0
const JOIN_HANDSHAKE_TIMEOUT_SECONDS := 8.0
const REJECTED_PEER_DISCONNECT_DELAY_SECONDS := 0.25
const ROOM_STATUS_RETRY_BASE_SECONDS := 0.5
const ROOM_STATUS_RETRY_MAX_SECONDS := 10.0
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
var room_status_queue: Array = []
var monitoring_in_flight_update: Dictionary = {}
var reconciliation_request: HTTPRequest
var pending_consume_requests: Dictionary = {} # peer_id -> HTTPRequest; never shared between peers
var unauthenticated_peer_deadlines: Dictionary = {} # peer_id -> monotonic deadline msec
var rejected_peer_disconnect_deadlines: Dictionary = {} # peer_id -> monotonic deadline msec
var public_mode := false
var require_lobby_consume := false
var ready_for_joins := false

func _ready() -> void:
	if token_secret.is_empty():
		token_secret = OS.get_environment(TOKEN_SECRET_ENV)
	if token_secret.is_empty():
		push_error("%s must be set; refusing to start dedicated server." % TOKEN_SECRET_ENV)
		get_tree().quit(2)
		return
	var configured_port := OS.get_environment(SERVER_PORT_ENV)
	var configured_listen_port := OS.get_environment(SERVER_LISTEN_PORT_ENV)
	if configured_listen_port.is_valid_int():
		configured_port = configured_listen_port
	if configured_port.is_valid_int():
		port = configured_port.to_int()
	public_mode = OS.get_environment(PUBLIC_MODE_ENV) == "1"
	require_lobby_consume = public_mode or OS.get_environment(REQUIRE_CONSUME_ENV) == "1"
	monitoring_url = OS.get_environment(MONITOR_URL_ENV).trim_suffix("/")
	monitoring_token = OS.get_environment(MONITOR_TOKEN_ENV)
	if require_lobby_consume and (monitoring_url.is_empty() or monitoring_token.is_empty()):
		push_error("A Lobby internal URL and token are required for secure ticket consumption.")
		get_tree().quit(2)
		return
	var peer := ENetMultiplayerPeer.new()
	if public_mode:
		# playit.gg is the sole public UDP ingress. Do not also expose ENet on LAN.
		peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(port, MatchProtocol.MAX_ROOMS * MatchProtocol.ROOM_CAPACITY)
	if error != OK:
		push_error("Cannot listen on UDP %d: %s" % [port, error_string(error)])
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	started_at_msec = Time.get_ticks_msec()
	if not monitoring_url.is_empty() and not monitoring_token.is_empty():
		monitoring_request = HTTPRequest.new()
		add_child(monitoring_request)
		monitoring_request.request_completed.connect(_on_monitoring_request_completed)
		_start_lobby_reconciliation()
	else:
		print("Dedicated Server monitoring is disabled (internal Lobby URL/token is not configured).")
		ready_for_joins = true
	print("Dedicated Server listening on UDP %d (protocol=%s)" % [port, SERVER_PROTOCOL_REVISION])

func _process(delta: float) -> void:
	_expire_unauthenticated_peers()
	var bounded_delta := minf(delta, MAX_FRAME_SECONDS)
	simulation_elapsed += bounded_delta
	var catch_up_ticks := 0
	while simulation_elapsed >= MatchProtocol.TICK_SECONDS and catch_up_ticks < MAX_CATCH_UP_TICKS:
		for session_value in sessions.values():
			var session := session_value as MatchSession
			var previous_phase := session.phase
			session.step(MatchProtocol.TICK_SECONDS)
			if previous_phase in ["match", "finish"] and session.phase == "result":
				# Do not admit a third party after the match, while preserving the
				# two connected players' result actions (rematch / return to lobby).
				session.close_admission()
				_queue_room_status(session.room_id, "closed")
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

@rpc("authority", "unreliable")
func receive_shared_sound(_sound_kind: StringName) -> void:
	pass

@rpc("authority", "reliable")
func receive_challenge_miss_feedback(_duration: float) -> void:
	pass

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

@rpc("any_peer", "reliable")
func join_room(room_id: String, requested_slot: int, token: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if not ready_for_joins:
		_reject_and_disconnect(peer_id, room_id, requested_slot, "server_initializing", "対戦サーバーを初期化しています。もう一度接続してください。")
		return
	if peer_rooms.has(peer_id) or pending_consume_requests.has(peer_id):
		_reject_join(peer_id, room_id, requested_slot, "duplicate_join", "入室要求を処理中です。")
		return
	var payload := _validated_ticket(token, room_id, requested_slot)
	if payload.is_empty():
		_reject_and_disconnect(peer_id, room_id, requested_slot, "invalid_or_expired_token", "入室トークンが無効または期限切れです。")
		return
	_extend_unauthenticated_peer_deadline(peer_id)
	if monitoring_url.is_empty() or monitoring_token.is_empty():
		if require_lobby_consume:
			_reject_and_disconnect(peer_id, room_id, requested_slot, "lobby_unavailable", "ロビー認証サービスを利用できません。")
			return
		# Explicit legacy development mode only. Public launchers always require consume.
		_accept_consumed_join(peer_id, room_id, requested_slot)
		return
	_start_consume_request(peer_id, room_id, requested_slot, str(payload["nonce"]))


func _start_consume_request(peer_id: int, room_id: String, requested_slot: int, nonce: String) -> void:
	var request := HTTPRequest.new()
	request.timeout = CONSUME_TIMEOUT_SECONDS
	add_child(request)
	pending_consume_requests[peer_id] = request
	request.request_completed.connect(_on_consume_request_completed.bind(peer_id, room_id, requested_slot))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"X-Skill-Battle-Internal-Token: %s" % monitoring_token,
	])
	var error := request.request(monitoring_url + "/internal/rooms/" + room_id.uri_encode() + "/consume", headers, HTTPClient.METHOD_POST, JSON.stringify({"slot": requested_slot, "nonce": nonce}))
	if error != OK:
		pending_consume_requests.erase(peer_id)
		request.queue_free()
		_reject_and_disconnect(peer_id, room_id, requested_slot, "consume_request_failed", "入室認証を開始できませんでした。")


func _start_lobby_reconciliation() -> void:
	"""Close stale Lobby state before this fresh process accepts any ticket."""
	reconciliation_request = HTTPRequest.new()
	reconciliation_request.timeout = CONSUME_TIMEOUT_SECONDS
	add_child(reconciliation_request)
	reconciliation_request.request_completed.connect(_on_lobby_reconciliation_completed)
	var headers := PackedStringArray(["X-Skill-Battle-Internal-Token: %s" % monitoring_token])
	var error := reconciliation_request.request(monitoring_url + "/internal/server/reconcile", headers, HTTPClient.METHOD_POST)
	if error != OK:
		_finish_lobby_reconciliation(false, "Lobby再起動同期を開始できませんでした。")


func _on_lobby_reconciliation_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_finish_lobby_reconciliation(result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300, "Lobby再起動同期が拒否されました。")


func _finish_lobby_reconciliation(succeeded: bool, failure_message: String) -> void:
	if reconciliation_request != null:
		reconciliation_request.queue_free()
		reconciliation_request = null
	if succeeded:
		ready_for_joins = true
		return
	if require_lobby_consume:
		push_error(failure_message)
		get_tree().quit(2)
		return
	push_warning(failure_message + " 開発モードのため入室を継続します。")
	ready_for_joins = true


func _on_consume_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, peer_id: int, room_id: String, requested_slot: int) -> void:
	var request: HTTPRequest = pending_consume_requests.get(peer_id)
	pending_consume_requests.erase(peer_id)
	if request != null:
		request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if multiplayer.get_peers().has(peer_id):
			_reject_and_disconnect(peer_id, room_id, requested_slot, "consume_rejected", "入室予約が無効、使用済み、または期限切れです。")
		else:
			_queue_room_status(room_id, "disconnected", requested_slot)
		return
	if not multiplayer.get_peers().has(peer_id):
		# The one-time nonce stays consumed; its short CONNECTING lease will recover.
		unauthenticated_peer_deadlines.erase(peer_id)
		_queue_room_status(room_id, "disconnected", requested_slot)
		return
	_accept_consumed_join(peer_id, room_id, requested_slot)


func _accept_consumed_join(peer_id: int, room_id: String, requested_slot: int) -> void:
	var session: MatchSession = sessions.get(room_id)
	if session == null:
		if sessions.size() >= MatchProtocol.MAX_ROOMS:
			_reject_and_disconnect(peer_id, room_id, requested_slot, "room_limit", "サーバーのルーム上限に達しています。")
			_queue_room_status(room_id, "disconnected", requested_slot)
			return
		session = MatchSession.new(room_id)
		sessions[room_id] = session
	var assigned := session.join(peer_id, requested_slot)
	if assigned == 0:
		_reject_and_disconnect(peer_id, room_id, requested_slot, "slot_unavailable", "このルームの席は利用できません。")
		_queue_room_status(room_id, "disconnected", requested_slot)
		return
	peer_rooms[peer_id] = room_id
	unauthenticated_peer_deadlines.erase(peer_id)
	rejected_peer_disconnect_deadlines.erase(peer_id)
	_queue_monitoring_event("join_accepted", room_id, {"peer_id": peer_id, "slot": assigned})
	_queue_room_status(room_id, "connected", assigned)
	if _has_active_multiplayer_peer():
		rpc_id(peer_id, "joined_room", room_id, assigned)
	_broadcast_session(session)


func _reject_join(peer_id: int, room_id: String, requested_slot: int, reason: String, message: String) -> void:
	_rejected_event("join_rejected", room_id, {"peer_id": peer_id, "requested_slot": requested_slot, "reason": reason})
	rpc_id(peer_id, "join_rejected", message)

func _reject_and_disconnect(peer_id: int, room_id: String, requested_slot: int, reason: String, message: String) -> void:
	_reject_join(peer_id, room_id, requested_slot, reason, message)
	unauthenticated_peer_deadlines.erase(peer_id)
	rejected_peer_disconnect_deadlines[peer_id] = Time.get_ticks_msec() + roundi(REJECTED_PEER_DISCONNECT_DELAY_SECONDS * 1000.0)

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
		if str(event.get("type", "")) == "challenge_character":
			_relay_typist_typing_key_sound(session, peer_id)
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
		_queue_room_status(session.room_id, "running")
		_broadcast_session(session)

@rpc("any_peer", "reliable")
func request_result_action(action: String) -> void:
	var session := _sender_session()
	if session != null and session.request_result_action(multiplayer.get_remote_sender_id(), action):
		_queue_monitoring_event("result_action", session.room_id, {"peer_id": multiplayer.get_remote_sender_id(), "action": action})
		_broadcast_session(session)

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

@rpc("any_peer", "unreliable")
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
	if not _has_active_multiplayer_peer():
		return
	var presentations := session.take_presentations()
	for peer_id in session.peer_slots.keys():
		for presentation in presentations:
			rpc_id(int(peer_id), "receive_skill_presentation", presentation)
		var recipient_slot := int(session.peer_slots[peer_id])
		rpc_id(int(peer_id), "receive_dedicated_snapshot", session.make_snapshot(recipient_slot, server_tick))


func _relay_typist_typing_key_sound(session: MatchSession, source_peer_id: int) -> void:
	for peer_id in session.peer_slots.keys():
		if int(peer_id) != source_peer_id:
			rpc_id(int(peer_id), "receive_typist_typing_key_sound")

func _on_peer_connected(peer_id: int) -> void:
	unauthenticated_peer_deadlines[peer_id] = Time.get_ticks_msec() + roundi(JOIN_HANDSHAKE_TIMEOUT_SECONDS * 1000.0)

func _extend_unauthenticated_peer_deadline(peer_id: int) -> void:
	# A valid ticket gets enough time for the internal consume request to finish.
	unauthenticated_peer_deadlines[peer_id] = Time.get_ticks_msec() + roundi((CONSUME_TIMEOUT_SECONDS + 1.0) * 1000.0)

func _is_unauthenticated_peer_expired(peer_id: int, now_msec: int) -> bool:
	return now_msec >= int(unauthenticated_peer_deadlines.get(peer_id, now_msec))

func _has_active_multiplayer_peer() -> bool:
	return is_inside_tree() and multiplayer.multiplayer_peer != null

func _disconnect_peer_transport(peer_id: int) -> void:
	if not _has_active_multiplayer_peer() or not multiplayer.get_peers().has(peer_id):
		return
	multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)

func _expire_unauthenticated_peers() -> void:
	var now_msec := Time.get_ticks_msec()
	for peer_value in unauthenticated_peer_deadlines.keys():
		var peer_id := int(peer_value)
		if not _is_unauthenticated_peer_expired(peer_id, now_msec):
			continue
		unauthenticated_peer_deadlines.erase(peer_id)
		# Keep an in-flight consume request alive after disconnect so it can release
		# a nonce that reached Lobby instead of leaving a CONNECTING lease behind.
		_disconnect_peer_transport(peer_id)
	for peer_value in rejected_peer_disconnect_deadlines.keys():
		var peer_id := int(peer_value)
		if now_msec < int(rejected_peer_disconnect_deadlines[peer_id]):
			continue
		rejected_peer_disconnect_deadlines.erase(peer_id)
		_disconnect_peer_transport(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	unauthenticated_peer_deadlines.erase(peer_id)
	rejected_peer_disconnect_deadlines.erase(peer_id)
	if pending_consume_requests.has(peer_id):
		# Let the request finish so a consume that reached Lobby receives the
		# matching disconnect notification instead of leaving a stale lease.
		return
	var room_id: String = peer_rooms.get(peer_id, "")
	peer_rooms.erase(peer_id)
	var session: MatchSession = sessions.get(room_id)
	if session == null:
		return
	# The Lobby API owns public room occupancy. Include the slot before
	# MatchSession.leave() removes it so the matching reservation is released.
	var slot := int(session.peer_slots.get(peer_id, 0))
	var terminal_phase := session.phase != "lobby"
	_queue_monitoring_event("peer_disconnected", room_id, {"peer_id": peer_id, "slot": slot})
	session.leave(peer_id)
	if terminal_phase:
		session.close_terminal()
		_queue_room_status(room_id, "closed")
	else:
		_queue_room_status(room_id, "disconnected", slot)
	_broadcast_session(session)
	if session.peers.is_empty():
		sessions.erase(room_id)
		_queue_monitoring_event("room_closed", room_id, {"reason": "all_peers_disconnected"})

func _sender_session() -> MatchSession:
	return sessions.get(peer_rooms.get(multiplayer.get_remote_sender_id(), "")) as MatchSession

func _validated_ticket(token: String, room_id: String, slot: int) -> Dictionary:
	var parts := token.split(".")
	if parts.size() != 2:
		return {}
	var payload_bytes := Marshalls.base64_to_raw(parts[0])
	var parsed = JSON.parse_string(payload_bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var nonce := str(parsed.get("nonce", ""))
	if str(parsed.get("room_id", "")) != room_id or int(parsed.get("slot", 0)) != slot or int(parsed.get("expires_at", 0)) < Time.get_unix_time_from_system() or nonce.length() < 32:
		return {}
	var signature_bytes := parts[1].hex_decode()
	if signature_bytes.size() != 32:
		return {}
	var hmac := HMACContext.new()
	hmac.start(HashingContext.HASH_SHA256, token_secret.to_utf8_buffer())
	hmac.update(parts[0].to_utf8_buffer())
	var crypto := Crypto.new()
	if not crypto.constant_time_compare(hmac.finish(), signature_bytes):
		return {}
	return parsed as Dictionary

func _rejected_event(kind: String, room_id: String, details: Dictionary) -> void:
	rejected_events += 1
	_queue_monitoring_event(kind, room_id, details)

func _queue_heartbeat() -> void:
	if monitoring_request == null:
		return
	var connected_peers := 0
	for session in sessions.values():
		connected_peers += (session as MatchSession).peers.size()
	monitoring_queue.append({
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


func _queue_room_status(room_id: String, status: String, slot := 0) -> void:
	if monitoring_request == null:
		return
	room_status_queue.append({
		"route": "room_status",
		"room_id": room_id,
		"status": status,
		"slot": slot,
		"retry_count": 0,
		"retry_after_msec": 0,
	})

func _next_ready_room_status_index(now_msec: int) -> int:
	# Preserve ordering within a room, while allowing an unavailable room's retry
	# to yield to transitions for other rooms and ordinary telemetry.
	var blocked_room_ids := {}
	for index in range(room_status_queue.size()):
		var update: Dictionary = room_status_queue[index]
		var room_id := str(update.get("room_id", ""))
		if blocked_room_ids.has(room_id):
			continue
		blocked_room_ids[room_id] = true
		if now_msec >= int(update.get("retry_after_msec", 0)):
			return index
	return -1

func _room_status_retry_delay_msec(retry_count: int) -> int:
	var multiplier := pow(2.0, min(retry_count - 1, 5))
	return roundi(minf(ROOM_STATUS_RETRY_BASE_SECONDS * multiplier, ROOM_STATUS_RETRY_MAX_SECONDS) * 1000.0)

func _reschedule_room_status(update: Dictionary) -> void:
	var retry_count := int(update.get("retry_count", 0)) + 1
	update["retry_count"] = retry_count
	update["retry_after_msec"] = Time.get_ticks_msec() + _room_status_retry_delay_msec(retry_count)
	room_status_queue.append(update)

func _should_retry_room_status(result: int, response_code: int) -> bool:
	return result != HTTPRequest.RESULT_SUCCESS or response_code == 408 or response_code == 429 or response_code >= 500

func _flush_monitoring() -> void:
	if monitoring_request == null or monitoring_in_flight:
		return
	var update: Dictionary = {}
	var status_index := _next_ready_room_status_index(Time.get_ticks_msec())
	if status_index >= 0:
		update = room_status_queue.pop_at(status_index)
	elif not monitoring_queue.is_empty():
		update = monitoring_queue.pop_front()
	else:
		return
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"X-Skill-Battle-Internal-Token: %s" % monitoring_token,
	])
	var path := "/internal/server/updates"
	var body: Dictionary = update
	if str(update.get("route", "")) == "room_status":
		path = "/internal/rooms/" + str(update["room_id"]).uri_encode() + "/status"
		body = {"status": update["status"]}
		if int(update.get("slot", 0)) in [1, 2]:
			body["slot"] = int(update["slot"])
	monitoring_in_flight_update = update
	var error := monitoring_request.request(monitoring_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		monitoring_in_flight_update = {}
		if str(update.get("route", "")) == "room_status":
			_reschedule_room_status(update)
		else:
			monitoring_queue.push_back(update)
		return
	monitoring_in_flight = true

func _on_monitoring_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var update := monitoring_in_flight_update
	monitoring_in_flight_update = {}
	monitoring_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if str(update.get("route", "")) == "room_status":
			if _should_retry_room_status(result, response_code):
				# State transitions are part of the security contract. Retry transient
				# failures with backoff so one room cannot stall other monitoring work.
				_reschedule_room_status(update)
			else:
				push_warning("Dedicated Server room-status update was permanently rejected by Lobby API: HTTP %d" % response_code)
		else:
			push_warning("Dedicated Server monitoring update was rejected by Lobby API: HTTP %d" % response_code)
