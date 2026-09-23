## Keeps a drawn polyline within the network payload limit while retaining its shape.
extends RefCounted

static func limit_points(points: PackedVector2Array, max_points: int) -> PackedVector2Array:
	if max_points <= 0 or points.is_empty():
		return PackedVector2Array()
	if points.size() <= max_points:
		return points.duplicate()
	if max_points == 1:
		return PackedVector2Array([points[-1]])

	var low_tolerance := 0.0
	var high_tolerance := 1.0
	var simplified := _simplify_polyline(points, high_tolerance)
	while simplified.size() > max_points and high_tolerance < 65536.0:
		high_tolerance *= 2.0
		simplified = _simplify_polyline(points, high_tolerance)

	if simplified.size() > max_points:
		return _sample_evenly(points, max_points)

	var best := simplified
	for _iteration in 24:
		var tolerance := (low_tolerance + high_tolerance) * 0.5
		var candidate := _simplify_polyline(points, tolerance)
		if candidate.size() > max_points:
			low_tolerance = tolerance
		else:
			high_tolerance = tolerance
			best = candidate
	return best


static func _simplify_polyline(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	var keep := PackedByteArray()
	keep.resize(points.size())
	keep[0] = 1
	keep[points.size() - 1] = 1
	var pending: Array[Vector2i] = [Vector2i(0, points.size() - 1)]
	var tolerance_squared := tolerance * tolerance
	while not pending.is_empty():
		var segment: Vector2i = pending.pop_back()
		var farthest_index := -1
		var farthest_distance_squared := tolerance_squared
		for index in range(segment.x + 1, segment.y):
			var distance_squared := _distance_squared_to_segment(points[index], points[segment.x], points[segment.y])
			if distance_squared > farthest_distance_squared:
				farthest_distance_squared = distance_squared
				farthest_index = index
		if farthest_index >= 0:
			keep[farthest_index] = 1
			pending.append(Vector2i(segment.x, farthest_index))
			pending.append(Vector2i(farthest_index, segment.y))

	var result := PackedVector2Array()
	for index in points.size():
		if keep[index] != 0:
			result.append(points[index])
	return result


static func _distance_squared_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var ratio := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_squared_to(start + segment * ratio)


static func _sample_evenly(points: PackedVector2Array, max_points: int) -> PackedVector2Array:
	var sampled := PackedVector2Array()
	for index in max_points:
		var source_index := roundi(float(index) * float(points.size() - 1) / float(max_points - 1))
		sampled.append(points[source_index])
	return sampled
