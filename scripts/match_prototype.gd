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
		if input_points.size() >= 2:
			draw_polyline(input_points, Color("fff2b0"), 5.0, true)
		for point in input_points:
			draw_circle(point, 3.0, Color("fff2b0"))

const ARENA := Rect2(0, 0, 2520, 1160)
## プレイヤーの座標は足元付近のアンカー。見た目の胴体に合わせて、
## アンカーから少し上にずらした縦長の楕円を当たり判定として使う。
const PLAYER_HITBOX_RADIUS_X := 20.0
const PLAYER_HITBOX_RADIUS_Y := 30.0
const PLAYER_HITBOX_OFFSET := Vector2(0.0, -12.0)
const PLAYER_SPEED := 280.0
const SLASH_RANGE := 74.0
const SLASH_DAMAGE := 12
const SLASH_ARC_HALF_ANGLE := deg_to_rad(55.0)
const NORMAL_ATTACK_OUTER_RANGE := SLASH_RANGE + PLAYER_HITBOX_RADIUS_X
const NORMAL_ATTACK_HAND_OFFSET := 10.0
const WEAPON_HANDLE_UV := Vector2(0.07, 0.94)
const WEAPON_TIP_UV := Vector2(0.93, 0.07)
const ATTACK_COOLDOWN := 0.5
const ATTACK_DURATION := 0.28
const NORMAL_ATTACK_FRAME_COUNT := 8
const MATCH_DURATION := 90.0
const FOCUS_SPEED_MULTIPLIER := 0.35
const TYPING_CHALLENGE_LIMIT := 6.0
const TYPING_SKILL_COOLDOWN := 2.0
const SKILL_PROJECTILE_RADIUS := 10.0
const TYPING_INTERRUPT_GAUGE := 30.0
const INTERRUPT_DISPLAY_SPEED := 180.0
const BIG_CHALLENGE_LIMIT := 10.0
const BIG_TYPING_CHALLENGE_LIMIT := 20.0
const BIG_PASSING_SCORE := 70
const ARITHMETIC_CHALLENGE_LIMIT := 7.0
const TRACE_CHALLENGE_LIMIT := 8.0
const CHALLENGE_MISS_TIME_PENALTY := 1.8
const TYPING_PROJECTILE_INTERVAL := 0.5
const CHANTER_ZONE_DELAY := 0.2
const ZONE_DURATION := 5.0
const NETWORK_PORT := 7000
const STATE_SYNC_INTERVAL := 0.05
const TITLE_LOGO_ANIMATION_DURATION := 1.2
const TITLE_PROMPT_BLINK_SPEED := 4.0
const UI_CLICK_SOUND: AudioStream = preload("res://assets/audio/ui_click.wav")
const DOT_GOTHIC_FONT: FontFile = preload("res://resources/DotGothic16/DotGothic16-Regular.ttf")
const UI_LOGO: Texture2D = preload("res://assets/ui/logo_title.png")
const UI_PANEL_FRAME: Texture2D = preload("res://assets/ui/panel_frame.png")
const UI_BUTTON_PRIMARY: Texture2D = preload("res://assets/ui/button_primary.png")
const UI_BUTTON_SECONDARY: Texture2D = preload("res://assets/ui/button_secondary.png")
const UI_CARD_CHARACTER: Texture2D = preload("res://assets/ui/card_character.png")
const UI_INPUT_INVITE_CODE: Texture2D = preload("res://assets/ui/input_invite_code.png")
const UI_BUTTON_READY: Texture2D = preload("res://assets/ui/button_ready.png")
const UI_MENU_BACKGROUND: Texture2D = preload("res://assets/ui/menu_background.png")

const MatchStateData = preload("res://scripts/match_state.gd")
const ChallengeLayerData = preload("res://scripts/challenge_layer.gd")
const MenuLayoutData = preload("res://scripts/data/menu_layout.gd")
const TYPIST_TEXTURE: Texture2D = preload("res://assets/characters/sprites/typist_pixel_8dir.png")
const ARITHMETICIAN_TEXTURE: Texture2D = preload("res://assets/characters/sprites/arithmetician_pixel_8dir.png")
const CHANTER_TEXTURE: Texture2D = preload("res://assets/characters/sprites/chanter_pixel_8dir.png")
const TYPIST_NORMAL_ATTACK_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_typist.png")
const ARITHMETICIAN_NORMAL_ATTACK_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_arithmetician.png")
const CHANTER_NORMAL_ATTACK_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_chanter.png")
const TYPIST_NORMAL_ATTACK_WEAPON_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_typist_weapon.png")
const ARITHMETICIAN_NORMAL_ATTACK_WEAPON_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_arithmetician_weapon.png")
const CHANTER_NORMAL_ATTACK_WEAPON_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_chanter_weapon.png")
const TYPIST_NORMAL_ATTACK_PARTICLE_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_typist_particle.png")
const ARITHMETICIAN_NORMAL_ATTACK_PARTICLE_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_arithmetician_particle.png")
const CHANTER_NORMAL_ATTACK_PARTICLE_TEXTURE: Texture2D = preload("res://assets/effects/normal_attack_chanter_particle.png")

var match_state: MatchState = MatchStateData.new()
var players: Dictionary = match_state.players
var status_text := "開始！ 距離を取りながら相手に通常攻撃を当てよう。"
var skill_projectiles: Array[Dictionary] = []
var magic_zones: Array[Dictionary] = []
var decoys: Array[Dictionary] = []
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
var challenge_definition: ChallengeDefinition
var challenge_typing_index: int = 0
var challenge_miss_flash: float = 0.0
var challenge_shake: float = 0.0
var challenge_typed_characters: String = ""
var challenge_base_position := Vector2(250.0, 185.0)
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
var menu_background: TextureRect
@export var menu_layout: MenuLayoutData


class NormalAttackHitArea:
	var origin: Vector2
	var facing: Vector2
	var outer_range: float
	var half_angle: float

	func _init(area_origin: Vector2, area_facing: Vector2, area_outer_range: float, area_half_angle: float) -> void:
		origin = area_origin
		facing = area_facing.normalized()
		outer_range = area_outer_range
		half_angle = area_half_angle

	func intersects_player_hitbox(target_center: Vector2, radius_x: float, radius_y: float) -> bool:
		if contains_point(target_center) or is_point_inside_ellipse(origin, target_center, radius_x, radius_y):
			return true
		# 楕円外周を十分細かくサンプリングし、実際の扇形内へ入る点だけを命中として扱う。
		# 通常攻撃開始時だけ呼ばれるため、見た目と一致する判定を優先する。
		const ELLIPSE_SAMPLE_COUNT := 64
		for sample_index in range(ELLIPSE_SAMPLE_COUNT):
			var angle := TAU * float(sample_index) / float(ELLIPSE_SAMPLE_COUNT)
			var ellipse_point := target_center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
			if contains_point(ellipse_point):
				return true
		return false

	func contains_point(point: Vector2) -> bool:
		var offset := point - origin
		var forward_distance := facing.dot(offset)
		return forward_distance >= 0.0 and offset.length_squared() <= outer_range * outer_range and absf(facing.cross(offset)) <= forward_distance * tan(half_angle)

	func is_point_inside_ellipse(point: Vector2, ellipse_center: Vector2, radius_x: float, radius_y: float) -> bool:
		var offset := point - ellipse_center
		return (offset.x * offset.x) / (radius_x * radius_x) + (offset.y * offset.y) / (radius_y * radius_y) <= 1.0


