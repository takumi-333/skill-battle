extends Node2D

const Evaluator = preload("res://scripts/trace_evaluator.gd")
var evaluator = Evaluator.new()
var target := PackedVector2Array()
var user := PackedVector2Array()
var drawing := false
var result: Dictionary = {}
var shape_index := 0
var shape_name := "Circle"
var status := "Drag over the target. [C/TAB] change emblem  [R] reset  [1/2] NG distance  [Q/A] sigma"

func _ready() -> void:
	set_shape(0)
	queue_redraw()

func set_shape(index: int) -> void:
	shape_index = posmod(index, 4)
	match shape_index:
		0:
			shape_name = "Circle"
			target = make_circle(Vector2(480, 220), 105.0)
		1:
			shape_name = "Five-point star"
			target = make_star(Vector2(480, 220), 125.0, 52.0)
		2:
			shape_name = "Triangle"
			target = PackedVector2Array([Vector2(350, 315), Vector2(480, 105), Vector2(610, 315), Vector2(350, 315)])
		3:
			shape_name = "Spiral"
			target = make_spiral(Vector2(480, 220))
	user.clear()
	result.clear()

func make_circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(65):
		points.append(center + Vector2.from_angle(float(index) * TAU / 64.0) * radius)
	return points

func make_star(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(11):
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := -PI / 2.0 + float(index) * TAU / 10.0
		points.append(center + Vector2.from_angle(angle) * radius)
	return points

func make_spiral(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(97):
		var ratio := float(index) / 96.0
		var angle := ratio * TAU * 2.25 - PI / 2.0
		var radius := 12.0 + ratio * 118.0
		points.append(center + Vector2.from_angle(angle) * radius)
	return points

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			user.clear()
			drawing = true
			user.append(event.position)
		else:
			drawing = false
			result = evaluator.evaluate(target, user)
			queue_redraw()
	if event is InputEventMouseMotion and drawing:
		if user.is_empty() or user[-1].distance_to(event.position) >= 2.0:
			user.append(event.position)
			queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.keycode == KEY_TAB:
			set_shape(shape_index + 1)
		elif event.keycode == KEY_R:
			user.clear()
			result.clear()
		elif event.keycode == KEY_1:
			evaluator.config["ng_distance"] = maxf(4.0, float(evaluator.config["ng_distance"]) - 2.0)
		elif event.keycode == KEY_2:
			evaluator.config["ng_distance"] = minf(80.0, float(evaluator.config["ng_distance"]) + 2.0)
		elif event.keycode == KEY_Q:
			evaluator.config["sigma"] = maxf(0.02, float(evaluator.config["sigma"]) - 0.02)
		elif event.keycode == KEY_A:
			evaluator.config["sigma"] = minf(1.0, float(evaluator.config["sigma"]) + 0.02)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("09111f"))
	draw_string(ThemeDB.fallback_font, Vector2(40, 42), "Polyline Trace Evaluator Debug - %s" % shape_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("fff2b0"))
	draw_string(ThemeDB.fallback_font, Vector2(40, 72), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("b7c1d8"))
	if target.size() >= 2:
		draw_polyline(target, Color("6e8ce8"), 14.0, true)
	if user.size() >= 2:
		draw_polyline(user, Color("fff2b0"), 5.0, true)
	for point in user:
		draw_circle(point, 3.0, Color("fff2b0"))
	var y := 540.0
	if result.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(40, y), "No submission yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b7c1d8"))
	else:
		var lines := [
			"Score %d   NG=%s (%s)" % [int(result.get("score", 0)), str(result.get("ng", false)), str(result.get("ng_reason", "none"))],
			"Mean %.2f  P90 %.2f  P95 %.2f  P99 %.2f  Coverage %.2f" % [result["mean_error"], result["p90_error"], result["p95_error"], result["p99_error"], result["coverage_error"]],
			"TargetLength %.1f  UserLength %.1f  Ratio %.3f  Penalty %.3f  MaxGap %.1f" % [result["target_length"], result["user_length"], result["length_ratio"], result["length_penalty"], result["max_gap_length"]],
			"NG distance %.1f  NG gap %.1f  Sigma %.2f  Scale %.2f" % [evaluator.config["ng_distance"], evaluator.config["ng_gap_length"], evaluator.config["sigma"], evaluator.config["normalization_scale_factor"]],
		]
		for line in lines:
			draw_string(ThemeDB.fallback_font, Vector2(40, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d8e2ff"))
			y += 27.0
