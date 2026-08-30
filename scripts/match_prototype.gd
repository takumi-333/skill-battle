extends MatchController

class StatusIcon extends Control:
	var is_ready: bool = false
	var spinner_angle: float = 0.0

	func set_ready(value: bool) -> void:
		is_ready = value
		queue_redraw()

	func _process(delta: float) -> void:
		if not is_ready:
			spinner_angle = fmod(spinner_angle + delta * 5.0, TAU)
			queue_redraw()

	func _draw() -> void:
		var center := Vector2(24.0, 24.0)
		if is_ready:
			draw_line(Vector2(10.0, 24.0), Vector2(20.0, 34.0), Color("71d6ba"), 5.0, true)
			draw_line(Vector2(20.0, 34.0), Vector2(39.0, 13.0), Color("71d6ba"), 5.0, true)
		else:
			draw_arc(center, 14.0, spinner_angle, spinner_angle + PI * 1.45, 20, Color("ffc45e"), 4.0, true)

class TraceCanvas extends Control:
	var target_points: PackedVector2Array = PackedVector2Array()
	var input_points: PackedVector2Array = PackedVector2Array()
	var is_tracing: bool = false

	func set_trace_data(target: PackedVector2Array, input: PackedVector2Array) -> void:
		target_points = target
		input_points = input
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0a1224cc"), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color("7386b8"), false, 2.0)
		if target_points.size() >= 2:
			draw_polyline(target_points, Color("8fa8e888"), 12.0, true)
			draw_circle(target_points[0], 13.0, Color("71d6ba"))
			draw_circle(target_points[0], 6.0, Color("10233a"))
			var end_point := target_points[target_points.size() - 1]
			var previous_point := target_points[target_points.size() - 2]
			var direction := (end_point - previous_point).normalized()
			var side := direction.orthogonal() * 10.0
			draw_colored_polygon(PackedVector2Array([end_point, end_point - direction * 24.0 + side, end_point - direction * 24.0 - side]), Color("ffc45e"))
		if input_points.size() >= 2:
			draw_polyline(input_points, Color("fff2b0"), 5.0, true)
		for point in input_points:
			draw_circle(point, 3.0, Color("fff2b0"))

const ARENA := Rect2(40, 100, 1200, 580)
## プレイヤーの座標は足元付近のアンカー。見た目の胴体に合わせて、
## アンカーから少し上にずらした縦長の楕円を当たり判定として使う。
const PLAYER_HITBOX_RADIUS_X := 20.0
const PLAYER_HITBOX_RADIUS_Y := 30.0
const PLAYER_HITBOX_OFFSET := Vector2(0.0, -12.0)
const PLAYER_SPEED := 280.0
const SLASH_RANGE := 74.0
const SLASH_DAMAGE := 12
const SLASH_ARC_HALF_ANGLE := deg_to_rad(55.0)
const ATTACK_COOLDOWN := 0.5
const ATTACK_DURATION := 0.16
const MATCH_DURATION := 90.0
const FOCUS_SPEED_MULTIPLIER := 0.35
const TYPING_CHALLENGE_LIMIT := 6.0
const TYPING_SKILL_COOLDOWN := 2.0
const SKILL_PROJECTILE_RADIUS := 10.0
const TYPING_INTERRUPT_GAUGE := 30.0
const INTERRUPT_DISPLAY_SPEED := 180.0
const BIG_CHALLENGE_LIMIT := 10.0
const BIG_PASSING_SCORE := 70
const ARITHMETIC_CHALLENGE_LIMIT := 7.0
const TRACE_CHALLENGE_LIMIT := 8.0
const ZONE_DURATION := 5.0
const NETWORK_PORT := 7000
const STATE_SYNC_INTERVAL := 0.05
const TITLE_LOGO_ANIMATION_DURATION := 1.2
const TITLE_PROMPT_BLINK_SPEED := 4.0
const UI_CLICK_SOUND: AudioStream = preload("res://assets/audio/ui_click.wav")

const MatchStateData = preload("res://scripts/match_state.gd")
const ChallengeLayerData = preload("res://scripts/challenge_layer.gd")
const TYPIST_TEXTURE: Texture2D = preload("res://assets/characters/typist_pixel_8dir.png")
const ARITHMETICIAN_TEXTURE: Texture2D = preload("res://assets/characters/arithmetician_pixel_8dir.png")
const CHANTER_TEXTURE: Texture2D = preload("res://assets/characters/chanter_pixel_8dir.png")

var match_state: MatchState = MatchStateData.new()
var players: Dictionary = match_state.players
var status_text := "開始！ 距離を取りながら相手に通常攻撃を当てよう。"
var skill_projectiles: Array[Dictionary] = []
var magic_zones: Array[Dictionary] = []
var phase: String = "lobby"
var screen: String = "title"
var countdown_remaining: float = 0.0
var p1_selection: int = 0
var p2_selection: int = 1
var p1_ready: bool = false
var p2_ready: bool = false
var challenge_owner: int = 0
var challenge_skill: String = ""
var challenge_prompt: String = ""
var challenge_answer: String = ""
var challenge_score: int = 0
var challenge_trace_points: PackedVector2Array = PackedVector2Array()
var challenge_target_points: PackedVector2Array = PackedVector2Array()
var challenge_definitions: Dictionary = {}
var network_mode: String = "local"
var local_player_id: int = 1
var debug_controlled_player_id: int = 1
var remote_input: Dictionary = {"move": Vector2.ZERO, "attack": false, "small": false, "big": false}
var network_sync_elapsed: float = 0.0
var pending_client_input: Dictionary = {}
var network_target_players: Dictionary = {}
var character_animation_elapsed: float = 0.0
var title_animation_elapsed: float = 0.0

var player_one_label: Label
var player_two_label: Label
var timer_label: Label
var status_label: Label
var controls_label: Label
var challenge_panel: PanelContainer
var challenge_title_label: Label
var challenge_prompt_label: Label
var challenge_progress_label: Label
var challenge_dimmer: ColorRect
var challenge_time_bar: ProgressBar
var challenge_trace_canvas: TraceCanvas
var typing_input: LineEdit
var lobby_panel: Panel
var lobby_label: Label
var result_panel: Panel
var result_label: Label
var result_rematch_button: Button
var result_lobby_button: Button
var network_back_button: Button
var lobby_home_button: Button
var gameplay_home_button: Button
var network_panel: Panel
var network_address_input: LineEdit
var network_status_label: Label
var title_panel: Panel
var title_prompt: Label
var home_panel: Panel
var practice_panel: Panel
var debug_panel: Panel
var title_logo: TextureRect
var practice_selection: int = 0
var debug_p1_selection: int = 0
var debug_p2_selection: int = 1
var practice_preview: Label
var debug_preview: Label
var practice_portrait: TextureRect
var debug_p1_portrait: TextureRect
var debug_p2_portrait: TextureRect
var debug_p1_name: Label
var debug_p2_name: Label
var debug_control_p1_button: Button
var debug_control_p2_button: Button
var lobby_p1_preview: TextureRect
var lobby_p2_preview: TextureRect
var lobby_p1_info: Label
var lobby_p2_info: Label
var lobby_p1_status_icon: StatusIcon
var lobby_p2_status_icon: StatusIcon
var lobby_p1_left: Button
var lobby_p1_right: Button
var lobby_p1_ready: Button
var lobby_p2_left: Button
var lobby_p2_right: Button
var lobby_p2_ready: Button
var ui_click_player: AudioStreamPlayer


func _ready() -> void:
	create_ui_sound_player()
	get_tree().node_added.connect(_on_node_added)
	create_challenge_definitions()
	create_hud()
	create_lobby_ui()
	create_result_ui()
	create_network_ui()
	create_navigation_ui()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	show_title()
	queue_redraw()


func create_ui_sound_player() -> void:
	ui_click_player = AudioStreamPlayer.new()
	ui_click_player.stream = UI_CLICK_SOUND
	ui_click_player.volume_db = -7.0
	add_child(ui_click_player)


func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(play_ui_click)


func play_ui_click() -> void:
	ui_click_player.play()


func create_challenge_definitions() -> void:
	var small_typing: ChallengeDefinition = ChallengeDefinition.new()
	small_typing.challenge_type = "typing"
	small_typing.prompt = "blade"
	small_typing.time_limit_seconds = TYPING_CHALLENGE_LIMIT
	small_typing.passing_score = 0
	challenge_definitions["blade_small"] = small_typing
	var big_typing: ChallengeDefinition = ChallengeDefinition.new()
	big_typing.challenge_type = "typing"
	big_typing.prompt = "the blade returns at dawn"
	big_typing.time_limit_seconds = BIG_CHALLENGE_LIMIT
	big_typing.passing_score = BIG_PASSING_SCORE
	challenge_definitions["blade_big"] = big_typing
	var small_arithmetic: ChallengeDefinition = ChallengeDefinition.new()
	small_arithmetic.challenge_type = "arithmetic"
	small_arithmetic.prompt = "7 + 8 = ?"
	small_arithmetic.time_limit_seconds = ARITHMETIC_CHALLENGE_LIMIT
	challenge_definitions["arithmetic_small"] = small_arithmetic
	var big_arithmetic: ChallengeDefinition = ChallengeDefinition.new()
	big_arithmetic.challenge_type = "arithmetic"
	big_arithmetic.prompt = "12 × 7 = ?"
	big_arithmetic.time_limit_seconds = BIG_CHALLENGE_LIMIT
	big_arithmetic.passing_score = BIG_PASSING_SCORE
	challenge_definitions["arithmetic_big"] = big_arithmetic