func _ready() -> void:
	if menu_layout == null:
		menu_layout = MenuLayoutData.new()
	create_ui_sound_player()
	create_menu_background()
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


func create_menu_background() -> void:
	menu_background = TextureRect.new()
	menu_background.texture = UI_MENU_BACKGROUND
	menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_background.stretch_mode = TextureRect.STRETCH_SCALE
	menu_background.position = Vector2.ZERO
	menu_background.size = Vector2(1280, 720)
	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_background.z_index = -1
	add_child(menu_background)


func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(play_ui_click)


func play_ui_click() -> void:
	ui_click_player.play()


func create_challenge_definitions() -> void:
	var small_typing: ChallengeDefinition = ChallengeDefinition.new()
	small_typing.challenge_type = "typing"
	small_typing.candidates = PackedStringArray(["Track", "Chase", "Trace", "Trail", "Stalk"])
	small_typing.time_limit_seconds = TYPING_CHALLENGE_LIMIT
	small_typing.passing_score = 0
	challenge_definitions["blade_small"] = small_typing
	var big_typing: ChallengeDefinition = ChallengeDefinition.new()
	big_typing.challenge_type = "typing"
	big_typing.candidates = PackedStringArray(["Hammer Down and Shatter the Ground", "Smash the Earth with a Crushing Blow", "Break the Ground with a Mighty Hammer", "Slam the Hammer and Split the Earth", "Crush the Floor with a Thunderous Strike", "Strike the Ground and Tear It Apart", "Bring the Hammer Down and Crack the Land"])
	big_typing.time_limit_seconds = BIG_TYPING_CHALLENGE_LIMIT
	big_typing.passing_score = BIG_PASSING_SCORE
	challenge_definitions["blade_big"] = big_typing
	var small_arithmetic: ChallengeDefinition = ChallengeDefinition.new()
	small_arithmetic.challenge_type = "arithmetic"
	small_arithmetic.candidates = arithmetic_candidates()
	small_arithmetic.time_limit_seconds = ARITHMETIC_CHALLENGE_LIMIT
	challenge_definitions["arithmetic_small"] = small_arithmetic
	var big_arithmetic: ChallengeDefinition = ChallengeDefinition.new()
	big_arithmetic.challenge_type = "arithmetic"
	big_arithmetic.candidates = arithmetic_candidates()
	big_arithmetic.time_limit_seconds = BIG_CHALLENGE_LIMIT
	big_arithmetic.passing_score = BIG_PASSING_SCORE
	challenge_definitions["arithmetic_big"] = big_arithmetic


func arithmetic_candidates() -> PackedStringArray:
	return PackedStringArray(["22 + 4 * 16", "4 + 8 * 9 + 12", "16 + 17 + 18 + 19", "164 + 255", "18 + 5 * 14", "7 + 6 * 8 + 15", "21 + 22 + 23 + 24", "176 + 248", "32 + 7 * 11", "9 + 5 * 12 + 18", "14 + 16 + 18 + 20", "187 + 326", "25 + 6 * 13", "8 + 9 * 7 + 14", "15 + 17 + 19 + 21"])


func _process(delta: float) -> void:
	character_animation_elapsed += delta
	challenge_miss_flash = maxf(0.0, challenge_miss_flash - delta)
	challenge_shake = maxf(0.0, challenge_shake - delta)
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
	update_decoys(delta)
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
	var is_attacking := float(player["attack_time"]) > 0.0
	if is_attacking:
		# 通常攻撃は開始時の位置と向きで完了まで固定する。
		player["is_moving"] = false
	elif network_mode == "local" and player_id != debug_controlled_player_id:
		direction = Vector2.ZERO
	elif network_mode == "host" and player_id == 2:
		direction = remote_input["move"]
	else:
		direction.x = float(Input.is_key_pressed(right_key)) - float(Input.is_key_pressed(left_key))
		direction.y = float(Input.is_key_pressed(down_key)) - float(Input.is_key_pressed(up_key))
	var moved := false
	if not is_attacking and direction.length_squared() > 0.0:
		direction = direction.normalized()
		player["facing"] = direction
		var speed_multiplier: float = (FOCUS_SPEED_MULTIPLIER if bool(player["focused"]) else 1.0) * (1.25 if float(player["buff_time"]) > 0.0 else 1.0)
		var next_position := clamp_to_arena(player["position"] + direction * PLAYER_SPEED * speed_multiplier * delta)
		if can_move_player_to(player_id, next_position):
			player["position"] = next_position
			moved = true
	player["is_moving"] = moved if not is_attacking else false
	player["attack_cooldown"] = maxf(0.0, player["attack_cooldown"] - delta)
	player["attack_time"] = maxf(0.0, player["attack_time"] - delta)
	player["hit_time"] = maxf(0.0, player["hit_time"] - delta)
	player["small_cooldown"] = maxf(0.0, float(player["small_cooldown"]) - delta)
	player["big_cooldown"] = maxf(0.0, float(player["big_cooldown"]) - delta)
	player["buff_time"] = maxf(0.0, float(player["buff_time"]) - delta)
	if float(player["buff_time"]) <= 0.0:
		player["attack_damage_buff"] = 0
	player["invisible_time"] = maxf(0.0, float(player.get("invisible_time", 0.0)) - delta)
	player["invisible_flicker"] = maxf(0.0, float(player.get("invisible_flicker", 0.0)) - delta)
	if float(player["invisible_time"]) > 0.0 and float(player["invisible_flicker"]) <= 0.0:
		player["invisible_flicker"] = 2.5
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
	var attack_facing: Vector2 = player["facing"]
	if attack_facing.length_squared() <= 0.0:
		attack_facing = Vector2.RIGHT
	else:
		attack_facing = attack_facing.normalized()
	player["attack_facing"] = attack_facing
	player["facing"] = attack_facing
	players[player_id] = player
	var target_id := 2 if player_id == 1 else 1
	var target: Dictionary = players[target_id]
	var hit_area := get_normal_attack_hit_area(player["position"], player["attack_facing"])
	var target_center := get_player_hitbox_center(target["position"])
	if hit_area.intersects_player_hitbox(target_center, PLAYER_HITBOX_RADIUS_X, PLAYER_HITBOX_RADIUS_Y):
		apply_damage(target_id, int(player["normal_damage"]) + int(player.get("attack_damage_buff", 0)), "%sの斬撃" % player["name"])
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
	challenge_typing_index = 0
	challenge_typed_characters = ""
	challenge_definition = null
	if character_id == "blade":
		var typing_definition: ChallengeDefinition = challenge_definitions["blade_big" if is_big else "blade_small"]
		challenge_definition = typing_definition
		challenge_prompt = typing_definition.candidates[randi_range(0, typing_definition.candidates.size() - 1)]
		challenge_answer = challenge_prompt
		challenge_skill = "big_typing" if is_big else "small_typing"
	elif character_id == "arithmetic":
		var arithmetic_definition: ChallengeDefinition = challenge_definitions["arithmetic_big" if is_big else "arithmetic_small"]
		challenge_definition = arithmetic_definition
		challenge_prompt = arithmetic_definition.candidates[randi_range(0, arithmetic_definition.candidates.size() - 1)] + " = ?"
		challenge_answer = str(evaluate_arithmetic(challenge_prompt.trim_suffix(" = ?")))
		challenge_skill = "big_arithmetic" if is_big else "small_arithmetic"
	else:
		challenge_definition = ChallengeDefinition.new()
		challenge_definition.challenge_type = "tracing"
		challenge_definition.no_time_limit = true
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
	challenge_miss_flash = 0.0
	challenge_shake = 0.0
	var show_local_challenge: bool = network_mode != "host" or owner_id == 1
	challenge_dimmer.visible = show_local_challenge
	challenge_panel.visible = show_local_challenge
	typing_input.visible = not challenge_skill.ends_with("trace")
	challenge_trace_canvas.visible = challenge_skill.ends_with("trace")
	typing_input.text = ""
	if typing_input.visible and show_local_challenge:
		typing_input.grab_focus()
	apply_challenge_layout(character_id)
	status_text = "%sが%sの集中を開始！" % [player["name"], "スキル2" if is_big else "スキル1"]
	update_challenge_ui(0.0)
	update_trace_canvas()


