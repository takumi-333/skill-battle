extends SceneTree

const TraceEvaluatorData = preload("res://scripts/trace_evaluator.gd")

func _init() -> void:
	var evaluator = TraceEvaluatorData.new()
	var target := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	var same := PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(100, 0), Vector2(100, 50), Vector2(100, 100)])
	var translated := PackedVector2Array()
	for point in same:
		translated.append(point + Vector2(8, 6))
	var omitted := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var same_result: Dictionary = evaluator.evaluate(target, same)
	var translated_result: Dictionary = evaluator.evaluate(target, translated)
	var omitted_result: Dictionary = evaluator.evaluate(target, omitted)
	assert(same_result["score"] >= 95)
	assert(translated_result["score"] > 50)
	assert(omitted_result["length_ratio"] < 0.8)
	assert(omitted_result["ng"])
	assert(same_result.has("p95_error") and same_result.has("coverage_error"))
	print("trace evaluator tests passed: same=%d translated=%d omitted_ratio=%.3f" % [same_result["score"], translated_result["score"], omitted_result["length_ratio"]])
	quit()