func _process(delta: float) -> void:
	character_animation_elapsed += delta
	if screen == "title" or screen == "home" or screen == "practice_select" or screen == "debug_select":
		if screen == "title":
			title_animation_elapsed += delta
			update_title_prompt_blink()
		queue_redraw()
		return
	if phase == "connection":
		queue_redraw()
		return
	if network_mode == "client":
		process_client_network_input(delta)
		interpolate_network_players(delta)
		if challenge_owner == local_player_id:
			var challenge_player: Dictionary = players[local_player_id]
			update_challenge_ui(float(challenge_player["challenge_elapsed"]))
		update_hud()
		queue_redraw()
		return
	if phase == "lobby":
		update_lobby(delta)
		if network_mode == "host":
			sync_network_state(delta)
		queue_redraw()
		return
	if phase == "countdown":
		countdown_remaining = maxf(0.0, countdown_remaining - delta)
		status_text = "試合開始まで %.1f" % countdown_remaining
		if countdown_remaining <= 0.0:
			begin_match()
		if network_mode == "host":
			sync_network_state(delta)
		update_hud()
		queue_redraw()
		return
	if phase == "result" or match_state.match_over:
		if Input.is_key_pressed(KEY_R):
			request_return_to_lobby()
		return

	match_state.time_remaining = maxf(0.0, match_state.time_remaining - delta)
	update_player(1, delta, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)
	if network_mode != "practice":
		update_player(2, delta, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)
	update_typing_challenge(delta)
	update_skill_projectiles(delta)
	update_magic_zones(delta)
	if network_mode == "host":
		sync_network_state(delta)

	if network_mode == "local":
		if Input.is_key_pressed(KEY_1):
			start_small_skill(debug_controlled_player_id)
		if Input.is_key_pressed(KEY_2):
			start_big_skill(debug_controlled_player_id)
		if Input.is_key_pressed(KEY_SPACE):
			try_attack(debug_controlled_player_id)
	else:
		if Input.is_key_pressed(KEY_1):
			start_small_skill(1)
		if Input.is_key_pressed(KEY_2):
			start_big_skill(1)
		if network_mode != "host" and Input.is_key_pressed(KEY_1):
			start_small_skill(2)
		if network_mode != "host" and Input.is_key_pressed(KEY_2):
			start_big_skill(2)
		if Input.is_key_pressed(KEY_SPACE):
			try_attack(1)
		if network_mode != "host" and Input.is_key_pressed(KEY_SPACE):
			try_attack(2)
	if network_mode == "host":
		if bool(remote_input["attack"]):
			try_attack(2)
		if bool(remote_input["small"]):
			start_small_skill(2)
		if bool(remote_input["big"]):
			start_big_skill(2)

	if match_state.time_remaining <= 0.0 and not match_state.match_over:
		finish_match_by_time()

	update_hud()
	queue_redraw()


func update_player(player_id: int, delta: float, left_key, right_key, up_key, down_key) -> void:
	var player: Dictionary = players[player_id]
	var direction := Vector2.ZERO
	if network_mode == "local" and player_id != debug_controlled_player_id:
		direction = Vector2.ZERO
	elif network_mode == "host" and player_id == 2:
		direction = remote_input["move"]
	else:
		direction.x = float(Input.is_key_pressed(right_key)) - float(Input.is_key_pressed(left_key))
		direction.y = float(Input.is_key_pressed(down_key)) - float(Input.is_key_pressed(up_key))
	var moved := false
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		player["facing"] = direction
		var speed_multiplier: float = (FOCUS_SPEED_MULTIPLIER if bool(player["focused"]) else 1.0) * (1.25 if float(player["buff_time"]) > 0.0 else 1.0)
		var next_position := clamp_to_arena(player["position"] + direction * PLAYER_SPEED * speed_multiplier * delta)
		if can_move_player_to(player_id, next_position):
			player["position"] = next_position
			moved = true
	player["is_moving"] = moved
	player["attack_cooldown"] = maxf(0.0, player["attack_cooldown"] - delta)
	player["attack_time"] = maxf(0.0, player["attack_time"] - delta)
	player["hit_time"] = maxf(0.0, player["hit_time"] - delta)
	player["small_cooldown"] = maxf(0.0, float(player["small_cooldown"]) - delta)
	player["big_cooldown"] = maxf(0.0, float(player["big_cooldown"]) - delta)
	player["buff_time"] = maxf(0.0, float(player["buff_time"]) - delta)
	var shown_gauge: float = float(player["interrupt_gauge_display"])
	var target_gauge: float = float(player["interrupt_gauge"])
	player["interrupt_gauge_display"] = move_toward(shown_gauge, target_gauge, INTERRUPT_DISPLAY_SPEED * delta)
	players[player_id] = player


func try_attack(player_id: int) -> void:
	var player: Dictionary = players[player_id]
	if bool(player["focused"]):
		if player_id == 1:
			status_text = "集中中は通常攻撃を使えない。Escで課題を中止できる。"
		return
	if player["attack_cooldown"] > 0.0:
		return
	player["attack_cooldown"] = ATTACK_COOLDOWN
	player["attack_time"] = ATTACK_DURATION
	players[player_id] = player
	var target_id := 2 if player_id == 1 else 1
	var target: Dictionary = players[target_id]
	var to_target: Vector2 = get_player_hitbox_center(target["position"]) - get_player_hitbox_center(player["position"])
	var facing: Vector2 = player["facing"]
	var in_range: bool = to_target.length() <= SLASH_RANGE + PLAYER_HITBOX_RADIUS_X
	var in_front: bool = to_target.length_squared() > 0.0 and facing.dot(to_target.normalized()) >= cos(SLASH_ARC_HALF_ANGLE)
	if in_range and in_front:
		apply_damage(target_id, int(player["normal_damage"]), "%sの斬撃" % player["name"])
		status_text = "%sの斬撃が%sに命中！" % [player["name"], target["name"]]
		if target["hp"] <= 0:
			finish_match(player_id)
	else:
		status_text = "%sは斬撃を振った。" % player["name"]


func start_small_skill(owner_id: int) -> void:
	start_skill_challenge(owner_id, false)


func start_big_skill(owner_id: int) -> void:
	start_skill_challenge(owner_id, true)


func start_skill_challenge(owner_id: int, is_big: bool) -> void:
	if challenge_owner != 0:
		return
	var player: Dictionary = players[owner_id]
	if bool(player["focused"]):
		return
	var cooldown_key: String = "big_cooldown" if is_big else "small_cooldown"
	if float(player[cooldown_key]) > 0.0:
		return
	var character_id: String = str(player["character_id"])
	challenge_owner = owner_id
	challenge_skill = "big" if is_big else "small"
	challenge_trace_points.clear()
	if character_id == "blade":
		var typing_definition: ChallengeDefinition = challenge_definitions["blade_big" if is_big else "blade_small"]
		challenge_prompt = typing_definition.prompt
		challenge_answer = challenge_prompt
		challenge_skill = "big_typing" if is_big else "small_typing"
	elif character_id == "arithmetic":
		var arithmetic_definition: ChallengeDefinition = challenge_definitions["arithmetic_big" if is_big else "arithmetic_small"]
		challenge_prompt = arithmetic_definition.prompt
		if is_big:
			var factor_a: int = randi_range(8, 15)
			var factor_b: int = randi_range(4, 9)
			challenge_prompt = "%d × %d = ?" % [factor_a, factor_b]
			challenge_answer = str(factor_a * factor_b)
		else:
			var add_a: int = randi_range(4, 18)
			var add_b: int = randi_range(3, 16)
			challenge_prompt = "%d + %d = ?" % [add_a, add_b]
			challenge_answer = str(add_a + add_b)
		challenge_skill = "big_arithmetic" if is_big else "small_arithmetic"
	else:
		challenge_prompt = "星形をなぞってください" if is_big else "右向きの線をなぞってください"
		challenge_answer = ""
		challenge_skill = "big_trace" if is_big else "small_trace"
		challenge_target_points = make_trace_target(is_big)
	player["focused"] = true
	player["challenge_elapsed"] = 0.0
	player["interrupt_gauge_max"] = 50.0 if is_big else TYPING_INTERRUPT_GAUGE
	player["interrupt_gauge"] = player["interrupt_gauge_max"]
	player["interrupt_gauge_display"] = player["interrupt_gauge_max"]
	players[owner_id] = player
	var show_local_challenge: bool = network_mode != "host" or owner_id == 1
	challenge_dimmer.visible = show_local_challenge
	challenge_panel.visible = show_local_challenge
	typing_input.visible = not challenge_skill.ends_with("trace")
	typing_input.text = ""
	if typing_input.visible and show_local_challenge:
		typing_input.grab_focus()
	status_text = "%sが%sの集中を開始！" % [player["name"], "スキル2" if is_big else "スキル1"]
	update_challenge_ui(0.0)
	update_trace_canvas()


func make_trace_target(is_big: bool) -> PackedVector2Array:
	if not is_big:
		return PackedVector2Array([Vector2(120, 110), Vector2(560, 110)])
	var center := Vector2(340, 118)
	var points := PackedVector2Array()
	for index in range(11):
		var angle := -PI / 2.0 + float(index) * TAU / 10.0
		var radius := 96.0 if index % 2 == 0 else 39.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func update_trace_canvas() -> void:
	if challenge_trace_canvas:
		challenge_trace_canvas.set_trace_data(challenge_target_points, challenge_trace_points)


func update_typing_challenge(delta: float) -> void:
	if challenge_owner == 0:
		return
	var player: Dictionary = players[challenge_owner]
	if not bool(player["focused"]):
		return
	var elapsed: float = float(player["challenge_elapsed"]) + delta
	player["challenge_elapsed"] = elapsed
	players[challenge_owner] = player
	update_challenge_ui(elapsed)
	var limit: float = BIG_CHALLENGE_LIMIT if challenge_skill.begins_with("big") else (TRACE_CHALLENGE_LIMIT if challenge_skill.ends_with("trace") else (ARITHMETIC_CHALLENGE_LIMIT if challenge_skill.ends_with("arithmetic") else TYPING_CHALLENGE_LIMIT))
	if elapsed >= limit:
		end_active_challenge(false, 0, "時間切れ。課題は失敗した。")


func _on_typing_submitted(submitted_text: String) -> void:
	if network_mode == "client":
		if challenge_owner == local_player_id:
			rpc_id(1, "receive_remote_challenge_input", submitted_text)
			typing_input.text = ""
		return
	if challenge_owner == 0:
		return
	var player: Dictionary = players[challenge_owner]
	if not bool(player["focused"]):
		return
	if submitted_text.strip_edges().to_lower() != challenge_answer.to_lower():
		player["challenge_errors"] = int(player["challenge_errors"]) + 1
		players[challenge_owner] = player
		end_active_challenge(false, 0, "誤入力。課題は失敗した。")
		return
	var elapsed: float = float(player["challenge_elapsed"])
	var limit: float = BIG_CHALLENGE_LIMIT if challenge_skill.begins_with("big") else (ARITHMETIC_CHALLENGE_LIMIT if challenge_skill.ends_with("arithmetic") else TYPING_CHALLENGE_LIMIT)
	var score: int = clampi(roundi(100.0 - elapsed / limit * 40.0), 0, 100)
	end_active_challenge(score >= (BIG_PASSING_SCORE if challenge_skill.begins_with("big") else 0), score, "")