func evaluate_arithmetic(expression: String) -> int:
	var total := 0
	for add_term in expression.split("+"):
		var product := 1
		for factor in add_term.strip_edges().split("*"):
			product *= int(factor.strip_edges())
		total += product
	return total


func apply_challenge_layout(character_id: String) -> void:
	match character_id:
		"blade":
			challenge_base_position = Vector2(320.0, 465.0)
			challenge_panel.size = Vector2(640.0, 240.0)
		"arithmetic":
			challenge_base_position = Vector2(55.0, 410.0)
			challenge_panel.size = Vector2(300.0, 290.0)
		_:
			challenge_base_position = Vector2(250.0, 185.0)
			challenge_panel.size = Vector2(780.0, 400.0)
	challenge_panel.position = challenge_base_position


func make_trace_target(is_big: bool) -> PackedVector2Array:
	if not is_big:
		var circle_center := Vector2(340, 118)
		var circle_points := PackedVector2Array()
		for index in range(49):
			var angle := float(index) * TAU / 48.0
			circle_points.append(circle_center + Vector2.from_angle(angle) * 92.0)
		return circle_points
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
	var limit: float = get_challenge_time_limit()
	if limit <= 0.0:
		return
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
	if submitted_text != challenge_answer:
		player["challenge_errors"] = int(player["challenge_errors"]) + 1
		player["challenge_elapsed"] = minf(get_challenge_time_limit(), float(player["challenge_elapsed"]) + CHALLENGE_MISS_TIME_PENALTY)
		players[challenge_owner] = player
		challenge_miss_flash = 0.22
		challenge_shake = 0.22
		typing_input.text = ""
		status_text = "入力ミス！ 残り時間が減少した。"
		update_challenge_ui(float(player["challenge_elapsed"]))
		return
		return
	var elapsed: float = float(player["challenge_elapsed"])
	var limit: float = get_challenge_time_limit()
	var score: int = clampi(roundi(100.0 - elapsed / limit * 40.0), 0, 100)
	if challenge_skill.ends_with("typing"):
		challenge_typed_characters = submitted_text
	var typing_success := challenge_skill == "big_typing" or not challenge_skill.begins_with("big")
	end_active_challenge(typing_success or score >= BIG_PASSING_SCORE, score, "")


func get_challenge_time_limit() -> float:
	if challenge_skill.ends_with("trace") or (challenge_definition != null and challenge_definition.no_time_limit):
		return 0.0
	if challenge_skill == "big_typing":
		return BIG_TYPING_CHALLENGE_LIMIT
	return BIG_CHALLENGE_LIMIT if challenge_skill.begins_with("big") else (TRACE_CHALLENGE_LIMIT if challenge_skill.ends_with("trace") else (ARITHMETIC_CHALLENGE_LIMIT if challenge_skill.ends_with("arithmetic") else TYPING_CHALLENGE_LIMIT))


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
	challenge_trace_points.clear()
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
		if not is_big:
			for index in range(challenge_typed_characters.length()):
				spawn_projectile(owner_id, score, false, 0.0, float(index) * TYPING_PROJECTILE_INTERVAL, challenge_typed_characters[index])
		else:
			for angle in [-PI / 3.0, 0.0, PI / 3.0]:
				spawn_projectile(owner_id, score, true, angle)
	elif character_id == "arithmetic":
		if not is_big:
			for index in range(30):
				var angle := TAU * float(index) / 30.0 + randf_range(-0.18, 0.18)
				var radius := randf_range(60.0, 620.0)
				var decoy_origin := clamp_to_arena(owner["position"] + Vector2.from_angle(angle) * radius)
				decoys.append({"owner_id": owner_id, "visual_id": owner.get("visual_id", "arithmetician"), "facing": owner.get("facing", Vector2.DOWN), "position": decoy_origin, "origin": decoy_origin, "lifetime": lerpf(20.0, 30.0, float(score) / 100.0), "sway_timer": randf_range(2.0, 3.0)})
			owner["buff_time"] = lerpf(20.0, 30.0, float(score) / 100.0)
			owner["attack_damage_buff"] = 8
			players[owner_id] = owner
		else:
			owner["buff_time"] = lerpf(10.0, 20.0, float(score) / 100.0)
			owner["attack_damage_buff"] = 10
			owner["invisible_time"] = owner["buff_time"]
			owner["invisible_flicker"] = 0.0
			players[owner_id] = owner
			status_text = "%sが最適解へ収束した！" % owner["name"]
	else:
		if not is_big:
			for index in range(3):
				var active_duration := 2.5 if index == 2 else 2.0
				spawn_zone(owner_id, score, Vector2.ZERO, 1.5 * float(index), 0.3, active_duration)
		else:
			for cycle in range(3):
				for shot in range(16):
					spawn_projectile(owner_id, score, true, TAU * float(shot) / 16.0, float(cycle * 16 + shot) * 0.08)


