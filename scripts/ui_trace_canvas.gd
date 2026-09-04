class_name UITraceCanvas
extends Control

var target_points := PackedVector2Array()
var input_points := PackedVector2Array()
var target_color := Color("8fa8e888")
var input_color := Color("fff2b0")
var input_outer_color := Color("fff2b0")
var input_width := 5.0

func set_trace_data(target: PackedVector2Array, input: PackedVector2Array, target_tint: Color = Color("8fa8e888"), input_tint: Color = Color("fff2b0"), input_outer_tint: Color = Color("fff2b0"), brush_width: float = 5.0) -> void:
	target_points = target
	input_points = input
	target_color = target_tint
	input_color = input_tint
	input_outer_color = input_outer_tint
	input_width = brush_width
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1224cc"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("7386b8"), false, 2.0)
	if target_points.size() >= 2:
		draw_polyline(target_points, target_color, 12.0, true)
	var glow_width := input_width + 4.0 if input_outer_color != input_color else input_width
	if input_points.size() >= 2:
		draw_polyline(input_points, input_outer_color, glow_width, false)
		draw_polyline(input_points, input_color, input_width, false)
