extends MatchController

const ARENA := Rect2(40, 100, 1200, 580)
const PLAYER_RADIUS := 26.0
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

const MatchStateData = preload("res://scripts/match_state.gd")
const ChallengeLayerData = preload("res://scripts/challenge_layer.gd")
const BLADE_TEXTURE: Texture2D = preload("res://assets/characters/blade.svg")
const ARITHMETIC_TEXTURE: Texture2D = preload("res://assets/characters/arithmetic.svg")
const CHANTER_TEXTURE: Texture2D = preload("res://assets/characters/chanter.svg")

var match_state: MatchState = MatchStateData.new()
var players: Dictionary = match_state.players
var status_text := "開始！ 距離を取りながら相手に通常攻撃を当てよう。"
var skill_projectiles: Array[Dictionary] = []
var magic_zones: Array[Dictionary] = []
var phase: String = "lobby"
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
var challenge_definitions: Dictionary = {}
var network_mode: String = "local"
var local_player_id: int = 1
var remote_input: Dictionary = {"move": Vector2.ZERO, "attack": false, "small": false, "big": false}
var network_sync_elapsed: float = 0.0
var pending_client_input: Dictionary = {}
var network_target_players: Dictionary = {}

var player_one_label: Label
var player_two_label: Label
var timer_label: Label
var status_label: Label
var challenge_panel: PanelContainer
var challenge_prompt_label: Label
var challenge_progress_label: Label
var typing_input: LineEdit
var lobby_panel: PanelContainer
var lobby_label: Label
var result_panel: Panel
var result_label: Label
var result_rematch_button: Button
var result_lobby_button: Button
var network_panel: Panel
var network_address_input: LineEdit
var network_status_label: Label


func _ready() -> void:
	create_challenge_definitions()
	create_hud()
	create_lobby_ui()
	create_result_ui()
	create_network_ui()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	show_connection()
	queue_redraw()


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
	update_player(1, delta, KEY_A, KEY_D, KEY_W, KEY_S)
	update_player(2, delta, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)
	separate_players()
	update_typing_challenge(delta)
	update_skill_projectiles(delta)
	update_magic_zones(delta)
	if network_mode == "host":
		sync_network_state(delta)

	if Input.is_key_pressed(KEY_Q):
		start_small_skill(1)
	if Input.is_key_pressed(KEY_E):
		start_big_skill(1)
	if network_mode != "host" and Input.is_key_pressed(KEY_KP_0):
		start_small_skill(2)
	if network_mode != "host" and Input.is_key_pressed(KEY_KP_9):
		start_big_skill(2)
	if Input.is_key_pressed(KEY_F):
		try_attack(1)
	if network_mode != "host" and Input.is_key_pressed(KEY_ENTER) and not typing_input.has_focus():
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
	if network_mode == "host" and player_id == 2:
		direction = remote_input["move"]
	else:
		direction.x = float(Input.is_key_pressed(right_key)) - float(Input.is_key_pressed(left_key))
		direction.y = float(Input.is_key_pressed(down_key)) - float(Input.is_key_pressed(up_key))
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		player["facing"] = direction
		var speed_multiplier: float = (FOCUS_SPEED_MULTIPLIER if bool(player["focused"]) else 1.0) * (1.25 if float(player["buff_time"]) > 0.0 else 1.0)
		player["position"] = clamp_to_arena(player["position"] + direction * PLAYER_SPEED * speed_multiplier * delta)
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
	var to_target: Vector2 = target["position"] - player["position"]
	var facing: Vector2 = player["facing"]
	var in_range: bool = to_target.length() <= SLASH_RANGE + PLAYER_RADIUS
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
	player["focused"] = true
	player["challenge_elapsed"] = 0.0
	player["interrupt_gauge_max"] = 50.0 if is_big else TYPING_INTERRUPT_GAUGE
	player["interrupt_gauge"] = player["interrupt_gauge_max"]
	player["interrupt_gauge_display"] = player["interrupt_gauge_max"]
	players[owner_id] = player
	var show_local_challenge: bool = network_mode != "host" or owner_id == 1
	challenge_panel.visible = show_local_challenge
	typing_input.visible = not challenge_skill.ends_with("trace")
	typing_input.text = ""
	if typing_input.visible and show_local_challenge:
		typing_input.grab_focus()
	status_text = "%sが%sの集中を開始！" % [player["name"], "大技" if is_big else "小技"]
	update_challenge_ui(0.0)


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
	typing_input.release_focus()
	typing_input.visible = true
	if success:
		spawn_character_skill(owner_id, score, is_big)
		status_text = "%sの%sが発動！ スコア %d点" % [player["name"], "大技" if is_big else "小技", score]
	else:
		status_text = failure_message
	challenge_owner = 0
	challenge_skill = ""