func end_active_challenge(success: bool, score: int, failure_message: String) -> void:
	if challenge_owner == 0:
		return
	var owner_id: int = challenge_owner
	var player: Dictionary = players[owner_id]
	var is_big: bool = challenge_skill.begins_with("big")
	var challenge_time: float = float(player["challenge_elapsed"])
	player["focused"] = false
	player["challenge_elapsed"] = 0.0
	player["challenge_total_time"] = float(player["challenge_total_time"]) + challenge_time
	player["interrupt_gauge"] = 0.0
	player["interrupt_gauge_max"] = 0.0
	player["small_cooldown" if not is_big else "big_cooldown"] = TYPING_SKILL_COOLDOWN * (2.0 if is_big else 1.0)
	if success:
		player["skill_successes"] = int(player["skill_successes"]) + 1
		player["score_total"] = int(player["score_total"]) + score
		player["best_score"] = maxi(int(player["best_score"]), score)
		player["challenge_count"] = int(player["challenge_count"]) + 1
		player["challenge_score_total"] = int(player["challenge_score_total"]) + score
		player["challenge_best_score"] = maxi(int(player["challenge_best_score"]), score)
	players[owner_id] = player
	challenge_panel.visible = false
	challenge_dimmer.visible = false
	typing_input.release_focus()
	typing_input.visible = true
	if success:
		spawn_character_skill(owner_id, score, is_big)
		status_text = "%sの%sが発動！ スコア %d点" % [player["name"], "スキル2" if is_big else "スキル1", score]
	else:
		status_text = failure_message
	challenge_owner = 0
	challenge_skill = ""
	challenge_target_points.clear()
	update_trace_canvas()


func end_typing_challenge(success: bool, score: int, failure_message: String) -> void:
	end_active_challenge(success, score, failure_message)


func spawn_typing_projectile(score: int) -> void:
	var owner: Dictionary = players[1]
	var owner_position: Vector2 = owner["position"]
	var facing: Vector2 = owner["facing"]
	var damage: int = 10 + roundi(float(score) * 0.1)
	var speed: float = 500.0 + float(score) * 3.0
	skill_projectiles.append({
		"position": get_player_hitbox_center(owner_position) + facing * (PLAYER_HITBOX_RADIUS_X + SKILL_PROJECTILE_RADIUS),
		"velocity": facing * speed,
		"damage": damage,
		"lifetime": 1.6,
	})


func spawn_character_skill(owner_id: int, score: int, is_big: bool) -> void:
	var owner: Dictionary = players[owner_id]
	var character_id: String = str(owner["character_id"])
	if character_id == "blade":
		var count: int = 2 if is_big else 1
		for shot in range(count):
			spawn_projectile(owner_id, score, is_big, float(shot - (count - 1) * 0.5) * 0.16)
	elif character_id == "arithmetic":
		if is_big:
			spawn_zone(owner_id, score, owner["position"] + owner["facing"] * 150.0)
		else:
			owner["buff_time"] = 5.0
			players[owner_id] = owner
			status_text = "%sの計算強化で移動速度が上がった！" % owner["name"]
	else:
		var target_id: int = 2 if owner_id == 1 else 1
		var target: Dictionary = players[target_id]
		var owner_position: Vector2 = owner["position"]
		var target_position: Vector2 = target["position"]
		if not is_big and is_point_in_player_hitbox(get_player_hitbox_center(owner_position), target_position, 170.0):
			apply_damage(target_id, 18 + roundi(float(score) * 0.08), "詠唱者の衝撃波")
		elif is_big:
			spawn_zone(owner_id, score, owner["position"] + owner["facing"] * 110.0)


func spawn_projectile(owner_id: int, score: int, is_big: bool, angle_offset: float) -> void:
	var owner: Dictionary = players[owner_id]
	var owner_facing: Vector2 = owner["facing"]
	var facing: Vector2 = owner_facing.rotated(angle_offset)
	skill_projectiles.append({
		"owner_id": owner_id,
		"position": get_player_hitbox_center(owner["position"]) + facing * (PLAYER_HITBOX_RADIUS_X + SKILL_PROJECTILE_RADIUS),
		"velocity": facing * (540.0 if is_big else 500.0),
		"damage": (24 if is_big else 10) + roundi(float(score) * (0.12 if is_big else 0.1)),
		"lifetime": 2.0 if is_big else 1.6,
		"piercing": is_big,
	})


func spawn_zone(owner_id: int, score: int, zone_position: Vector2) -> void:
	magic_zones.append({"owner_id": owner_id, "position": clamp_to_arena(zone_position), "lifetime": ZONE_DURATION, "damage_timer": 0.0, "damage": 8 + roundi(float(score) * 0.06)})


func update_magic_zones(delta: float) -> void:
	for index in range(magic_zones.size() - 1, -1, -1):
		var zone: Dictionary = magic_zones[index]
		zone["lifetime"] = float(zone["lifetime"]) - delta
		zone["damage_timer"] = float(zone["damage_timer"]) - delta
		if float(zone["damage_timer"]) <= 0.0:
			var target_id: int = 2 if int(zone["owner_id"]) == 1 else 1
			var target: Dictionary = players[target_id]
			var target_position: Vector2 = target["position"]
			var zone_position: Vector2 = zone["position"]
			if is_point_in_player_hitbox(zone_position, target_position, 80.0):
				apply_damage(target_id, int(zone["damage"]), "魔法陣")
			zone["damage_timer"] = 0.8
		if float(zone["lifetime"]) <= 0.0:
			magic_zones.remove_at(index)
		else:
			magic_zones[index] = zone