func spawn_projectile(owner_id: int, score: int, is_big: bool, angle_offset: float, delay: float = 0.0, chip: String = "") -> void:
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
		"delay": delay,
		"chip": chip,
		"launched": false,
	})


func spawn_zone(owner_id: int, score: int, zone_position: Vector2, delay: float = 0.0, damage_delay: float = 0.0, active_duration: float = 1.0) -> void:
	magic_zones.append({"owner_id": owner_id, "position": clamp_to_arena(zone_position), "lifetime": 0.0, "active_duration": active_duration, "delay": delay, "damage_timer": damage_delay, "damage": 8 + roundi(float(score) * 0.06), "spawned": false, "damage_started": false, "damage_flash": 0.0, "pulse_time": 0.0, "damage_applied": false})


func update_magic_zones(delta: float) -> void:
	for index in range(magic_zones.size() - 1, -1, -1):
		var zone: Dictionary = magic_zones[index]
		zone["delay"] = maxf(0.0, float(zone.get("delay", 0.0)) - delta)
		if not bool(zone.get("spawned", false)) and float(zone["delay"]) <= 0.0:
			var target_id: int = 2 if int(zone["owner_id"]) == 1 else 1
			var target: Dictionary = players[target_id]
			zone["position"] = clamp_to_arena(target["position"])
			zone["spawned"] = true
			zone["lifetime"] = float(zone.get("active_duration", 1.0))
			zone["damage_timer"] = 0.3
		if bool(zone.get("spawned", false)):
			zone["lifetime"] = float(zone["lifetime"]) - delta
			zone["damage_timer"] = float(zone["damage_timer"]) - delta
			zone["damage_flash"] = maxf(0.0, float(zone.get("damage_flash", 0.0)) - delta)
			zone["pulse_time"] = float(zone.get("pulse_time", 0.0)) + delta
			if float(zone["damage_timer"]) <= 0.0 and not bool(zone.get("damage_started", false)):
				zone["damage_started"] = true
				zone["damage_flash"] = 0.18
			if bool(zone.get("damage_started", false)) and not bool(zone.get("damage_applied", false)):
				var target_id: int = 2 if int(zone["owner_id"]) == 1 else 1
				var target: Dictionary = players[target_id]
				if is_point_in_player_hitbox(zone["position"], target["position"], 80.0):
					apply_damage(target_id, int(zone["damage"]), "魔法陣")
				zone["damage_applied"] = true
		if bool(zone.get("spawned", false)) and float(zone["lifetime"]) <= 0.0:
			magic_zones.remove_at(index)
		else:
			magic_zones[index] = zone


func update_decoys(delta: float) -> void:
	for index in range(decoys.size() - 1, -1, -1):
		var decoy: Dictionary = decoys[index]
		decoy["lifetime"] = float(decoy["lifetime"]) - delta
		decoy["sway_timer"] = float(decoy["sway_timer"]) - delta
		if float(decoy["sway_timer"]) <= 0.0:
			decoy["sway_timer"] = randf_range(2.0, 3.0)
			decoy["position"] = decoy["origin"] + Vector2(randf_range(-24.0, 24.0), randf_range(-18.0, 18.0))
		if float(decoy["lifetime"]) <= 0.0:
			decoys.remove_at(index)
		else:
			decoys[index] = decoy