func end_typing_challenge(success: bool, score: int, failure_message: String) -> void:
	end_active_challenge(success, score, failure_message)


func spawn_typing_projectile(score: int) -> void:
	var owner: Dictionary = players[1]
	var owner_position: Vector2 = owner["position"]
	var facing: Vector2 = owner["facing"]
	var damage: int = 10 + roundi(float(score) * 0.1)
	var speed: float = 500.0 + float(score) * 3.0
	skill_projectiles.append({
		"position": owner_position + facing * (PLAYER_RADIUS + SKILL_PROJECTILE_RADIUS),
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
		var distance: float = owner_position.distance_to(target_position)
		if not is_big and distance <= 170.0:
			apply_damage(target_id, 18 + roundi(float(score) * 0.08), "詠唱者の衝撃波")
		elif is_big:
			spawn_zone(owner_id, score, owner["position"] + owner["facing"] * 110.0)


func spawn_projectile(owner_id: int, score: int, is_big: bool, angle_offset: float) -> void:
	var owner: Dictionary = players[owner_id]
	var owner_facing: Vector2 = owner["facing"]
	var facing: Vector2 = owner_facing.rotated(angle_offset)
	skill_projectiles.append({
		"owner_id": owner_id,
		"position": owner["position"] + facing * (PLAYER_RADIUS + SKILL_PROJECTILE_RADIUS),
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
			if target_position.distance_to(zone_position) <= 80.0:
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
		if position_value.distance_to(target_position) <= PLAYER_RADIUS + SKILL_PROJECTILE_RADIUS:
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


func separate_players() -> void:
	var first: Dictionary = players[1]
	var second: Dictionary = players[2]
	var offset: Vector2 = second["position"] - first["position"]
	var minimum_distance := PLAYER_RADIUS * 2.0
	if offset.length_squared() > 0.0 and offset.length() < minimum_distance:
		var push := offset.normalized() * (minimum_distance - offset.length()) * 0.5
		first["position"] = clamp_to_arena(first["position"] - push)
		second["position"] = clamp_to_arena(second["position"] + push)
		players[1] = first
		players[2] = second


func clamp_to_arena(position_value: Vector2) -> Vector2:
	return Vector2(
		clampf(position_value.x, ARENA.position.x + PLAYER_RADIUS, ARENA.end.x - PLAYER_RADIUS),
		clampf(position_value.y, ARENA.position.y + PLAYER_RADIUS, ARENA.end.y - PLAYER_RADIUS)
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
	typing_input.release_focus()
	challenge_owner = 0
	status_text = "%sの集中は%sで中断された。" % [player["name"], attack_name]


func finish_match(winner_id: int) -> void:
	match_state.match_over = true
	match_state.winner_id = winner_id
	challenge_panel.visible = false
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

	var controls := make_hud_label(Vector2(300, 72), HORIZONTAL_ALIGNMENT_CENTER)
	controls.size = Vector2(680, 24)
	controls.text = "P1: WASD移動 / F斬撃 / Q小技 / E大技     P2: 矢印移動 / Enter斬撃 / Num0小技 / Num9大技"
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color("b7c1d8"))
	create_challenge_ui(layer)


func create_lobby_ui() -> void:
	lobby_panel = PanelContainer.new()
	lobby_panel.position = Vector2(260, 150)
	lobby_panel.size = Vector2(760, 390)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b34f5")
	style.border_color = Color("8fa8e8")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	lobby_panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(lobby_panel)
	lobby_label = Label.new()
	lobby_label.position = Vector2(28, 22)
	lobby_label.size = Vector2(700, 340)
	lobby_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lobby_label.add_theme_font_size_override("font_size", 22)
	lobby_panel.add_child(lobby_label)


func create_result_ui() -> void:
	result_panel = Panel.new()
	result_panel.position = Vector2(330, 170)
	result_panel.size = Vector2(620, 320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b34f5")
	style.border_color = Color("ffc45e")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	result_panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(result_panel)
	result_label = Label.new()
	result_label.position = Vector2(22, 18)
	result_label.size = Vector2(575, 270)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 21)
	result_panel.add_child(result_label)
	result_rematch_button = Button.new()
	result_rematch_button.text = "もう一度対戦"
	result_rematch_button.position = Vector2(120, 270)
	result_rematch_button.size = Vector2(170, 36)
	result_rematch_button.pressed.connect(request_rematch)
	result_panel.add_child(result_rematch_button)
	result_lobby_button = Button.new()
	result_lobby_button.text = "ロビーへ戻る"
	result_lobby_button.position = Vector2(330, 270)
	result_lobby_button.size = Vector2(170, 36)
	result_lobby_button.pressed.connect(request_return_to_lobby)
	result_panel.add_child(result_lobby_button)
	result_panel.visible = false


func create_network_ui() -> void:
	network_panel = Panel.new()
	network_panel.position = Vector2(330, 175)
	network_panel.size = Vector2(620, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b34f5")
	style.border_color = Color("71d6ba")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	network_panel.add_theme_stylebox_override("panel", style)
	get_child(0).add_child(network_panel)
	var title := Label.new()
	title.text = "オンライン対戦"
	title.position = Vector2(30, 25)
	title.size = Vector2(560, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	network_panel.add_child(title)
	network_address_input = LineEdit.new()
	network_address_input.text = "127.0.0.1:7000"
	network_address_input.placeholder_text = "接続先 IP:ポート"
	network_address_input.position = Vector2(110, 93)
	network_address_input.size = Vector2(400, 38)
	network_panel.add_child(network_address_input)
	var host_button := Button.new()
	host_button.text = "ルームを作成"
	host_button.position = Vector2(110, 150)
	host_button.size = Vector2(185, 42)
	host_button.pressed.connect(start_host)
	network_panel.add_child(host_button)
	var join_button := Button.new()
	join_button.text = "ルームに参加"
	join_button.position = Vector2(325, 150)
	join_button.size = Vector2(185, 42)
	join_button.pressed.connect(join_host)
	network_panel.add_child(join_button)
	var local_button := Button.new()
	local_button.text = "同一PCデバッグで開始"
	local_button.position = Vector2(200, 205)
	local_button.size = Vector2(220, 34)
	local_button.pressed.connect(start_local_debug)
	network_panel.add_child(local_button)
	network_status_label = Label.new()
	network_status_label.position = Vector2(30, 255)
	network_status_label.size = Vector2(560, 26)
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.add_theme_color_override("font_color", Color("b7c1d8"))
	network_panel.add_child(network_status_label)


func show_connection() -> void:
	phase = "connection"
	network_panel.visible = true
	lobby_panel.visible = false
	result_panel.visible = false
	challenge_panel.visible = false
	network_status_label.text = "ホスト作成、またはIP:ポートを入力して参加してください。"


func start_local_debug() -> void:
	network_mode = "local"
	local_player_id = 1
	network_panel.visible = false
	show_lobby()


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
		"attack": Input.is_key_pressed(KEY_ENTER) and not typing_input.has_focus(),
		"small": Input.is_key_pressed(KEY_KP_0),
		"big": Input.is_key_pressed(KEY_KP_9),
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
	lobby_panel.visible = phase == "lobby"
	if phase == "lobby":
		refresh_lobby_label()
	if phase == "result":
		if not result_panel.visible:
			show_result(match_state.winner_id)
		return
	result_panel.visible = false
	var player_is_challenging: bool = challenge_owner == local_player_id and phase == "match"
	challenge_panel.visible = player_is_challenging
	if player_is_challenging:
		challenge_prompt_label.text = challenge_prompt
		typing_input.visible = not challenge_skill.ends_with("trace")
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
	match_state.reset()
	players = match_state.players
	p1_ready = false
	p2_ready = false
	challenge_owner = 0
	skill_projectiles.clear()
	magic_zones.clear()
	challenge_panel.visible = false
	lobby_panel.visible = true
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
	lobby_label.text = "SKILL BATTLE GAME\n\nP1選択: [%d] %s     P2選択: [%d] %s\n\n1/2/3: P1選択       7/8/9: P2選択\nSpace: P1準備 / Enter: P2準備\n\nP1: %s     P2: %s\n\n両者が準備完了すると3秒カウントダウン" % [p1_selection + 1, names[p1_selection], p2_selection + 1, names[p2_selection], "準備完了" if p1_ready else "未準備", "準備完了" if p2_ready else "未準備"]


func begin_match() -> void:
	phase = "match"
	match_state.match_over = false
	match_state.time_remaining = MATCH_DURATION
	configure_player(1, p1_selection)
	configure_player(2, p2_selection)
	status_text = "開始！ 通常攻撃と課題スキルを使い分けよう。"


func configure_player(player_id: int, selection: int) -> void:
	var player: Dictionary = players[player_id]
	var ids: Array[String] = ["blade", "arithmetic", "chanter"]
	var names: Array[String] = ["打鍵者", "算術士", "詠唱者"]
	var colors: Array[Color] = [Color("ef6b73"), Color("7498ff"), Color("b98aff")]
	player["character_id"] = ids[selection]
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
	challenge_panel = PanelContainer.new()
	challenge_panel.position = Vector2(40, 520)
	challenge_panel.size = Vector2(390, 154)
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
	content.add_theme_constant_override("separation", 5)
	challenge_panel.add_child(content)
	var title := Label.new()
	title.text = "打鍵者・小技  集中中"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ffc1c6"))
	content.add_child(title)
	challenge_prompt_label = Label.new()
	challenge_prompt_label.add_theme_font_size_override("font_size", 17)
	content.add_child(challenge_prompt_label)
	typing_input = LineEdit.new()
	typing_input.placeholder_text = "ここに入力して Enter"
	typing_input.add_theme_font_size_override("font_size", 18)
	typing_input.text_submitted.connect(_on_typing_submitted)
	content.add_child(typing_input)
	challenge_progress_label = Label.new()
	challenge_progress_label.add_theme_font_size_override("font_size", 13)
	challenge_progress_label.add_theme_color_override("font_color", Color("b7c1d8"))
	content.add_child(challenge_progress_label)
	challenge_panel.visible = false


func update_challenge_ui(elapsed: float) -> void:
	challenge_prompt_label.text = challenge_prompt
	var limit: float = BIG_CHALLENGE_LIMIT if challenge_skill.begins_with("big") else (TRACE_CHALLENGE_LIMIT if challenge_skill.ends_with("trace") else (ARITHMETIC_CHALLENGE_LIMIT if challenge_skill.ends_with("arithmetic") else TYPING_CHALLENGE_LIMIT))
	challenge_progress_label.text = "残り %.1f秒  |  Esc: 中止  |  集中中は移動低下・通常攻撃不可" % maxf(0.0, limit - elapsed)


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
	var player_one: Dictionary = players[1]
	var focus_suffix := "  集中中" if bool(player_one["focused"]) else ""
	var player_two: Dictionary = players[2]
	player_one_label.text = "P1  %s  HP %d%s\n通常 %.1fs  小技 %.1fs  大技 %.1fs" % [player_one["name"], player_one["hp"], focus_suffix, float(player_one["attack_cooldown"]), float(player_one["small_cooldown"]), float(player_one["big_cooldown"])]
	player_two_label.text = "P2  %s  HP %d\n通常 %.1fs  小技 %.1fs  大技 %.1fs" % [player_two["name"], player_two["hp"], float(player_two["attack_cooldown"]), float(player_two["small_cooldown"]), float(player_two["big_cooldown"])]
	timer_label.text = "残り %02d秒" % ceili(match_state.time_remaining)
	status_label.text = status_text


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("080d1d"))
	draw_arena()
	for player_id in [1, 2]:
		draw_player(players[player_id])
	for projectile in skill_projectiles:
		draw_skill_projectile(projectile)
	for zone in magic_zones:
		var zone_ratio: float = clampf(float(zone["lifetime"]) / ZONE_DURATION, 0.0, 1.0)
		draw_circle(zone["position"], 80.0, Color(0.55, 0.35, 0.95, 0.12 + zone_ratio * 0.10))
		draw_arc(zone["position"], 80.0, 0.0, TAU, 32, Color("c7a6ff"), 3.0, true)
	if challenge_owner != 0 and challenge_skill.ends_with("trace") and challenge_trace_points.size() >= 2:
		draw_polyline(challenge_trace_points, Color("ffd36a"), 5.0, true)


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


func draw_player(player: Dictionary) -> void:
	var position_value: Vector2 = player["position"]
	var color: Color = player["color"]
	var facing: Vector2 = player["facing"]
	var side := Vector2(-facing.y, facing.x)
	var body_color := Color("fff1dc") if player["hit_time"] > 0.0 else color
	draw_circle(position_value, PLAYER_RADIUS + 6.0, Color(color.r, color.g, color.b, 0.20))
	if bool(player["focused"]):
		draw_circle(position_value, PLAYER_RADIUS + 15.0, Color("ef6b7355"))
		draw_arc(position_value, PLAYER_RADIUS + 18.0, 0.0, TAU, 28, Color("ffd0a1"), 2.5, true)
	var character_texture: Texture2D = BLADE_TEXTURE
	if str(player["character_id"]) == "arithmetic":
		character_texture = ARITHMETIC_TEXTURE
	elif str(player["character_id"]) == "chanter":
		character_texture = CHANTER_TEXTURE
	var sprite_rect := Rect2(position_value - Vector2(32, 32), Vector2(64, 64))
	draw_texture_rect(character_texture, sprite_rect, false, body_color)
	var weapon_start := position_value + facing * 7.0 + side * 10.0
	var weapon_end := position_value + facing * 34.0 + side * 15.0
	draw_line(weapon_start, weapon_end, Color("e9eef5"), 4.0)
	if player["attack_time"] > 0.0:
		var angle := facing.angle()
		draw_arc(position_value, SLASH_RANGE, angle - SLASH_ARC_HALF_ANGLE, angle + SLASH_ARC_HALF_ANGLE, 18, Color("fff3ad"), 7.0, true)
	var health_ratio: float = float(player["hp"]) / 100.0
	var health_rect := Rect2(position_value + Vector2(-30, -44), Vector2(60, 7))
	draw_rect(health_rect, Color("070b14"), true)
	draw_rect(Rect2(health_rect.position, Vector2(health_rect.size.x * health_ratio, health_rect.size.y)), Color("52d6ad"), true)
	if bool(player["focused"]) and float(player["interrupt_gauge_max"]) > 0.0:
		var gauge_ratio: float = clampf(float(player["interrupt_gauge_display"]) / float(player["interrupt_gauge_max"]), 0.0, 1.0)
		var gauge_rect := Rect2(position_value + Vector2(-30, -33), Vector2(60, 5))
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
	if event is InputEventKey and event.pressed and not event.echo:
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
		if event.pressed:
			challenge_trace_points.clear()
			challenge_trace_points.append(event.position)
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
		challenge_trace_points.append(event.position)


func evaluate_trace() -> int:
	if challenge_trace_points.size() < 2:
		return 0
	var path_length: float = 0.0
	for index in range(1, challenge_trace_points.size()):
		path_length += challenge_trace_points[index - 1].distance_to(challenge_trace_points[index])
	var target_length: float = 260.0 if challenge_skill.begins_with("big") else 140.0
	var length_score: float = clampf(100.0 - absf(path_length - target_length) * 0.35, 0.0, 100.0)
	return roundi(length_score)
