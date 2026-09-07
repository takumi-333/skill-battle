## Client transport adapter. UI supplies a Lobby API response, then listens to
## its signals; this class never decides a match result locally.
class_name DedicatedClientConnection
extends Node

signal rooms_received(rooms: Array)
signal reservation_received(connection: Dictionary)
signal connection_error(message: String)
signal joined(room_id: String, slot: int)
signal snapshot_received(snapshot: Dictionary)

@export var lobby_url := "http://127.0.0.1:8000"
var _http: HTTPRequest
var _pending_action := ""
var _join_data: Dictionary = {}
var sequence := 0
var event_sequence := 0

func has_pending_join() -> bool:
	return not _join_data.is_empty()

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): connection_error.emit("対戦サーバーへ接続できませんでした。"))
	multiplayer.server_disconnected.connect(func(): connection_error.emit("対戦サーバーとの接続が切れました。"))

func refresh_rooms() -> void:
	_request("GET", "/v1/rooms", "rooms")

func create_room(name: String) -> void:
	_request("POST", "/v1/rooms", "create", JSON.stringify({"name": name}))

func join_room(room_id: String) -> void:
	_request("POST", "/v1/rooms/%s/join" % room_id.uri_encode(), "join")

func connect_reserved_room(connection: Dictionary) -> void:
	_join_data = connection
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(str(connection["server_address"]), int(connection["server_port"]))
	if error != OK:
		connection_error.emit("対戦サーバーへの接続を開始できません: %s" % error_string(error))
		return
	multiplayer.multiplayer_peer = peer

func send_input(move: Vector2) -> void:
	if _join_data.is_empty() or not multiplayer.has_multiplayer_peer():
		return
	sequence += 1
	get_parent().rpc_id(1, "submit_match_input", MatchProtocol.make_input(sequence, move))

func send_event(event_type: String, payload: Variant = null) -> void:
	if _join_data.is_empty() or not multiplayer.has_multiplayer_peer():
		return
	event_sequence += 1
	get_parent().rpc_id(1, "submit_match_event", MatchProtocol.make_event(event_sequence, event_type, payload))

func set_ready(is_ready: bool) -> void:
	get_parent().rpc_id(1, "set_room_ready", is_ready)

@rpc("authority", "reliable")
func joined_room(room_id: String, slot: int) -> void:
	joined.emit(room_id, slot)

@rpc("authority", "reliable")
func join_rejected(message: String) -> void:
	connection_error.emit(message)

@rpc("authority", "unreliable_ordered")
func receive_dedicated_snapshot(snapshot: Dictionary) -> void:
	snapshot_received.emit(snapshot)

func _on_connected() -> void:
	get_parent().rpc_id(1, "join_room", str(_join_data["room"]["id"]), int(_join_data["slot"]), str(_join_data["token"]))

func _request(method: String, path: String, action: String, body := "") -> void:
	_pending_action = action
	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := _http.request(lobby_url.trim_suffix("/") + path, headers, HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST, body)
	if error != OK:
		connection_error.emit("ロビー API へ接続できません: %s" % error_string(error))

func _on_http_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or not parsed is Dictionary:
		connection_error.emit("ロビー API エラー (%d)" % code)
		return
	if _pending_action == "rooms":
		rooms_received.emit(parsed.get("rooms", []))
	else:
		reservation_received.emit(parsed)
