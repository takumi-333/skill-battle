class_name TraceEvaluator
extends RefCounted

const DEFAULT_CONFIG := {
	"sample_interval": 2.0,
	"ng_distance": 20.0,
	"ng_gap_length": 30.0,
	"noise_distance": 1.0,
	"sigma": 0.18,
	"score_power": 1.35,
	"normalization_scale_factor": 0.55,
	"mean_weight": 0.40,
	"p90_weight": 0.30,
	"p99_weight": 0.15,
	"coverage_weight": 0.10,
	"length_weight": 0.05,
}

var config: Dictionary = DEFAULT_CONFIG.duplicate()

func _init(overrides: Dictionary = {}) -> void:
	for key in overrides:
		if config.has(key):
			config[key] = overrides[key]

func evaluate(target: PackedVector2Array, user: PackedVector2Array) -> Dictionary:
	var result := _empty_result()
	if target.size() < 2 or user.size() < 2:
		result["ng_reason"] = "insufficient_points"
		return result
	var clean_target := _remove_noise(target)
	var clean_user := _remove_noise(user)
	var target_line := _resample(clean_target)
	var user_line := _resample(clean_user)
	if target_line.size() < 2 or user_line.size() < 2:
		result["ng_reason"] = "insufficient_points"
		return result
	var target_length := _polyline_length(target_line)
	var user_length := _polyline_length(user_line)
	var scale := _stroke_scale(target_line)
	var user_errors := PackedFloat32Array()
	for point in user_line:
		user_errors.append(_distance_to_polyline(point, target_line))
	var target_errors := PackedFloat32Array()
	var max_gap := 0.0
	var current_gap := 0.0
	for point in target_line:
		var distance := _distance_to_polyline(point, user_line)
		target_errors.append(distance)
		if distance >= float(config["ng_distance"]):
			current_gap += float(config["sample_interval"])
			max_gap = maxf(max_gap, current_gap)
		else:
			current_gap = 0.0
	var mean_error := _mean(user_errors)
	var p90_error := _percentile(user_errors, 0.90)
	var p95_error := _percentile(user_errors, 0.95)
	var p99_error := _percentile(user_errors, 0.99)
	var coverage_error := _mean(target_errors)
	var ratio := user_length / maxf(target_length, 0.001)
	var length_penalty := absf(log(maxf(ratio, 0.001)))
	var weighted_error := mean_error * float(config["mean_weight"]) + p90_error * float(config["p90_weight"]) + p99_error * float(config["p99_weight"]) + coverage_error * float(config["coverage_weight"]) + length_penalty * scale * float(config["length_weight"])
	var normalized_error := weighted_error / scale
	var sigma := maxf(float(config["sigma"]), 0.001)
	var score := 100.0 * exp(-pow(normalized_error / sigma, float(config["score_power"])))
	result.merge({
		"mean_error": mean_error, "p90_error": p90_error, "p95_error": p95_error, "p99_error": p99_error,
		"coverage_error": coverage_error, "target_length": target_length, "user_length": user_length,
		"length_ratio": ratio, "length_penalty": length_penalty, "max_gap_length": max_gap,
		"normalized_error": normalized_error, "score": clampi(roundi(score), 0, 100),
		"target_points": target_line, "user_points": user_line,
	}, true)
	result["ng"] = false
	# A short local gap can be caused by a sharp corner or sparse pointer events.
	# Treat it as NG only when the overall target coverage is also substantially bad;
	# otherwise the continuous error/length score should decide the result.
	var severe_coverage_error := float(config["ng_distance"])
	if max_gap >= float(config["ng_gap_length"]) and coverage_error >= severe_coverage_error:
		result["ng"] = true
		result["ng_reason"] = "gap"
		result["score"] = 0
	return result

func _empty_result() -> Dictionary:
	return {"ng": true, "ng_reason": "", "score": 0, "mean_error": 0.0, "p90_error": 0.0, "p95_error": 0.0, "p99_error": 0.0, "coverage_error": 0.0, "target_length": 0.0, "user_length": 0.0, "length_ratio": 0.0, "length_penalty": 0.0, "max_gap_length": 0.0, "normalized_error": 0.0}

func _remove_noise(points: PackedVector2Array) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or point.distance_to(clean[-1]) >= float(config["noise_distance"]):
			clean.append(point)
	return clean

func _resample(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var output := PackedVector2Array([points[0]])
	var interval := maxf(float(config["sample_interval"]), 0.1)
	var carry := 0.0
	for index in range(points.size() - 1):
		var start := points[index]
		var end := points[index + 1]
		var segment := end - start
		var length := segment.length()
		if length <= 0.001:
			continue
		var distance := interval - carry
		while distance <= length:
			output.append(start + segment * (distance / length))
			distance += interval
		carry = fmod(length - (distance - interval), interval)
	output.append(points[-1])
	return output

func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	return total

func _stroke_scale(points: PackedVector2Array) -> float:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	# Using the full bounding-box width makes a long stroke too forgiving.
	# Use a tunable fraction of the largest target dimension as the error scale.
	return maxf(maxf(bounds.size.x, bounds.size.y) * float(config["normalization_scale_factor"]), 1.0)

func _distance_to_polyline(point: Vector2, line: PackedVector2Array) -> float:
	var closest := INF
	for index in range(line.size() - 1):
		closest = minf(closest, _distance_to_segment(point, line[index], line[index + 1]))
	return closest

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var ratio := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)

func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

func _percentile(values: PackedFloat32Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := Array(values)
	sorted.sort()
	var index := clampi(ceili((sorted.size() - 1) * percentile), 0, sorted.size() - 1)
	return float(sorted[index])