func update_skill_projectiles(delta: float) -> void:
	for index in range(skill_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = skill_projectiles[index]
		var position_value: Vector2 = projectile["position"] + projectile["velocity"] * delta
		projectile["position"] = position_value
		projectile["lifetime"] = float(projectile["lifetime"]) - delta
		var owner_id: int = int(projectile["owner_id"])
		var target_id: int = 2 if owner_id == 1 else 1
		var target: Dictionary = players[target_id]
		var target_position: Vector2 = target["position"]
		if is_point_in_player_hitbox(position_value, target_position, SKILL_PROJECTILE_RADIUS):
			apply_damage(target_id, int(projectile["damage"]), "ブレード弾")
			status_text = "ブレード弾が%sに命中！" % target["name"]
			if bool(projectile["piercing"]):
				var projectile_velocity: Vector2 = projectile["velocity"]
				var projectile_direction: Vector2 = projectile_velocity.normalized()
				projectile["position"] = position_value + projectile_direction * 48.0
				skill_projectiles[index] = projectile
				continue
			skill_projectiles.remove_at(index)
			continue
		if float(projectile["lifetime"]) <= 0.0 or not ARENA.grow(40.0).has_point(position_value):
			skill_projectiles.remove_at(index)
		else:
			skill_projectiles[index] = projectile


func get_player_hitbox_center(player_position: Vector2) -> Vector2:
	return player_position + PLAYER_HITBOX_OFFSET


func is_point_in_player_hitbox(point: Vector2, player_position: Vector2, padding: float = 0.0) -> bool:
	var center := get_player_hitbox_center(player_position)
	var radius_x: float = PLAYER_HITBOX_RADIUS_X + padding
	var radius_y: float = PLAYER_HITBOX_RADIUS_Y + padding
	var normalized_point := point - center
	return (normalized_point.x * normalized_point.x) / (radius_x * radius_x) + (normalized_point.y * normalized_point.y) / (radius_y * radius_y) <= 1.0


func can_move_player_to(player_id: int, next_position: Vector2) -> bool:
	if network_mode == "practice":
		return true
	var other_id: int = 2 if player_id == 1 else 1
	if not players.has(other_id):
		return true
	var other: Dictionary = players[other_id]
	return not are_player_hitboxes_overlapping(next_position, other["position"])


func are_player_hitboxes_overlapping(first_position: Vector2, second_position: Vector2) -> bool:
	var offset := get_player_hitbox_center(first_position) - get_player_hitbox_center(second_position)
	var combined_radius_x: float = PLAYER_HITBOX_RADIUS_X * 2.0
	var combined_radius_y: float = PLAYER_HITBOX_RADIUS_Y * 2.0
	return (offset.x * offset.x) / (combined_radius_x * combined_radius_x) + (offset.y * offset.y) / (combined_radius_y * combined_radius_y) < 1.0


func clamp_to_arena(position_value: Vector2) -> Vector2:
	return Vector2(
		clampf(position_value.x, ARENA.position.x + PLAYER_HITBOX_RADIUS_X, ARENA.end.x - PLAYER_HITBOX_RADIUS_X),
		clampf(position_value.y, ARENA.position.y + PLAYER_HITBOX_RADIUS_Y, ARENA.end.y - PLAYER_HITBOX_RADIUS_Y)
	)


func apply_damage(target_id: int, damage: int, attack_name: String) -> void:
	var target: Dictionary = players[target_id]
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	target["hit_time"] = 0.20
	if bool(target["focused"]):
		var new_gauge: float = maxf(0.0, float(target["interrupt_gauge"]) - float(damage))
		target["interrupt_gauge"] = new_gauge
		if new_gauge <= 0.0:
			players[target_id] = target
			interrupt_active_challenge(target_id, attack_name)
			if int(target["hp"]) <= 0:
				finish_match(2 if target_id == 1 else 1)
			return
	players[target_id] = target
	if int(target["hp"]) <= 0:
		finish_match(2 if target_id == 1 else 1)


func interrupt_active_challenge(player_id: int, attack_name: String) -> void:
	if challenge_owner == player_id:
		end_active_challenge(false, 0, "%sで中断ゲージが尽きた。課題は失敗した。" % attack_name)
		return
	var player: Dictionary = players[player_id]
	player["focused"] = false
	player["challenge_elapsed"] = 0.0
	player["interrupt_gauge"] = 0.0
	player["interrupt_gauge_max"] = 0.0
	player["small_cooldown"] = TYPING_SKILL_COOLDOWN
	players[player_id] = player
	challenge_panel.visible = false
	challenge_dimmer.visible = false
	typing_input.release_focus()
	challenge_owner = 0
	challenge_target_points.clear()
	update_trace_canvas()
	status_text = "%sの集中は%sで中断された。" % [player["name"], attack_name]


func finish_match(winner_id: int) -> void:
	match_state.match_over = true
	match_state.winner_id = winner_id
	challenge_panel.visible = false
	challenge_dimmer.visible = false
	typing_input.release_focus()
	status_text = "%sの勝利！ Rキーで再戦できます。" % players[winner_id]["name"]
	show_result(winner_id)


func finish_match_by_time() -> void:
	var first_hp: int = players[1]["hp"]
	var second_hp: int = players[2]["hp"]
	if first_hp == second_hp:
		match_state.match_over = true
		match_state.winner_id = 0
		status_text = "時間切れ、引き分け！ Rキーで再戦できます。"
		show_result(0)
	else:
		finish_match(1 if first_hp > second_hp else 2)


func reset_match() -> void:
	show_lobby()


func show_result(winner_id: int) -> void:
	phase = "result"
	result_panel.visible = true
	var result_title: String = "引き分け" if winner_id == 0 else "%sの勝利" % players[winner_id]["name"]
	var first: Dictionary = players[1]
	var second: Dictionary = players[2]
	result_label.text = "%s\n\nP1 %s  残HP %d  成功 %d回  平均 %.1f  最高 %d\nP2 %s  残HP %d  成功 %d回  平均 %.1f  最高 %d" % [result_title, first["name"], first["hp"], first["challenge_count"], average_score(first), first["challenge_best_score"], second["name"], second["hp"], second["challenge_count"], average_score(second), second["challenge_best_score"]]
	if network_mode == "host":
		rpc("receive_network_state", make_network_state())


func rematch_from_result() -> void:
	match_state.reset()
	players = match_state.players
	begin_match()
	result_panel.visible = false


func request_rematch() -> void:
	if network_mode == "client":
		rpc_id(1, "receive_remote_result_action", "rematch")
		return
	rematch_from_result()


func request_return_to_lobby() -> void:
	if network_mode == "client":
		rpc_id(1, "receive_remote_result_action", "lobby")
		return
	if network_mode == "local" or network_mode == "practice":
		show_home()
		return
	show_lobby()


func average_score(player: Dictionary) -> float:
	var count: int = int(player["challenge_count"])
	return 0.0 if count == 0 else float(player["challenge_score_total"]) / float(count)


func create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	player_one_label = make_hud_label(Vector2(40, 28), HORIZONTAL_ALIGNMENT_LEFT)
	player_two_label = make_hud_label(Vector2(820, 28), HORIZONTAL_ALIGNMENT_RIGHT)
	timer_label = make_hud_label(Vector2(500, 28), HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.size = Vector2(280, 44)
	status_label = make_hud_label(Vector2(160, 690), HORIZONTAL_ALIGNMENT_CENTER)
	status_label.size = Vector2(960, 28)
	status_label.add_theme_font_size_override("font_size", 16)

	controls_label = make_hud_label(Vector2(760, 68), HORIZONTAL_ALIGNMENT_RIGHT)
	controls_label.size = Vector2(470, 48)
	controls_label.text = "移動: 矢印キー  通常攻撃: Space\nスキル1/2: 1・2  課題中止: Esc"
	controls_label.add_theme_font_size_override("font_size", 15)
	controls_label.add_theme_color_override("font_color", Color("b7c1d8"))
	gameplay_home_button = Button.new()
	gameplay_home_button.text = "ホームへ戻る"
	gameplay_home_button.position = Vector2(1040, 24)
	gameplay_home_button.size = Vector2(190, 40)
	gameplay_home_button.add_theme_font_size_override("font_size", 18)
	gameplay_home_button.pressed.connect(return_to_home)
	get_child(0).add_child(gameplay_home_button)
	create_challenge_ui(layer)


func set_gameplay_hud_visible(is_visible: bool) -> void:
	player_one_label.visible = is_visible
	player_two_label.visible = is_visible and network_mode == "local"
	timer_label.visible = is_visible
	status_label.visible = false
	controls_label.visible = is_visible and network_mode == "practice"
	gameplay_home_button.visible = is_visible and network_mode in ["practice", "local"]
	if not is_visible:
		challenge_panel.visible = false
		challenge_dimmer.visible = false


func create_lobby_ui() -> void:
	lobby_panel = Panel.new()
	lobby_panel.position = Vector2.ZERO
	lobby_panel.size = Vector2(1280, 720)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b34f5")
	style.border_color = Color("8fa8e8")
	style.set_border_width_all(0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	lobby_panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(lobby_panel)
	lobby_label = Label.new()
	lobby_label.position = Vector2(20, 16)
	lobby_label.size = Vector2(1170, 48)
	lobby_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_label.add_theme_font_size_override("font_size", 28)
	lobby_panel.add_child(lobby_label)
	lobby_p1_preview = TextureRect.new()
	lobby_p1_preview.position = Vector2(135, 115)
	lobby_p1_preview.size = Vector2(300, 260)
	lobby_p1_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lobby_p1_preview.stretch_mode = TextureRect.STRETCH_SCALE
	lobby_panel.add_child(lobby_p1_preview)
	lobby_p2_preview = TextureRect.new()
	lobby_p2_preview.position = Vector2(775, 115)
	lobby_p2_preview.size = Vector2(300, 260)
	lobby_p2_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lobby_p2_preview.stretch_mode = TextureRect.STRETCH_SCALE
	lobby_panel.add_child(lobby_p2_preview)
	lobby_p1_info = make_lobby_info(Vector2(70, 72), Vector2(430, 50))
	lobby_p2_info = make_lobby_info(Vector2(710, 72), Vector2(430, 50))
	lobby_p1_status_icon = make_status_icon(Vector2(340, 72))
	lobby_p2_status_icon = make_status_icon(Vector2(980, 72))
	lobby_p1_left = make_lobby_button("◀", Vector2(95, 410), func(): set_lobby_selection(1, -1))
	lobby_p1_right = make_lobby_button("▶", Vector2(390, 410), func(): set_lobby_selection(1, 1))
	lobby_p1_ready = make_lobby_button("準備完了", Vector2(175, 465), func(): toggle_lobby_ready(1), Vector2(240, 46))
	lobby_p2_left = make_lobby_button("◀", Vector2(735, 410), func(): set_lobby_selection(2, -1))
	lobby_p2_right = make_lobby_button("▶", Vector2(1030, 410), func(): set_lobby_selection(2, 1))
	lobby_p2_ready = make_lobby_button("準備完了", Vector2(815, 465), func(): toggle_lobby_ready(2), Vector2(240, 46))
	lobby_home_button = make_lobby_button("ホームへ戻る", Vector2(40, 24), return_to_home, Vector2(190, 42))


func make_lobby_info(info_position: Vector2, info_size: Vector2) -> Label:
	var label := Label.new()
	label.position = info_position
	label.size = info_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	lobby_panel.add_child(label)
	return label


func make_lobby_button(button_text: String, button_position: Vector2, callback: Callable, button_size := Vector2(90, 46)) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	lobby_panel.add_child(button)
	return button


func make_status_icon(icon_position: Vector2) -> StatusIcon:
	var icon := StatusIcon.new()
	icon.position = icon_position
	icon.size = Vector2(48, 48)
	lobby_panel.add_child(icon)
	return icon


func set_lobby_selection(player_id: int, step: int) -> void:
	if player_id == 1 and network_mode == "client":
		return
	if player_id == 2 and network_mode == "host":
		return
	if player_id == 1:
		p1_selection = posmod(p1_selection + step, 3)
		p1_ready = false
	else:
		p2_selection = posmod(p2_selection + step, 3)
		p2_ready = false
	if network_mode == "client":
		rpc_id(1, "receive_remote_lobby_choice", p2_selection, p2_ready)
	refresh_lobby_label()


func toggle_lobby_ready(player_id: int) -> void:
	if player_id == 1 and network_mode == "client":
		return
	if player_id == 2 and network_mode == "host":
		return
	if player_id == 1:
		p1_ready = not p1_ready
	else:
		p2_ready = not p2_ready
	if network_mode == "client":
		rpc_id(1, "receive_remote_lobby_choice", p2_selection, p2_ready)
	refresh_lobby_label()


func create_result_ui() -> void:
	result_panel = Panel.new()
	result_panel.position = Vector2.ZERO
	result_panel.size = Vector2(1280, 720)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b34f5")
	style.border_color = Color("ffc45e")
	style.set_border_width_all(0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	result_panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(result_panel)
	result_label = Label.new()
	result_label.position = Vector2(330, 170)
	result_label.size = Vector2(620, 270)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 21)
	result_panel.add_child(result_label)
	result_rematch_button = Button.new()
	result_rematch_button.text = "もう一度対戦"
	result_rematch_button.position = Vector2(450, 440)
	result_rematch_button.size = Vector2(170, 36)
	result_rematch_button.pressed.connect(request_rematch)
	result_panel.add_child(result_rematch_button)
	result_lobby_button = Button.new()
	result_lobby_button.text = "ロビーへ戻る"
	result_lobby_button.position = Vector2(660, 440)
	result_lobby_button.size = Vector2(170, 36)
	result_lobby_button.pressed.connect(request_return_to_lobby)
	result_panel.add_child(result_lobby_button)
	result_panel.visible = false


func create_network_ui() -> void:
	network_panel = Panel.new()
	network_panel.position = Vector2.ZERO
	network_panel.size = Vector2(1280, 720)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b34f5")
	style.border_color = Color("71d6ba")
	style.set_border_width_all(0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	network_panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(network_panel)
	var title := Label.new()
	title.text = "オンライン対戦"
	title.position = Vector2(330, 175)
	title.size = Vector2(620, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	network_panel.add_child(title)
	network_address_input = LineEdit.new()
	network_address_input.text = "127.0.0.1:7000"
	network_address_input.placeholder_text = "接続先 IP:ポート"
	network_address_input.position = Vector2(440, 243)
	network_address_input.size = Vector2(400, 38)
	network_panel.add_child(network_address_input)
	var host_button := Button.new()
	host_button.text = "ルームを作成"
	host_button.position = Vector2(440, 300)
	host_button.size = Vector2(185, 42)
	host_button.pressed.connect(start_host)
	network_panel.add_child(host_button)
	var join_button := Button.new()
	join_button.text = "ルームに参加"
	join_button.position = Vector2(655, 300)
	join_button.size = Vector2(185, 42)
	join_button.pressed.connect(join_host)
	network_panel.add_child(join_button)
	var local_button := Button.new()
	local_button.text = "同一PCデバッグで開始"
	local_button.position = Vector2(530, 355)
	local_button.size = Vector2(220, 34)
	local_button.pressed.connect(start_local_debug)
	local_button.visible = false
	network_panel.add_child(local_button)
	network_status_label = Label.new()
	network_status_label.position = Vector2(330, 405)
	network_status_label.size = Vector2(560, 26)
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.add_theme_color_override("font_color", Color("b7c1d8"))
	network_panel.add_child(network_status_label)
	network_back_button = Button.new()
	network_back_button.text = "ホームへ戻る"
	network_back_button.position = Vector2(40, 24)
	network_back_button.size = Vector2(190, 42)
	network_back_button.add_theme_font_size_override("font_size", 18)
	network_back_button.pressed.connect(return_to_home)
	network_panel.add_child(network_back_button)


func make_menu_panel(panel_position: Vector2, panel_size: Vector2, border_color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = Vector2(1280, 720)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b34f5")
	style.border_color = border_color
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(panel)
	return panel


func make_menu_button(parent: Control, text_value: String, button_position: Vector2, button_size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func create_navigation_ui() -> void:
	title_panel = make_menu_panel(Vector2(160, 90), Vector2(960, 540), Color("71d6ba"))
	# ロゴはNode2D側で描画するため、このパネルは枠だけにして覆い隠さない。
	var title_panel_style := StyleBoxFlat.new()
	title_panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	title_panel_style.border_color = Color("71d6ba")
	title_panel_style.set_border_width_all(0)
	title_panel_style.set_corner_radius_all(0)
	title_panel.add_theme_stylebox_override("panel", title_panel_style)
	title_logo = TextureRect.new()
	title_logo.texture = preload("res://assets/ui/skill_battlers_logo.png")
	title_logo.position = Vector2(55, 70)
	title_logo.size = Vector2(850, 250)
	title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode = TextureRect.STRETCH_SCALE
	# ロゴはNode2Dの_drawで固定矩形へ描画する。TextureRectには描画を任せない。
	title_logo.visible = false
	title_panel.add_child(title_logo)
	title_prompt = Label.new()
	title_prompt.text = "Press Space / Enter / Click to Start"
	title_prompt.position = Vector2(200, 390)
	title_prompt.size = Vector2(880, 48)
	title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_prompt.add_theme_font_size_override("font_size", 28)
	title_panel.add_child(title_prompt)

	home_panel = make_menu_panel(Vector2(150, 90), Vector2(980, 540), Color("8fa8e8"))
	var home_title := Label.new()
	home_title.text = "SKILL BATTLE HOME"
	home_title.position = Vector2(180, 24)
	home_title.size = Vector2(920, 50)
	home_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_title.add_theme_font_size_override("font_size", 30)
	home_panel.add_child(home_title)
	make_menu_button(home_panel, "オンライン対戦", Vector2(205, 130), Vector2(400, 260), show_online_menu)
	make_menu_button(home_panel, "練習", Vector2(675, 115), Vector2(370, 75), show_practice_select)
	var character_button := make_menu_button(home_panel, "キャラクター", Vector2(675, 210), Vector2(370, 75), show_character_unavailable)
	character_button.tooltip_text = "キャラクター育成画面は準備中です"
	make_menu_button(home_panel, "デバッグ", Vector2(675, 305), Vector2(370, 75), show_debug_select)

	practice_panel = make_menu_panel(Vector2(210, 90), Vector2(860, 540), Color("71d6ba"))
	practice_preview = Label.new()
	practice_preview.position = Vector2(370, 35)
	practice_preview.size = Vector2(540, 42)
	practice_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	practice_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	practice_preview.add_theme_font_size_override("font_size", 28)
	practice_panel.add_child(practice_preview)
	practice_portrait = make_selection_portrait(practice_panel, Vector2(480, 82), Vector2(320, 250))
	make_menu_button(practice_panel, "◀", Vector2(300, 350), Vector2(90, 55), func(): change_practice_selection(-1))
	make_menu_button(practice_panel, "▶", Vector2(890, 350), Vector2(90, 55), func(): change_practice_selection(1))
	make_menu_button(practice_panel, "このキャラクターで練習", Vector2(470, 430), Vector2(340, 52), start_practice)
	make_menu_button(practice_panel, "戻る", Vector2(230, 20), Vector2(100, 42), show_home)

	debug_panel = make_menu_panel(Vector2(120, 70), Vector2(1040, 580), Color("ffc45e"))
	debug_preview = Label.new()
	debug_preview.position = Vector2(155, 25)
	debug_preview.size = Vector2(970, 40)
	debug_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debug_preview.add_theme_font_size_override("font_size", 25)
	debug_panel.add_child(debug_preview)
	debug_p1_name = make_selection_name(debug_panel, Vector2(210, 64), Vector2(390, 36))
	debug_p2_name = make_selection_name(debug_panel, Vector2(680, 64), Vector2(390, 36))
	debug_p1_portrait = make_selection_portrait(debug_panel, Vector2(235, 102), Vector2(340, 235))
	debug_p2_portrait = make_selection_portrait(debug_panel, Vector2(705, 102), Vector2(340, 235))
	make_menu_button(debug_panel, "P1 ◀", Vector2(210, 350), Vector2(130, 55), func(): change_debug_selection(1, -1))
	make_menu_button(debug_panel, "P1 ▶", Vector2(365, 350), Vector2(130, 55), func(): change_debug_selection(1, 1))
	make_menu_button(debug_panel, "P2 ◀", Vector2(785, 350), Vector2(130, 55), func(): change_debug_selection(2, -1))
	make_menu_button(debug_panel, "P2 ▶", Vector2(940, 350), Vector2(130, 55), func(): change_debug_selection(2, 1))
	debug_control_p1_button = make_menu_button(debug_panel, "P1を操作", Vector2(390, 420), Vector2(220, 42), func(): set_debug_controlled_player(1))
	debug_control_p2_button = make_menu_button(debug_panel, "P2を操作", Vector2(670, 420), Vector2(220, 42), func(): set_debug_controlled_player(2))
	make_menu_button(debug_panel, "デバッグ対戦を開始", Vector2(470, 480), Vector2(340, 52), start_debug_match)
	make_menu_button(debug_panel, "戻る", Vector2(140, 20), Vector2(100, 42), show_home)
	title_panel.visible = false
	home_panel.visible = false
	practice_panel.visible = false
	debug_panel.visible = false


func character_names() -> Array[String]:
	return ["打鍵者", "算術士", "詠唱者"]


func make_selection_name(parent: Control, name_position: Vector2, name_size: Vector2) -> Label:
	var label := Label.new()
	label.position = name_position
	label.size = name_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23)
	parent.add_child(label)
	return label


func make_selection_portrait(parent: Control, portrait_position: Vector2, portrait_size: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.position = portrait_position
	portrait.size = portrait_size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(portrait)
	return portrait


func update_selection_labels() -> void:
	var names := character_names()
	var visual_ids: Array[String] = ["typist", "arithmetician", "chanter"]
	if practice_preview:
		practice_preview.text = names[practice_selection]
		practice_portrait.texture = get_idle_texture(visual_ids[practice_selection])
	if debug_preview:
		debug_preview.text = ""
		debug_p1_name.text = "P1  %s%s" % [names[debug_p1_selection], "（操作対象）" if debug_controlled_player_id == 1 else ""]
		debug_p2_name.text = "P2  %s%s" % [names[debug_p2_selection], "（操作対象）" if debug_controlled_player_id == 2 else ""]
		debug_p1_portrait.texture = get_idle_texture(visual_ids[debug_p1_selection])
		debug_p2_portrait.texture = get_idle_texture(visual_ids[debug_p2_selection])
		if debug_control_p1_button:
			debug_control_p1_button.text = "P1を操作 ✓" if debug_controlled_player_id == 1 else "P1を操作"
		if debug_control_p2_button:
			debug_control_p2_button.text = "P2を操作 ✓" if debug_controlled_player_id == 2 else "P2を操作"


func hide_menu_panels() -> void:
	title_panel.visible = false
	home_panel.visible = false
	practice_panel.visible = false
	debug_panel.visible = false


func show_title() -> void:
	screen = "title"
	title_animation_elapsed = 0.0
	hide_menu_panels()
	title_panel.visible = true
	title_prompt.modulate.a = 1.0
	network_panel.visible = false
	lobby_panel.visible = false
	result_panel.visible = false
	set_gameplay_hud_visible(false)


func update_title_prompt_blink() -> void:
	if not title_prompt:
		return
	var blink_wave := (sin(title_animation_elapsed * TITLE_PROMPT_BLINK_SPEED) + 1.0) * 0.5
	title_prompt.modulate.a = lerpf(0.35, 1.0, blink_wave)


func show_home() -> void:
	screen = "home"
	hide_menu_panels()
	home_panel.visible = true
	network_panel.visible = false
	lobby_panel.visible = false
	result_panel.visible = false
	set_gameplay_hud_visible(false)


func return_to_home() -> void:
	if challenge_owner != 0:
		end_active_challenge(false, 0, "課題を中止した。")
	challenge_owner = 0
	challenge_panel.visible = false
	challenge_dimmer.visible = false
	typing_input.release_focus()
	skill_projectiles.clear()
	magic_zones.clear()
	match_state.reset()
	players = match_state.players
	phase = "lobby"
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	network_mode = "local"
	local_player_id = 1
	p1_ready = false
	p2_ready = false
	network_target_players.clear()
	remote_input = {"move": Vector2.ZERO, "attack": false, "small": false, "big": false}
	show_home()


func show_online_menu() -> void:
	screen = "connection"
	show_connection()


func show_practice_select() -> void:
	screen = "practice_select"
	hide_menu_panels()
	practice_panel.visible = true
	update_selection_labels()
	set_gameplay_hud_visible(false)


func show_debug_select() -> void:
	screen = "debug_select"
	hide_menu_panels()
	debug_panel.visible = true
	update_selection_labels()
	set_gameplay_hud_visible(false)


func show_character_unavailable() -> void:
	status_text = "キャラクター画面は準備中です。"


func change_practice_selection(step: int) -> void:
	practice_selection = posmod(practice_selection + step, 3)
	update_selection_labels()


func change_debug_selection(player_id: int, step: int) -> void:
	if player_id == 1:
		debug_p1_selection = posmod(debug_p1_selection + step, 3)
	else:
		debug_p2_selection = posmod(debug_p2_selection + step, 3)
	update_selection_labels()


func set_debug_controlled_player(player_id: int) -> void:
	debug_controlled_player_id = 2 if player_id == 2 else 1
	update_selection_labels()


func start_practice() -> void:
	network_mode = "practice"
	local_player_id = 1
	p1_selection = practice_selection
	p2_selection = practice_selection
	begin_match()
	screen = "match"
	hide_menu_panels()


func start_debug_match() -> void:
	network_mode = "local"
	local_player_id = debug_controlled_player_id
	p1_selection = debug_p1_selection
	p2_selection = debug_p2_selection
	begin_match()
	screen = "match"
	hide_menu_panels()


func show_connection() -> void:
	phase = "connection"
	screen = "connection"
	hide_menu_panels()
	network_panel.visible = true
	lobby_panel.visible = false
	result_panel.visible = false
	challenge_panel.visible = false
	challenge_dimmer.visible = false
	set_gameplay_hud_visible(false)
	network_status_label.text = "ホスト作成、またはIP:ポートを入力して参加してください。"
	network_back_button.visible = true


func start_local_debug() -> void:
	show_debug_select()


func start_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var result: int = peer.create_server(NETWORK_PORT, 1)
	if result != OK:
		network_status_label.text = "ポート%dを開けませんでした: %s" % [NETWORK_PORT, error_string(result)]
		return
	multiplayer.multiplayer_peer = peer
	network_mode = "host"
	local_player_id = 1
	network_panel.visible = false
	show_lobby()
	status_text = "ルームを作成しました。参加者を待っています。"


func join_host() -> void:
	var address_parts: PackedStringArray = network_address_input.text.strip_edges().split(":", false, 1)
	var host_address: String = address_parts[0] if not address_parts.is_empty() else "127.0.0.1"
	var host_port: int = int(address_parts[1]) if address_parts.size() == 2 else NETWORK_PORT
	var peer := ENetMultiplayerPeer.new()
	var result: int = peer.create_client(host_address, host_port)
	if result != OK:
		network_status_label.text = "接続を開始できませんでした: %s" % error_string(result)
		return
	multiplayer.multiplayer_peer = peer
	network_mode = "client"
	local_player_id = 2
	network_status_label.text = "接続中..."


func _on_peer_connected(peer_id: int) -> void:
	if network_mode == "host":
		status_text = "参加者が接続しました。キャラクターを選択してください。"
		sync_network_state(STATE_SYNC_INTERVAL)


func _on_connected_to_server() -> void:
	network_panel.visible = false
	phase = "lobby"
	screen = "online_waiting"
	rpc_id(1, "request_lobby_state")


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	network_mode = "local"
	show_connection()
	network_status_label.text = "接続に失敗しました。IP:ポートを確認してください。"


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	network_mode = "local"
	show_connection()
	network_status_label.text = "ホストとの接続が切れました。"


func process_client_network_input(_delta: float) -> void:
	if phase == "lobby":
		return
	if phase == "result":
		return
	var move := Vector2.ZERO
	move.x = float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
	move.y = float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
	pending_client_input = {
		"move": move.normalized() if move.length_squared() > 0.0 else Vector2.ZERO,
		"attack": Input.is_key_pressed(KEY_SPACE),
		"small": Input.is_key_pressed(KEY_1),
		"big": Input.is_key_pressed(KEY_2),
	}
	rpc_id(1, "receive_remote_input", pending_client_input)


func sync_network_state(delta: float) -> void:
	if network_mode != "host":
		return
	network_sync_elapsed += delta
	if network_sync_elapsed < STATE_SYNC_INTERVAL:
		return
	network_sync_elapsed = 0.0
	rpc("receive_network_state", make_network_state())


func make_network_state() -> Dictionary:
	return {
		"phase": phase,
		"players": players,
		"time_remaining": match_state.time_remaining,
		"match_over": match_state.match_over,
		"winner_id": match_state.winner_id,
		"p1_selection": p1_selection,
		"p2_selection": p2_selection,
		"p1_ready": p1_ready,
		"p2_ready": p2_ready,
		"countdown_remaining": countdown_remaining,
		"status_text": status_text,
		"skill_projectiles": skill_projectiles,
		"magic_zones": magic_zones,
		"challenge_owner": challenge_owner,
		"challenge_skill": challenge_skill,
		"challenge_prompt": challenge_prompt,
	}


@rpc("authority", "unreliable")
func receive_network_state(state: Dictionary) -> void:
	if network_mode != "client":
		return
	var incoming_players: Dictionary = state["players"]
	if network_target_players.is_empty():
		players = incoming_players.duplicate(true)
	else:
		for player_id in [1, 2]:
			var current_player: Dictionary = players[player_id]
			var incoming_player: Dictionary = incoming_players[player_id]
			var current_position: Vector2 = current_player["position"]
			current_player = incoming_player.duplicate(true)
			current_player["position"] = current_position
			players[player_id] = current_player
	network_target_players = incoming_players.duplicate(true)
	match_state.players = players
	match_state.time_remaining = float(state["time_remaining"])
	match_state.match_over = bool(state["match_over"])
	match_state.winner_id = int(state["winner_id"])
	phase = str(state["phase"])
	if phase == "lobby":
		screen = "online_waiting"
	elif phase == "match" or phase == "countdown" or phase == "result":
		screen = "match"
	p1_selection = int(state["p1_selection"])
	p2_selection = int(state["p2_selection"])
	p1_ready = bool(state["p1_ready"])
	p2_ready = bool(state["p2_ready"])
	countdown_remaining = float(state["countdown_remaining"])
	status_text = str(state["status_text"])
	skill_projectiles = state["skill_projectiles"]
	magic_zones = state["magic_zones"]
	challenge_owner = int(state["challenge_owner"])
	challenge_skill = str(state["challenge_skill"])
	challenge_prompt = str(state["challenge_prompt"])
	challenge_target_points = make_trace_target(challenge_skill.begins_with("big")) if challenge_skill.ends_with("trace") else PackedVector2Array()
	update_client_ui_from_state()


func interpolate_network_players(delta: float) -> void:
	if network_target_players.is_empty() or phase != "match":
		return
	for player_id in [1, 2]:
		var current_player: Dictionary = players[player_id]
		var target_player: Dictionary = network_target_players[player_id]
		var current_position: Vector2 = current_player["position"]
		var target_position: Vector2 = target_player["position"]
		current_player["position"] = current_position.lerp(target_position, minf(delta * 14.0, 1.0))
		players[player_id] = current_player


func update_client_ui_from_state() -> void:
	set_gameplay_hud_visible(phase == "match" or phase == "countdown")
	lobby_panel.visible = phase == "lobby"
	if phase == "lobby":
		refresh_lobby_label()
	if phase == "result":
		if not result_panel.visible:
			show_result(match_state.winner_id)
		return
	result_panel.visible = false
	var player_is_challenging: bool = challenge_owner == local_player_id and phase == "match"
	challenge_dimmer.visible = player_is_challenging
	challenge_panel.visible = player_is_challenging
	if player_is_challenging:
		challenge_prompt_label.text = challenge_prompt
		typing_input.visible = not challenge_skill.ends_with("trace")
		update_challenge_ui(float(players[local_player_id]["challenge_elapsed"]))
		if typing_input.visible and not typing_input.has_focus():
			typing_input.grab_focus()
	else:
		typing_input.release_focus()


@rpc("any_peer", "reliable")
func request_lobby_state() -> void:
	if network_mode != "host":
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id > 0:
		rpc_id(sender_id, "receive_network_state", make_network_state())


@rpc("any_peer", "reliable")
func receive_remote_lobby_choice(selection: int, ready: bool) -> void:
	if network_mode != "host" or multiplayer.get_remote_sender_id() <= 0:
		return
	p2_selection = clampi(selection, 0, 2)
	p2_ready = ready


@rpc("any_peer", "unreliable")
func receive_remote_input(input_state: Dictionary) -> void:
	if network_mode != "host" or multiplayer.get_remote_sender_id() <= 0:
		return
	var input_move: Vector2 = input_state.get("move", Vector2.ZERO)
	remote_input = {
		"move": input_move.limit_length(1.0),
		"attack": bool(input_state.get("attack", false)),
		"small": bool(input_state.get("small", false)),
		"big": bool(input_state.get("big", false)),
	}


@rpc("any_peer", "reliable")
func receive_remote_challenge_input(submitted_text: String) -> void:
	if network_mode == "host" and multiplayer.get_remote_sender_id() > 0 and challenge_owner == 2:
		_on_typing_submitted(submitted_text)


@rpc("any_peer", "reliable")
func receive_remote_trace(trace_points: PackedVector2Array) -> void:
	if network_mode != "host" or multiplayer.get_remote_sender_id() <= 0 or challenge_owner != 2:
		return
	challenge_trace_points = trace_points
	var trace_score: int = evaluate_trace()
	end_active_challenge(trace_score >= (BIG_PASSING_SCORE if challenge_skill.begins_with("big") else 45), trace_score, "なぞりに失敗した。")


@rpc("any_peer", "reliable")
func receive_remote_result_action(action: String) -> void:
	if network_mode != "host" or multiplayer.get_remote_sender_id() <= 0 or phase != "result":
		return
	if action == "rematch":
		rematch_from_result()
	else:
		show_lobby()


func show_lobby() -> void:
	phase = "lobby"
	screen = "online_waiting" if network_mode in ["host", "client"] else "debug_waiting"
	set_gameplay_hud_visible(false)
	match_state.reset()
	players = match_state.players
	p1_ready = false
	p2_ready = false
	challenge_owner = 0
	skill_projectiles.clear()
	magic_zones.clear()
	challenge_panel.visible = false
	challenge_dimmer.visible = false
	lobby_panel.visible = true
	lobby_home_button.visible = network_mode in ["host", "client"]
	result_panel.visible = false
	status_text = "キャラクターを選択してください。"
	update_lobby(0.0)


func update_lobby(_delta: float) -> void:
	refresh_lobby_label()
	if p1_ready and p2_ready:
		phase = "countdown"
		countdown_remaining = 3.0
		lobby_panel.visible = false
		status_text = "試合開始まで 3"


func refresh_lobby_label() -> void:
	var names: Array[String] = ["打鍵者", "算術士", "詠唱者"]
	var visual_ids: Array[String] = ["typist", "arithmetician", "chanter"]
	lobby_label.text = "オンライン対戦 - 待機画面"
	var local_side := 2 if network_mode == "client" else 1
	var remote_connected := multiplayer.has_multiplayer_peer() and (network_mode == "client" or multiplayer.get_peers().size() > 0)
	lobby_p1_preview.visible = local_side == 1
	lobby_p2_preview.visible = local_side == 2
	lobby_p1_info.text = "あなた\n%s" % names[p1_selection] if local_side == 1 else ("対戦相手\n%s" % names[p1_selection] if remote_connected else "対戦相手\n入室待ち")
	lobby_p2_info.text = "あなた\n%s" % names[p2_selection] if local_side == 2 else ("対戦相手\n%s" % names[p2_selection] if remote_connected else "対戦相手\n入室待ち")
	set_lobby_status_icon(lobby_p1_status_icon, p1_ready, local_side == 1 or remote_connected)
	set_lobby_status_icon(lobby_p2_status_icon, p2_ready, local_side == 2 or remote_connected)
	if local_side == 1:
		lobby_p1_preview.texture = get_idle_texture(visual_ids[p1_selection])
		lobby_p2_preview.texture = null
	else:
		lobby_p1_preview.texture = null
		lobby_p2_preview.texture = get_idle_texture(visual_ids[p2_selection])
	for button in [lobby_p1_left, lobby_p1_right, lobby_p1_ready]:
		button.visible = local_side == 1
	for button in [lobby_p2_left, lobby_p2_right, lobby_p2_ready]:
		button.visible = local_side == 2


func set_lobby_status_icon(icon: StatusIcon, is_ready: bool, is_present: bool) -> void:
	icon.visible = is_present
	if is_present:
		icon.set_ready(is_ready)


func get_idle_texture(visual_id: String) -> Texture2D:
	if visual_id == "arithmetician":
		return preload("res://assets/characters/arithmetician_idle.png")
	if visual_id == "chanter":
		return preload("res://assets/characters/chanter_idle.png")
	return preload("res://assets/characters/typist_idle.png")


func begin_match() -> void:
	phase = "match"
	screen = "match"
	lobby_panel.visible = false
	network_panel.visible = false
	set_gameplay_hud_visible(true)
	match_state.match_over = false
	match_state.time_remaining = MATCH_DURATION
	configure_player(1, p1_selection)
	configure_player(2, p2_selection)
	status_text = "開始！ 通常攻撃と課題スキルを使い分けよう。"


func configure_player(player_id: int, selection: int) -> void:
	var player: Dictionary = players[player_id]
	var ids: Array[String] = ["blade", "arithmetic", "chanter"]
	var visual_ids: Array[String] = ["typist", "arithmetician", "chanter"]
	var names: Array[String] = ["打鍵者", "算術士", "詠唱者"]
	var colors: Array[Color] = [Color("ef6b73"), Color("7498ff"), Color("b98aff")]
	player["character_id"] = ids[selection]
	player["visual_id"] = visual_ids[selection]
	player["name"] = names[selection]
	player["color"] = colors[selection]
	player["normal_damage"] = 12 if selection == 0 else (10 if selection == 1 else 11)
	player["hp"] = 100
	player["position"] = Vector2(300, 390) if player_id == 1 else Vector2(980, 390)
	player["facing"] = Vector2.RIGHT if player_id == 1 else Vector2.LEFT
	players[player_id] = player


func create_challenge_ui(layer: CanvasLayer) -> void:
	var challenge_layer: ChallengeLayer = ChallengeLayerData.new()
	add_child(challenge_layer)
	layer = challenge_layer
	challenge_dimmer = ColorRect.new()
	challenge_dimmer.position = Vector2.ZERO
	challenge_dimmer.size = Vector2(1280, 720)
	challenge_dimmer.color = Color(0.02, 0.04, 0.10, 0.58)
	challenge_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	challenge_dimmer.visible = false
	layer.add_child(challenge_dimmer)
	challenge_panel = PanelContainer.new()
	challenge_panel.position = Vector2(250, 185)
	challenge_panel.size = Vector2(780, 400)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("111b34e8")
	panel_style.border_color = Color("ef6b73")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	challenge_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(challenge_panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.add_theme_constant_override("margin_left", 22)
	content.add_theme_constant_override("margin_top", 18)
	content.add_theme_constant_override("margin_right", 22)
	content.add_theme_constant_override("margin_bottom", 18)
	challenge_panel.add_child(content)
	challenge_time_bar = ProgressBar.new()
	challenge_time_bar.min_value = 0.0
	challenge_time_bar.max_value = 1.0
	challenge_time_bar.value = 1.0
	challenge_time_bar.show_percentage = false
	challenge_time_bar.custom_minimum_size = Vector2(0, 8)
	var time_bar_style := StyleBoxFlat.new()
	time_bar_style.bg_color = Color("ffc45e")
	time_bar_style.set_corner_radius_all(4)
	challenge_time_bar.add_theme_stylebox_override("fill", time_bar_style)
	var time_bar_bg := StyleBoxFlat.new()
	time_bar_bg.bg_color = Color("263452")
	time_bar_bg.set_corner_radius_all(4)
	challenge_time_bar.add_theme_stylebox_override("background", time_bar_bg)
	content.add_child(challenge_time_bar)
	challenge_title_label = Label.new()
	challenge_title_label.add_theme_font_size_override("font_size", 26)
	challenge_title_label.add_theme_color_override("font_color", Color("ffc1c6"))
	challenge_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(challenge_title_label)
	challenge_prompt_label = Label.new()
	challenge_prompt_label.add_theme_font_size_override("font_size", 20)
	challenge_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(challenge_prompt_label)
	challenge_trace_canvas = TraceCanvas.new()
	challenge_trace_canvas.custom_minimum_size = Vector2(0, 235)
	challenge_trace_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	challenge_trace_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(challenge_trace_canvas)
	typing_input = LineEdit.new()
	typing_input.placeholder_text = "ここに入力して Enter"
	typing_input.add_theme_font_size_override("font_size", 18)
	typing_input.text_submitted.connect(_on_typing_submitted)
	content.add_child(typing_input)
	challenge_progress_label = Label.new()
	challenge_progress_label.add_theme_font_size_override("font_size", 16)
	challenge_progress_label.add_theme_color_override("font_color", Color("b7c1d8"))
	challenge_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(challenge_progress_label)
	challenge_panel.visible = false


func update_challenge_ui(elapsed: float) -> void:
	var challenge_player: Dictionary = players[challenge_owner] if challenge_owner in players else {}
	var skill_name := "スキル２" if challenge_skill.begins_with("big") else "スキル１"
	challenge_title_label.text = "%s　発動！！" % skill_name
	challenge_prompt_label.text = challenge_prompt
	var limit: float = BIG_CHALLENGE_LIMIT if challenge_skill.begins_with("big") else (TRACE_CHALLENGE_LIMIT if challenge_skill.ends_with("trace") else (ARITHMETIC_CHALLENGE_LIMIT if challenge_skill.ends_with("arithmetic") else TYPING_CHALLENGE_LIMIT))
	challenge_progress_label.text = "残り %.1f秒　|　Esc: 中止" % maxf(0.0, limit - elapsed)
	challenge_time_bar.value = clampf(1.0 - elapsed / limit, 0.0, 1.0)
	update_trace_canvas()


func make_hud_label(label_position: Vector2, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = Vector2(420, 44)
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("f1f5ff"))
	get_child(0).add_child(label)
	return label


func update_hud() -> void:
	if network_mode == "local":
		player_one_label.text = format_debug_hud_player(1)
		player_two_label.text = format_debug_hud_player(2)
		player_two_label.visible = true
	else:
		var own_player: Dictionary = players[local_player_id]
		var focus_suffix := "  集中中" if bool(own_player["focused"]) else ""
		player_one_label.text = "自分  %s  HP %d%s\n通常 %.1fs  スキル1 %.1fs  スキル2 %.1fs" % [own_player["name"], own_player["hp"], focus_suffix, float(own_player["attack_cooldown"]), float(own_player["small_cooldown"]), float(own_player["big_cooldown"])]
	timer_label.text = "残り %02d秒" % ceili(match_state.time_remaining)


func format_debug_hud_player(player_id: int) -> String:
	var player: Dictionary = players[player_id]
	var focus_suffix := "  集中中" if bool(player["focused"]) else ""
	var control_suffix := "  操作中" if player_id == debug_controlled_player_id else ""
	return "P%d  %s%s%s  HP %d\n通常 %.1fs  スキル1 %.1fs  スキル2 %.1fs" % [player_id, player["name"], control_suffix, focus_suffix, player["hp"], float(player["attack_cooldown"]), float(player["small_cooldown"]), float(player["big_cooldown"])]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("080d1d"))
	if screen == "title":
		# 元画像の解像度に影響されず、固定位置のまま左から順に表示する。
		var logo_rect := Rect2(215, 170, 850, 260)
		var logo_progress := clampf(title_animation_elapsed / TITLE_LOGO_ANIMATION_DURATION, 0.0, 1.0)
		var visible_width := logo_rect.size.x * logo_progress
		var visible_logo_rect := Rect2(logo_rect.position, Vector2(visible_width, logo_rect.size.y))
		var source_rect := Rect2(0.0, 0.0, title_logo.texture.get_width() * logo_progress, title_logo.texture.get_height())
		draw_texture_rect_region(title_logo.texture, visible_logo_rect, source_rect)
		return
	if screen != "match":
		return
	draw_arena()
	# 条件式の配列リテラルは未型付きArrayになるため、ここでは推論型で受ける。
	var draw_player_ids := [1] if network_mode == "practice" else [1, 2]
	for player_id in draw_player_ids:
		draw_player(player_id, players[player_id])
	for projectile in skill_projectiles:
		draw_skill_projectile(projectile)
	for zone in magic_zones:
		var zone_ratio: float = clampf(float(zone["lifetime"]) / ZONE_DURATION, 0.0, 1.0)
		draw_circle(zone["position"], 80.0, Color(0.55, 0.35, 0.95, 0.12 + zone_ratio * 0.10))
		draw_arc(zone["position"], 80.0, 0.0, TAU, 32, Color("c7a6ff"), 3.0, true)


func draw_arena() -> void:
	draw_rect(ARENA, Color("385d3d"), true)
	var tile_size := 48
	for y in range(int(ARENA.position.y), int(ARENA.end.y), tile_size):
		for x in range(int(ARENA.position.x), int(ARENA.end.x), tile_size):
			var tile_index := int(x / tile_size) + int(y / tile_size)
			var tile_color := Color("426b46") if tile_index % 2 == 0 else Color("3d6543")
			draw_rect(Rect2(x + 1, y + 1, tile_size - 2, tile_size - 2), tile_color, true)
	for x in range(int(ARENA.position.x), int(ARENA.end.x), tile_size):
		draw_rect(Rect2(x, ARENA.position.y, tile_size - 2, 14), Color("6e6a56"), true)
		draw_rect(Rect2(x, ARENA.end.y - 14, tile_size - 2, 14), Color("6e6a56"), true)
	for y in range(int(ARENA.position.y) + 14, int(ARENA.end.y) - 14, tile_size):
		draw_rect(Rect2(ARENA.position.x, y, 14, tile_size - 2), Color("6e6a56"), true)
		draw_rect(Rect2(ARENA.end.x - 14, y, 14, tile_size - 2), Color("6e6a56"), true)
	draw_rect(ARENA, Color("9a967c"), false, 3.0)


func get_character_texture(visual_id: String) -> Texture2D:
	if visual_id == "arithmetician":
		return ARITHMETICIAN_TEXTURE
	if visual_id == "chanter":
		return CHANTER_TEXTURE
	return TYPIST_TEXTURE


func get_sprite_direction_column(facing: Vector2) -> int:
	var octant: int = int(posmod(roundi(facing.angle() / (PI / 4.0)), 8))
	match octant:
		0: return 6 # 右
		1: return 7 # 下右
		2: return 0 # 下
		3: return 1 # 下左
		4: return 2 # 左
		5: return 3 # 上左
		6: return 4 # 上
		_: return 5 # 上右


func draw_player(player_id: int, player: Dictionary) -> void:
	var position_value: Vector2 = player["position"]
	var facing: Vector2 = player["facing"]
	if bool(player["focused"]):
		var focus_center := get_player_hitbox_center(position_value)
		draw_arc(focus_center, PLAYER_HITBOX_RADIUS_Y + 15.0, 0.0, TAU, 28, Color("ffd0a1"), 2.5, true)
	var is_moving: bool = bool(player.get("is_moving", false))
	var character_texture: Texture2D = get_character_texture(str(player.get("visual_id", "typist")))
	var sprite_column: int = get_sprite_direction_column(facing)
	var sprite_row: int = 0 if not is_moving else 1 + (int(floor(character_animation_elapsed * 8.0)) % 4)
	var source_rect := Rect2(sprite_column * 64.0, sprite_row * 64.0, 64.0, 64.0)
	var sprite_rect := Rect2(position_value + Vector2(-32.0, -44.0), Vector2(64.0, 64.0))
	var sprite_tint := Color(4.0, 4.0, 4.0, 1.0) if float(player["hit_time"]) > 0.0 else Color.WHITE
	draw_texture_rect_region(character_texture, sprite_rect, source_rect, sprite_tint)
	if network_mode in ["host", "client"] and player_id == local_player_id:
		draw_string(ThemeDB.fallback_font, position_value + Vector2(-42.0, -91.0), "あなた", HORIZONTAL_ALIGNMENT_CENTER, 84.0, 18, Color("f1f5ff"))
	if player["attack_time"] > 0.0:
		var angle := facing.angle()
		draw_arc(position_value, SLASH_RANGE, angle - SLASH_ARC_HALF_ANGLE, angle + SLASH_ARC_HALF_ANGLE, 18, Color("fff3ad"), 7.0, true)
	var health_ratio: float = float(player["hp"]) / 100.0
	var health_rect := Rect2(position_value + Vector2(-30, -54), Vector2(60, 7))
	draw_rect(health_rect, Color("070b14"), true)
	draw_rect(Rect2(health_rect.position, Vector2(health_rect.size.x * health_ratio, health_rect.size.y)), Color("52d6ad"), true)
	if bool(player["focused"]) and float(player["interrupt_gauge_max"]) > 0.0:
		var gauge_ratio: float = clampf(float(player["interrupt_gauge_display"]) / float(player["interrupt_gauge_max"]), 0.0, 1.0)
		var gauge_rect := Rect2(position_value + Vector2(-30, -43), Vector2(60, 5))
		draw_rect(gauge_rect, Color("070b14"), true)
		draw_rect(Rect2(gauge_rect.position, Vector2(gauge_rect.size.x * gauge_ratio, gauge_rect.size.y)), Color("ffc45e"), true)


func draw_skill_projectile(projectile: Dictionary) -> void:
	var position_value: Vector2 = projectile["position"]
	var velocity: Vector2 = projectile["velocity"]
	var direction := velocity.normalized()
	draw_circle(position_value, SKILL_PROJECTILE_RADIUS + 5.0, Color("ffca7055"))
	draw_line(position_value - direction * 14.0, position_value + direction * 8.0, Color("fff0b5"), 5.0)
	draw_circle(position_value + direction * 9.0, 5.0, Color("ffbd5f"))


func _input(event: InputEvent) -> void:
	if screen == "title":
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			play_ui_click()
			show_home()
			return
	if screen == "home" or screen == "practice_select" or screen == "debug_select" or screen == "connection":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and phase == "match" and challenge_owner == 0 and network_mode in ["practice", "local"]:
			return_to_home()
			return
		if phase == "lobby":
			if network_mode == "client":
				if event.keycode == KEY_1 or event.keycode == KEY_7:
					p2_selection = 0
				elif event.keycode == KEY_2 or event.keycode == KEY_8:
					p2_selection = 1
				elif event.keycode == KEY_3 or event.keycode == KEY_9:
					p2_selection = 2
				elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
					p2_ready = not p2_ready
				rpc_id(1, "receive_remote_lobby_choice", p2_selection, p2_ready)
				return
			if event.keycode == KEY_1:
				p1_selection = 0
			elif event.keycode == KEY_2:
				p1_selection = 1
			elif event.keycode == KEY_3:
				p1_selection = 2
			elif event.keycode == KEY_7 and network_mode != "host":
				p2_selection = 0
			elif event.keycode == KEY_8 and network_mode != "host":
				p2_selection = 1
			elif event.keycode == KEY_9 and network_mode != "host":
				p2_selection = 2
			elif event.keycode == KEY_SPACE:
				p1_ready = not p1_ready
			elif event.keycode == KEY_ENTER and network_mode != "host":
				p2_ready = not p2_ready
			return
		if event.keycode == KEY_ESCAPE and challenge_owner != 0:
			end_active_challenge(false, 0, "課題を中止した。")
			return
	if event is InputEventMouseButton and challenge_owner != 0 and challenge_skill.ends_with("trace"):
		if network_mode == "host" and challenge_owner != 1:
			return
		if challenge_trace_canvas == null or not challenge_trace_canvas.get_global_rect().has_point(event.position):
			return
		if event.pressed:
			challenge_trace_points.clear()
			challenge_trace_points.append(event.position - challenge_trace_canvas.global_position)
			update_trace_canvas()
		else:
			if network_mode == "client":
				rpc_id(1, "receive_remote_trace", challenge_trace_points)
				return
			var trace_score: int = evaluate_trace()
			end_active_challenge(trace_score >= (BIG_PASSING_SCORE if challenge_skill.begins_with("big") else 45), trace_score, "なぞりに失敗した。")
		return
	if event is InputEventMouseMotion and challenge_owner != 0 and challenge_skill.ends_with("trace") and event.button_mask != 0:
		if network_mode == "host" and challenge_owner != 1:
			return
		if challenge_trace_canvas != null and challenge_trace_canvas.get_global_rect().has_point(event.position):
			challenge_trace_points.append(event.position - challenge_trace_canvas.global_position)
			update_trace_canvas()


func evaluate_trace() -> int:
	if challenge_trace_points.size() < 2 or challenge_target_points.size() < 2:
		return 0
	var start_score := clampf(100.0 - challenge_trace_points[0].distance_to(challenge_target_points[0]) * 0.8, 0.0, 100.0)
	var end_score := clampf(100.0 - challenge_trace_points[challenge_trace_points.size() - 1].distance_to(challenge_target_points[challenge_target_points.size() - 1]) * 0.8, 0.0, 100.0)
	var distance_total := 0.0
	for point in challenge_trace_points:
		distance_total += distance_to_trace_target(point)
	var distance_score := clampf(100.0 - distance_total / float(challenge_trace_points.size()) * 1.8, 0.0, 100.0)
	var covered := 0
	var sample_count := 0
	for index in range(challenge_target_points.size() - 1):
		var segment_start := challenge_target_points[index]
		var segment_end := challenge_target_points[index + 1]
		var segment_length := segment_start.distance_to(segment_end)
		var steps := maxi(1, ceili(segment_length / 24.0))
		for step in range(steps + 1):
			var target_point := segment_start.lerp(segment_end, float(step) / float(steps))
			sample_count += 1
			for input_point in challenge_trace_points:
				if input_point.distance_to(target_point) <= 28.0:
					covered += 1
					break
	var coverage_score := 0.0 if sample_count == 0 else float(covered) / float(sample_count) * 100.0
	return roundi(start_score * 0.20 + end_score * 0.20 + distance_score * 0.25 + coverage_score * 0.35)


func distance_to_trace_target(point: Vector2) -> float:
	var closest := INF
	for index in range(challenge_target_points.size() - 1):
		var start_point := challenge_target_points[index]
		var end_point := challenge_target_points[index + 1]
		var segment := end_point - start_point
		var ratio := clampf((point - start_point).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		closest = minf(closest, point.distance_to(start_point + segment * ratio))
	return closest
