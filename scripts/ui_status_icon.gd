class_name LobbyStatusIcon
extends Control

var is_ready := false
var spinner_angle := 0.0

func set_ready(value: bool) -> void:
	is_ready = value
	queue_redraw()

func _process(delta: float) -> void:
	if not is_ready:
		spinner_angle = fmod(spinner_angle + delta * 5.0, TAU)
		queue_redraw()

func _draw() -> void:
	if is_ready:
		draw_line(Vector2(10, 24), Vector2(20, 34), Color("71d6ba"), 5, true)
		draw_line(Vector2(20, 34), Vector2(39, 13), Color("71d6ba"), 5, true)
	else:
		draw_arc(Vector2(24, 24), 14, spinner_angle, spinner_angle + PI * 1.45, 20, Color("ffc45e"), 4, true)