func update_skill_projectiles(delta: float) -> void:
	for index in range(skill_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = skill_projectiles[index]
		projectile["delay"] = maxf(0.0, float(projectile.get("delay", 0.0)) - delta)
		if float(projectile["delay"]) > 0.0:
			skill_projectiles[index] = projectile
			continue
		if str(projectile.get("chip", "")) != "" and not bool(projectile.get("launched", false)):
			var launch_owner_id := int(projectile["owner_id"])
			var launch_target_id := 2 if launch_owner_id == 1 else 1
			var launch_origin: Vector2 = players[launch_owner_id]["position"]
			var launch_target: Vector2 = players[launch_target_id]["position"]
			var launch_direction := (launch_target - launch_origin).normalized()
			projectile["position"] = launch_origin
			projectile["velocity"] = launch_direction * 500.0
			projectile["launched"] = true
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


func get_normal_attack_hit_area(player_position: Vector2, attack_facing: Vector2) -> NormalAttackHitArea:
	var normalized_facing := attack_facing.normalized()
	var attack_origin := get_player_hitbox_center(player_position) + normalized_facing * NORMAL_ATTACK_HAND_OFFSET
	return NormalAttackHitArea.new(attack_origin, normalized_facing, NORMAL_ATTACK_OUTER_RANGE, SLASH_ARC_HALF_ANGLE)


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
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color("8fa8e8")
	style.set_border_width_all(0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	lobby_panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(lobby_panel)
	add_menu_logo(lobby_panel, Vector2(500, 12), Vector2(280, 186))
	add_menu_texture(lobby_panel, UI_PANEL_FRAME, Vector2(220, 175), Vector2(840, 420))
	add_menu_texture(lobby_panel, UI_CARD_CHARACTER, Vector2(280, 220), Vector2(340, 360))
	add_menu_texture(lobby_panel, UI_CARD_CHARACTER, Vector2(660, 220), Vector2(340, 360))
	lobby_label = Label.new()
	lobby_label.position = Vector2(20, 170)
	lobby_label.size = Vector2(1170, 48)
	lobby_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_label.add_theme_font_size_override("font_size", 28)
	lobby_panel.add_child(lobby_label)
	lobby_p1_preview = TextureRect.new()
	lobby_p1_preview.position = Vector2(325, 285)
	lobby_p1_preview.size = Vector2(245, 210)
	lobby_p1_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lobby_p1_preview.stretch_mode = TextureRect.STRETCH_SCALE
	lobby_panel.add_child(lobby_p1_preview)
	lobby_p2_preview = TextureRect.new()
	lobby_p2_preview.position = Vector2(710, 285)
	lobby_p2_preview.size = Vector2(245, 210)
	lobby_p2_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lobby_p2_preview.stretch_mode = TextureRect.STRETCH_SCALE
	lobby_panel.add_child(lobby_p2_preview)
	lobby_p1_info = make_lobby_info(Vector2(290, 230), Vector2(320, 52))
	lobby_p2_info = make_lobby_info(Vector2(675, 230), Vector2(320, 52))
	lobby_p1_status_icon = make_status_icon(Vector2(555, 235))
	lobby_p2_status_icon = make_status_icon(Vector2(940, 235))
	lobby_p1_left = make_lobby_button("◀", Vector2(300, 500), func(): set_lobby_selection(1, -1))
	lobby_p1_right = make_lobby_button("▶", Vector2(515, 500), func(): set_lobby_selection(1, 1))
	lobby_p1_ready = make_lobby_button("準備完了", Vector2(390, 620), func(): toggle_lobby_ready(1), Vector2(250, 58))
	lobby_p2_left = make_lobby_button("◀", Vector2(685, 500), func(): set_lobby_selection(2, -1))
	lobby_p2_right = make_lobby_button("▶", Vector2(900, 500), func(): set_lobby_selection(2, 1))
	lobby_p2_ready = make_lobby_button("準備完了", Vector2(640, 620), func(): toggle_lobby_ready(2), Vector2(250, 58))
	lobby_home_button = make_lobby_button("ホームへ戻る", Vector2(32, 24), return_to_home, Vector2(210, 52))


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
	if button_text == "準備完了":
		add_menu_texture(lobby_panel, UI_BUTTON_READY, button_position, button_size)
		var ready_button := Button.new()
		ready_button.text = button_text
		ready_button.position = button_position
		ready_button.size = button_size
		ready_button.add_theme_font_size_override("font_size", 20)
		ready_button.add_theme_color_override("font_color", Color("fff0c9"))
		ready_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		ready_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		ready_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		ready_button.pressed.connect(callback)
		lobby_panel.add_child(ready_button)
		return ready_button
	return add_menu_asset_button(lobby_panel, button_text, button_position, button_size, callback, button_size.x >= 180.0)


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
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color("71d6ba")
	style.set_border_width_all(0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	network_panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(network_panel)
	add_menu_logo(network_panel, menu_layout.online_logo_position, menu_layout.online_logo_size)
	add_menu_texture(network_panel, UI_PANEL_FRAME, menu_layout.online_panel_position, menu_layout.online_panel_size)
	var title := Label.new()
	title.text = "オンライン対戦"
	title.position = menu_layout.online_title_position
	title.size = menu_layout.online_title_size
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ff78b8"))
	network_panel.add_child(title)
	add_menu_texture(network_panel, UI_INPUT_INVITE_CODE, menu_layout.online_address_frame_position, menu_layout.online_address_frame_size)
	network_address_input = LineEdit.new()
	network_address_input.text = "127.0.0.1:7000"
	network_address_input.placeholder_text = "接続先 IP:ポート"
	network_address_input.position = menu_layout.online_address_input_position
	network_address_input.size = menu_layout.online_address_input_size
	network_panel.add_child(network_address_input)
	var host_button := add_menu_asset_button(network_panel, "ルームを作成", menu_layout.online_host_button_position, menu_layout.online_action_button_size, start_host, true)
	host_button.add_theme_font_size_override("font_size", 23)
	var join_button := add_menu_asset_button(network_panel, "ルームに参加", menu_layout.online_join_button_position, menu_layout.online_action_button_size, join_host, false)
	join_button.add_theme_font_size_override("font_size", 23)
	var local_button := Button.new()
	local_button.text = "同一PCデバッグで開始"
	local_button.position = Vector2(530, 355)
	local_button.size = Vector2(220, 34)
	local_button.pressed.connect(start_local_debug)
	local_button.visible = false
	network_panel.add_child(local_button)
	network_status_label = Label.new()
	network_status_label.position = menu_layout.online_status_position
	network_status_label.size = menu_layout.online_status_size
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.add_theme_color_override("font_color", Color("b7c1d8"))
	network_status_label.add_theme_font_size_override("font_size", 20)
	network_panel.add_child(network_status_label)
	network_back_button = add_menu_asset_button(network_panel, "ホームへ戻る", Vector2(32, 24), Vector2(210, 52), return_to_home, false)


func make_menu_panel(panel_position: Vector2, panel_size: Vector2, border_color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = Vector2(1280, 720)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = border_color
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(panel)
	return panel


func make_menu_button(parent: Control, text_value: String, button_position: Vector2, button_size: Vector2, callback: Callable) -> Button:
	return add_menu_asset_button(parent, text_value, button_position, button_size, callback, button_size.x >= 180.0)


func add_menu_texture(parent: Control, texture: Texture2D, texture_position: Vector2, texture_size: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	# expand_mode の変更時にTextureRectが素材の原寸へ戻るため、先にモードを固定する。
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.position = texture_position
	image.size = texture_size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image


func add_menu_logo(parent: Control, logo_position: Vector2, logo_size: Vector2) -> TextureRect:
	return add_menu_texture(parent, UI_LOGO, logo_position, logo_size)


func add_menu_asset_button(parent: Control, text_value: String, button_position: Vector2, button_size: Vector2, callback: Callable, primary: bool) -> Button:
	add_menu_texture(parent, UI_BUTTON_PRIMARY if primary else UI_BUTTON_SECONDARY, button_position, button_size)
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("fff0c9"))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func add_menu_panel_button(parent: Control, text_value: String, button_position: Vector2, button_size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color("ff9ac2"))
	button.add_theme_color_override("font_hover_color", Color("fff0c9"))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	title_logo.texture = UI_LOGO
	title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode = TextureRect.STRETCH_SCALE
	title_logo.position = Vector2(260, 85)
	title_logo.size = Vector2(760, 460)
	# ロゴはNode2Dの_drawで固定矩形へ描画する。TextureRectには描画を任せない。
	title_logo.visible = false
	title_panel.add_child(title_logo)
	title_prompt = Label.new()
	title_prompt.text = "Press Space / Enter / Click to Start"
	title_prompt.position = Vector2(200, 565)
	title_prompt.size = Vector2(880, 48)
	title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_prompt.add_theme_font_size_override("font_size", 28)
	title_panel.add_child(title_prompt)

	home_panel = make_menu_panel(Vector2(150, 90), Vector2(980, 540), Color("8fa8e8"))
	add_menu_logo(home_panel, Vector2(490, 20), Vector2(300, 200))
	add_menu_texture(home_panel, UI_PANEL_FRAME, Vector2(165, 235), Vector2(470, 345))
	add_menu_panel_button(home_panel, "オンライン対戦", Vector2(205, 280), Vector2(390, 250), show_online_menu)
	make_menu_button(home_panel, "練習", Vector2(680, 235), Vector2(400, 130), show_practice_select)
	var character_button := make_menu_button(home_panel, "キャラクター", Vector2(680, 355), Vector2(400, 130), show_character_unavailable)
	character_button.tooltip_text = "キャラクター育成画面は準備中です"
	make_menu_button(home_panel, "デバッグ", Vector2(680, 475), Vector2(400, 130), show_debug_select)

	practice_panel = make_menu_panel(Vector2(210, 90), Vector2(860, 540), Color("71d6ba"))
	add_menu_logo(practice_panel, Vector2(490, 12), Vector2(300, 200))
	add_menu_texture(practice_panel, UI_PANEL_FRAME, Vector2(280, 205), Vector2(720, 385))
	practice_preview = Label.new()
	practice_preview.position = Vector2(370, 195)
	practice_preview.size = Vector2(540, 42)
	practice_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	practice_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	practice_preview.add_theme_font_size_override("font_size", 28)
	practice_panel.add_child(practice_preview)
	practice_portrait = make_selection_portrait(practice_panel, Vector2(495, 258), Vector2(300, 230))
	make_menu_button(practice_panel, "◀", Vector2(325, 415), Vector2(95, 55), func(): change_practice_selection(-1))
	make_menu_button(practice_panel, "▶", Vector2(860, 415), Vector2(95, 55), func(): change_practice_selection(1))
	make_menu_button(practice_panel, "このキャラクターで練習", Vector2(470, 570), Vector2(340, 58), start_practice)
	make_menu_button(practice_panel, "戻る", Vector2(32, 24), Vector2(190, 52), show_home)

	debug_panel = make_menu_panel(Vector2(120, 70), Vector2(1040, 580), Color("ffc45e"))
	add_menu_logo(debug_panel, Vector2(490, 6), Vector2(300, 200))
	add_menu_texture(debug_panel, UI_PANEL_FRAME, Vector2(245, 190), Vector2(790, 405))
	debug_preview = Label.new()
	debug_preview.position = Vector2(155, 182)
	debug_preview.size = Vector2(970, 40)
	debug_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debug_preview.add_theme_font_size_override("font_size", 25)
	debug_panel.add_child(debug_preview)
	debug_p1_name = make_selection_name(debug_panel, Vector2(285, 230), Vector2(330, 36))
	debug_p2_name = make_selection_name(debug_panel, Vector2(665, 230), Vector2(330, 36))
	debug_p1_portrait = make_selection_portrait(debug_panel, Vector2(300, 270), Vector2(290, 200))
	debug_p2_portrait = make_selection_portrait(debug_panel, Vector2(690, 270), Vector2(290, 200))
	make_menu_button(debug_panel, "◀", Vector2(300, 465), Vector2(90, 50), func(): change_debug_selection(1, -1))
	make_menu_button(debug_panel, "▶", Vector2(500, 465), Vector2(90, 50), func(): change_debug_selection(1, 1))
	make_menu_button(debug_panel, "◀", Vector2(690, 465), Vector2(90, 50), func(): change_debug_selection(2, -1))
	make_menu_button(debug_panel, "▶", Vector2(890, 465), Vector2(90, 50), func(): change_debug_selection(2, 1))
	debug_control_p1_button = make_menu_button(debug_panel, "P1を操作", Vector2(310, 530), Vector2(270, 50), func(): set_debug_controlled_player(1))
	debug_control_p2_button = make_menu_button(debug_panel, "P2を操作", Vector2(700, 530), Vector2(270, 50), func(): set_debug_controlled_player(2))
	make_menu_button(debug_panel, "デバッグ対戦を開始", Vector2(470, 625), Vector2(340, 56), start_debug_match)
	make_menu_button(debug_panel, "戻る", Vector2(32, 24), Vector2(190, 52), show_home)
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
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = portrait_position
	portrait.size = portrait_size
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
	# 背景TextureRectより前面のUIレイヤーでロゴを表示する。
	title_logo.visible = true
	menu_background.visible = true
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
	menu_background.visible = true
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
	decoys.clear()
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
	menu_background.visible = true
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
		"decoys": decoys,
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
	decoys = state.get("decoys", [])
	var incoming_challenge_owner := int(state["challenge_owner"])
	var incoming_challenge_skill := str(state["challenge_skill"])
	if challenge_owner != incoming_challenge_owner or challenge_skill != incoming_challenge_skill:
		challenge_trace_points.clear()
	challenge_owner = incoming_challenge_owner
	challenge_skill = incoming_challenge_skill
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
		apply_challenge_layout(str(players[local_player_id]["character_id"]))
		challenge_prompt_label.text = challenge_prompt
		typing_input.visible = not challenge_skill.ends_with("trace")
		challenge_trace_canvas.visible = challenge_skill.ends_with("trace")
		update_challenge_ui(float(players[local_player_id]["challenge_elapsed"]))
		if typing_input.visible and not typing_input.has_focus():
			typing_input.grab_focus()
	else:
		challenge_trace_canvas.visible = false
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
		return preload("res://assets/characters/portraits/arithmetician_idle.png")
	if visual_id == "chanter":
		return preload("res://assets/characters/portraits/chanter_idle.png")
	return preload("res://assets/characters/portraits/typist_idle.png")


func begin_match() -> void:
	reset_match_runtime_state()
	phase = "match"
	screen = "match"
	menu_background.visible = false
	lobby_panel.visible = false
	network_panel.visible = false
	set_gameplay_hud_visible(true)
	match_state.match_over = false
	match_state.time_remaining = MATCH_DURATION
	configure_player(1, p1_selection)
	configure_player(2, p2_selection)
	status_text = "開始！ 通常攻撃と課題スキルを使い分けよう。"


func reset_match_runtime_state() -> void:
	skill_projectiles.clear()
	magic_zones.clear()
	decoys.clear()
	challenge_owner = 0
	challenge_skill = ""
	challenge_prompt = ""
	challenge_answer = ""
	challenge_typed_characters = ""
	challenge_trace_points.clear()
	challenge_target_points.clear()
	challenge_miss_flash = 0.0
	challenge_shake = 0.0
	if challenge_panel:
		challenge_panel.visible = false
	if challenge_dimmer:
		challenge_dimmer.visible = false
	if typing_input:
		typing_input.text = ""
		typing_input.release_focus()


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
	player["focused"] = false
	player["challenge_elapsed"] = 0.0
	player["attack_cooldown"] = 0.0
	player["attack_time"] = 0.0
	player["hit_time"] = 0.0
	player["buff_time"] = 0.0
	player["attack_damage_buff"] = 0
	player["invisible_time"] = 0.0
	player["invisible_flicker"] = 0.0
	player["small_cooldown"] = 0.0
	player["big_cooldown"] = 0.0
	player["interrupt_gauge"] = 0.0
	player["interrupt_gauge_max"] = 0.0
	player["interrupt_gauge_display"] = 0.0
	player["position"] = Vector2(300, 390) if player_id == 1 else Vector2(2260, 390)
	player["facing"] = Vector2.RIGHT if player_id == 1 else Vector2.LEFT
	player["attack_facing"] = player["facing"]
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
	var limit: float = get_challenge_time_limit()
	if limit <= 0.0:
		challenge_progress_label.text = "時間制限なし　|　ボタンを離して判定　|　Esc: 中止"
		challenge_time_bar.value = 1.0
	else:
		challenge_progress_label.text = "残り %.1f秒　|　Esc: 中止" % maxf(0.0, limit - elapsed)
		challenge_time_bar.value = clampf(1.0 - elapsed / limit, 0.0, 1.0)
	if challenge_panel:
		challenge_panel.modulate = Color(1.0, 0.38, 0.38) if challenge_miss_flash > 0.0 else Color.WHITE
		challenge_panel.position = challenge_base_position + (Vector2(sin(challenge_shake * 180.0) * 6.0, 0.0) if challenge_shake > 0.0 else Vector2.ZERO)
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
	if screen == "match":
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("080d1d"))
	if screen == "title":
		# 元画像の解像度に影響されず、固定位置のまま左から順に表示する。
		var logo_rect := Rect2(260, 85, 760, 460)
		var logo_progress := clampf(title_animation_elapsed / TITLE_LOGO_ANIMATION_DURATION, 0.0, 1.0)
		var visible_width := logo_rect.size.x * logo_progress
		var visible_logo_rect := Rect2(logo_rect.position, Vector2(visible_width, logo_rect.size.y))
		var source_rect := Rect2(0.0, 0.0, title_logo.texture.get_width() * logo_progress, title_logo.texture.get_height())
		draw_texture_rect_region(title_logo.texture, visible_logo_rect, source_rect)
		return
	if screen != "match":
		return
	draw_set_transform(get_world_draw_offset())
	draw_arena()
	# 条件式の配列リテラルは未型付きArrayになるため、ここでは推論型で受ける。
	var draw_player_ids := [1] if network_mode == "practice" else [1, 2]
	for player_id in draw_player_ids:
		draw_player(player_id, players[player_id])
	for projectile in skill_projectiles:
		draw_skill_projectile(projectile)
	for decoy in decoys:
		var decoy_owner_id := int(decoy["owner_id"])
		var alpha := 0.22 if decoy_owner_id == local_player_id else 0.72
		draw_decoy(decoy, alpha)
	for zone in magic_zones:
		if not bool(zone.get("spawned", false)):
			continue
		var zone_alpha: float = 0.18
		if bool(zone.get("damage_started", false)):
			zone_alpha = 0.95 if float(zone.get("damage_flash", 0.0)) > 0.0 else 0.44 + sin(float(zone.get("pulse_time", 0.0)) * 9.0) * 0.16
		draw_circle(zone["position"], 80.0, Color(0.55, 0.35, 0.95, zone_alpha))
		draw_arc(zone["position"], 80.0, 0.0, TAU, 32, Color("c7a6ff"), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func get_world_draw_offset() -> Vector2:
	var camera_player_id := 1
	if network_mode == "local":
		camera_player_id = debug_controlled_player_id
	elif network_mode != "practice":
		camera_player_id = local_player_id
	if not players.has(camera_player_id):
		return Vector2.ZERO
	return get_viewport_rect().size * 0.5 - Vector2(players[camera_player_id]["position"])


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


func get_normal_attack_texture(visual_id: String) -> Texture2D:
	if visual_id == "arithmetician":
		return ARITHMETICIAN_NORMAL_ATTACK_TEXTURE
	if visual_id == "chanter":
		return CHANTER_NORMAL_ATTACK_TEXTURE
	return TYPIST_NORMAL_ATTACK_TEXTURE


func get_normal_attack_weapon_texture(visual_id: String) -> Texture2D:
	if visual_id == "arithmetician":
		return ARITHMETICIAN_NORMAL_ATTACK_WEAPON_TEXTURE
	if visual_id == "chanter":
		return CHANTER_NORMAL_ATTACK_WEAPON_TEXTURE
	return TYPIST_NORMAL_ATTACK_WEAPON_TEXTURE


func get_normal_attack_particle_texture(visual_id: String) -> Texture2D:
	if visual_id == "arithmetician":
		return ARITHMETICIAN_NORMAL_ATTACK_PARTICLE_TEXTURE
	if visual_id == "chanter":
		return CHANTER_NORMAL_ATTACK_PARTICLE_TEXTURE
	return TYPIST_NORMAL_ATTACK_PARTICLE_TEXTURE


func draw_normal_attack_effect(player: Dictionary, position_value: Vector2, facing: Vector2) -> void:
	var progress := clampf(1.0 - float(player["attack_time"]) / ATTACK_DURATION, 0.0, 1.0)
	var hit_area := get_normal_attack_hit_area(position_value, facing)
	var visual_id := str(player.get("visual_id", "typist"))
	var weapon_texture := get_normal_attack_weapon_texture(visual_id)
	var particle_texture := get_normal_attack_particle_texture(visual_id)
	var particle_size := 28.75 if visual_id == "arithmetician" else (43.7 if visual_id == "chanter" else 34.5)
	var particle_count := 28 if visual_id == "arithmetician" else (40 if visual_id == "chanter" else 24)
	var source_size := weapon_texture.get_size()
	var source_longest_edge := float(maxi(source_size.x, source_size.y))
	var normalized_source_size := Vector2(source_size) / source_longest_edge
	var normalized_tip_offset := (WEAPON_TIP_UV - WEAPON_HANDLE_UV) * normalized_source_size
	var hand_to_tip_distance := hit_area.outer_range
	var weapon_canvas_size := hand_to_tip_distance / normalized_tip_offset.length()
	var weapon_size := normalized_source_size * weapon_canvas_size
	var hand_pivot := hit_area.origin
	# 素材の柄尻と先端をUVで定義し、先端が攻撃扇形の外周をなぞるようにする。
	var swing_angle := facing.angle() + lerpf(PI * 0.5, -PI * 0.5, progress)
	var weapon_tip_local := (WEAPON_TIP_UV - WEAPON_HANDLE_UV) * weapon_size
	var swing_rotation := swing_angle - weapon_tip_local.angle()
	var weapon_rect := Rect2(-WEAPON_HANDLE_UV * weapon_size, weapon_size)
	var weapon_tip_distance := hand_to_tip_distance

	# 進行済みの「武器先端」の位置にだけ粒子を残し、密度の高い扇状の軌跡を作る。
	for trail_index in range(particle_count):
		var trail_progress := maxf(0.0, progress - float(trail_index) * (1.05 / float(particle_count)))
		if trail_progress >= progress and progress < 0.04:
			continue
		var trail_angle := facing.angle() + lerpf(PI * 0.5, -PI * 0.5, trail_progress)
		var trail_direction := Vector2.from_angle(trail_angle)
		var trail_age_ratio := float(trail_index) / float(maxi(particle_count - 1, 1))
		var trail_side_offset := trail_direction.orthogonal() * sin(float(trail_index) * 2.17) * (1.5 + float(trail_index) * 0.35)
		var particle_position := hand_pivot + trail_direction * weapon_tip_distance + trail_side_offset
		var particle_alpha := (0.44 * pow(1.0 - trail_age_ratio, 1.3) + 0.08) * sin(trail_progress * PI)
		var particle_scale := particle_size * (1.0 - trail_age_ratio * 0.46)
		draw_set_transform(particle_position + get_world_draw_offset(), trail_angle + float(trail_index) * 0.22, Vector2.ONE)
		draw_texture_rect(particle_texture, Rect2(-particle_scale * 0.5, -particle_scale * 0.5, particle_scale, particle_scale), false, Color(1.0, 1.0, 1.0, particle_alpha))

	draw_set_transform(hand_pivot + get_world_draw_offset(), swing_rotation, Vector2.ONE)
	draw_texture_rect(weapon_texture, weapon_rect, false)
	# `_draw()` が設定したカメラ変換を以降のワールド描画へ戻す。
	draw_set_transform(get_world_draw_offset())


func draw_debug_normal_attack_hit_area(position_value: Vector2, facing: Vector2) -> void:
	# 実際の命中判定と同じ形状データを使用する。内側の死角は持たない。
	const DOT_SPACING := 8.0
	const DOT_RADIUS := 1.5
	var hit_area := get_normal_attack_hit_area(position_value, facing)
	var attack_origin := hit_area.origin
	var max_distance := hit_area.outer_range
	var start_angle := hit_area.facing.angle() - hit_area.half_angle
	var end_angle := hit_area.facing.angle() + hit_area.half_angle
	var debug_color := Color(1.0, 0.20, 0.24, 0.90)
	var edge_steps := ceili(max_distance / DOT_SPACING)
	for edge_index in range(edge_steps + 1):
		var distance := minf(float(edge_index) * DOT_SPACING, max_distance)
		draw_circle(attack_origin + Vector2.from_angle(start_angle) * distance, DOT_RADIUS, debug_color, true)
		draw_circle(attack_origin + Vector2.from_angle(end_angle) * distance, DOT_RADIUS, debug_color, true)
	var outer_arc_steps := ceili((end_angle - start_angle) * max_distance / DOT_SPACING)
	for arc_index in range(outer_arc_steps + 1):
		var ratio := float(arc_index) / float(outer_arc_steps)
		var direction := Vector2.from_angle(lerpf(start_angle, end_angle, ratio))
		draw_circle(attack_origin + direction * max_distance, DOT_RADIUS, debug_color, true)


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


func draw_menu_backdrop() -> void:
	# 理想画像の地下アーケードを、画面装飾として軽量に再現する。
	var screen_rect := Rect2(Vector2.ZERO, Vector2(1280, 720))
	draw_rect(screen_rect, Color("090817"), true)
	for y in range(0, 520, 38):
		var offset := 48 if int(y / 38) % 2 == 0 else 0
		for x in range(-20, 1300, 96):
			draw_rect(Rect2(x + offset, y, 92, 34), Color("111127"), true)
			draw_rect(Rect2(x + offset, y, 92, 34), Color("332044"), false, 1.0)
	for y in range(500, 720, 32):
		var ratio := float(y - 500) / 220.0
		var half_width := lerpf(250.0, 760.0, ratio)
		draw_line(Vector2(640 - half_width, y), Vector2(640 + half_width, y), Color("263050"), 1.0)
	for x in range(0, 1281, 80):
		draw_line(Vector2(640, 500), Vector2(x, 720), Color("263050"), 1.0)
	draw_circle(Vector2(290, 640), 120, Color("00b9c622"))
	draw_circle(Vector2(780, 640), 150, Color("ff287a1d"))
	draw_line(Vector2(0, 32), Vector2(210, 205), Color("d83c9955"), 5.0)
	draw_line(Vector2(1280, 32), Vector2(1070, 205), Color("d83c9955"), 5.0)
	draw_line(Vector2(35, 0), Vector2(180, 145), Color("4e315f"), 14.0)
	draw_line(Vector2(1245, 0), Vector2(1100, 145), Color("4e315f"), 14.0)
	draw_string(DOT_GOTHIC_FONT, Vector2(84, 330), "✦", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("6a4c93"))
	draw_string(DOT_GOTHIC_FONT, Vector2(1130, 350), "✦", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("ff3d81"))


func draw_player(player_id: int, player: Dictionary) -> void:
	var position_value: Vector2 = player["position"]
	var facing: Vector2 = player["attack_facing"] if float(player["attack_time"]) > 0.0 else player["facing"]
	if float(player.get("invisible_time", 0.0)) > 0.0 and player_id != local_player_id and float(player.get("invisible_flicker", 0.0)) < 2.3 and float(player["attack_time"]) <= 0.0:
		return
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
	if float(player.get("invisible_time", 0.0)) > 0.0 and player_id == local_player_id:
		sprite_tint.a = 0.35
	draw_texture_rect_region(character_texture, sprite_rect, source_rect, sprite_tint)
	if network_mode in ["host", "client"] and player_id == local_player_id:
		draw_string(DOT_GOTHIC_FONT, position_value + Vector2(-42.0, -91.0), "あなた", HORIZONTAL_ALIGNMENT_CENTER, 84.0, 18, Color("f1f5ff"))
	if player["attack_time"] > 0.0:
		draw_normal_attack_effect(player, position_value, facing)
		draw_debug_normal_attack_hit_area(position_value, facing)
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
	if str(projectile.get("chip", "")) != "":
		draw_string(DOT_GOTHIC_FONT, position_value + Vector2(-5.0, 5.0), str(projectile["chip"]), HORIZONTAL_ALIGNMENT_CENTER, 10.0, 10, Color("17213d"))


func draw_decoy(decoy: Dictionary, alpha: float) -> void:
	var visual_id := str(decoy.get("visual_id", "arithmetician"))
	var facing: Vector2 = decoy.get("facing", Vector2.DOWN)
	var texture := get_character_texture(visual_id)
	var source_rect := Rect2(get_sprite_direction_column(facing) * 64.0, 0.0, 64.0, 64.0)
	var position_value: Vector2 = decoy["position"]
	draw_texture_rect_region(texture, Rect2(position_value + Vector2(-32.0, -44.0), Vector2(64.0, 64.0)), source_rect, Color(1.0, 1.0, 1.0, alpha))


func _input(event: InputEvent) -> void:
	if screen == "title":
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			play_ui_click()
			show_home()
			return
	if screen == "home" or screen == "practice_select" or screen == "debug_select" or screen == "connection":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if challenge_owner != 0 and not challenge_skill.ends_with("trace") and challenge_owner == local_player_id:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_on_typing_submitted(typing_input.text)
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_BACKSPACE:
				typing_input.text = typing_input.text.left(maxi(0, typing_input.text.length() - 1))
				typing_input.caret_column = typing_input.text.length()
				get_viewport().set_input_as_handled()
				return
			if event.unicode > 0:
				typing_input.text += String.chr(event.unicode)
				typing_input.caret_column = typing_input.text.length()
				get_viewport().set_input_as_handled()
				return
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
	if challenge_skill == "small_trace":
		return roundi(distance_score * 0.45 + coverage_score * 0.55)
	var start_score := clampf(100.0 - challenge_trace_points[0].distance_to(challenge_target_points[0]) * 0.8, 0.0, 100.0)
	var end_score := clampf(100.0 - challenge_trace_points[challenge_trace_points.size() - 1].distance_to(challenge_target_points[challenge_target_points.size() - 1]) * 0.8, 0.0, 100.0)
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
