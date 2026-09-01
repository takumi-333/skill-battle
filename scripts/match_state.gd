class_name MatchState
extends RefCounted

const MATCH_DURATION := 90.0

var players: Dictionary = {}
var time_remaining: float = MATCH_DURATION
var match_over: bool = false
var winner_id: int = 0


func _init() -> void:
	reset()


func reset() -> void:
	players.clear()
	players[1] = create_player("打鍵者", Vector2(300, 390), Vector2.RIGHT, Color("ef6b73"))
	players[2] = create_player("算術士", Vector2(980, 390), Vector2.LEFT, Color("7498ff"))
	time_remaining = MATCH_DURATION
	match_over = false
	winner_id = 0


func create_player(display_name: String, start_position: Vector2, start_facing: Vector2, display_color: Color) -> Dictionary:
	return {
		"name": display_name,
		"character_id": "blade",
		"visual_id": "typist",
		"is_moving": false,
		"position": start_position,
		"facing": start_facing,
		"color": display_color,
		"hp": 100,
		"attack_cooldown": 0.0,
		"attack_time": 0.0,
		"hit_time": 0.0,
		"focused": false,
		"challenge_elapsed": 0.0,
		"skill_cooldown": 0.0,
		"skill_successes": 0,
		"score_total": 0,
		"best_score": 0,
		"challenge_count": 0,
		"challenge_score_total": 0,
		"challenge_best_score": 0,
		"challenge_errors": 0,
		"challenge_total_time": 0.0,
		"buff_time": 0.0,
		"attack_damage_buff": 0,
		"invisible_time": 0.0,
		"invisible_flicker": 0.0,
		"normal_damage": 12,
		"small_cooldown": 0.0,
		"big_cooldown": 0.0,
		"interrupt_gauge": 0.0,
		"interrupt_gauge_max": 0.0,
		"interrupt_gauge_display": 0.0,
	}
