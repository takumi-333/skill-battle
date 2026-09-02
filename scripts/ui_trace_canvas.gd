class_name UITraceCanvas
extends Control

var target_points := PackedVector2Array()
var input_points := PackedVector2Array()

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
