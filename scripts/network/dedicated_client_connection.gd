## Client transport adapter. UI supplies a Lobby API response, then listens to
## its signals; this class never decides a match result locally.
class_name DedicatedClientConnection
extends Node

signal rooms_received(rooms: Array)
signal reservation_received(connection: Dictionary)
signal connection_error(message: String)
signal joined(room_id: String, slot: int)
signal snapshot_received(snapshot: Dictionary)

@export var lobby_url := ""
@export var access_token := ""
@export var allow_insecure_lobby_url := false
var _http: HTTPRequest
var _pending_action := ""
var _join_data: Dictionary = {}
var sequence := 0
var event_sequence := 0

func reset_match_sequences() -> void:
	sequence = 0
	event_sequence = 0

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
	_request("POST", "/v1/rooms/%s/join" % room_id.uri_encode(), "join", "{}")


func configure_lobby(url: String, token: String, allow_http: bool) -> void:
	lobby_url = url.strip_edges().trim_suffix("/")
	access_token = token.strip_edges()
	allow_insecure_lobby_url = allow_http


func configuration_error() -> String:
	var normalized_url := lobby_url.strip_edges().trim_suffix("/")
	if normalized_url.is_empty():
		return "Lobby HTTPS URL を設定してください。"
	if normalized_url.contains(" ") or not normalized_url.contains("://"):
		return "Lobby URL の形式が正しくありません。"
	if normalized_url.begins_with("https://"):
		if normalized_url.trim_prefix("https://").split("/", false, 1)[0].is_empty():
			return "Lobby URL のホスト名を設定してください。"
	elif not (allow_insecure_lobby_url and _is_loopback_http_lobby_url(normalized_url)):
		return "Lobby URL は HTTPS を使用してください。"
	if access_token.length() < 32 or access_token.contains(" "):
		return "招待アクセストークンを設定してください。"
	return ""


func _is_loopback_http_lobby_url(url: String) -> bool:
	if not url.begins_with("http://"):
		return false
	var authority := url.trim_prefix("http://").split("/", false, 1)[0].to_lower()
	if authority == "127.0.0.1" or authority == "localhost":
		return true
	var parts := authority.split(":", false, 1)
	if parts.size() != 2 or parts[0] not in ["127.0.0.1", "localhost"] or not parts[1].is_valid_int():
		return false
	var port := parts[1].to_int()
	return port >= 1 and port <= 65535

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
	var invalid_reason := configuration_error()
	if not invalid_reason.is_empty():
		connection_error.emit(invalid_reason)
		return
	_pending_action = action
	var headers := PackedStringArray(["Accept: application/json", "X-Skill-Battle-Access-Token: %s" % access_token])
	if method == "POST":
		headers.append("Content-Type: application/json")
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
