class_name TypistHammerShockwaveHitbox
extends RefCounted

const TEXTURE: Texture2D = preload("res://assets/effects/typist_hammer_shockwave.png")
const DRAW_SCALE := 1.8
const DEFAULT_SOURCE_SIZE := Vector2(64.0, 64.0)

static var _opaque_pixel_centers := PackedVector2Array()
static var _source_size := DEFAULT_SOURCE_SIZE


static func intersects_ellipse(effect: Dictionary, ellipse_center: Vector2, radius_x: float, radius_y: float) -> bool:
	if radius_x <= 0.0 or radius_y <= 0.0:
		return false
	var radius_x_squared := radius_x * radius_x
	var radius_y_squared := radius_y * radius_y
	for source_pixel in opaque_pixel_centers():
		var offset := source_pixel_to_world_position(effect, source_pixel) - ellipse_center
		if (offset.x * offset.x) / radius_x_squared + (offset.y * offset.y) / radius_y_squared <= 1.0:
			return true
	return false


static func intersects_circle(effect: Dictionary, circle_center: Vector2, radius: float) -> bool:
	return intersects_ellipse(effect, circle_center, radius, radius)


static func opaque_pixel_centers() -> PackedVector2Array:
	if not _opaque_pixel_centers.is_empty():
		return _opaque_pixel_centers
	var image := TEXTURE.get_image()
	if image == null or image.is_empty():
		push_error("三叉震槌の衝撃波テクスチャを読み込めません")
		return _opaque_pixel_centers
	_source_size = Vector2(image.get_size())
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				_opaque_pixel_centers.append(Vector2(float(x) + 0.5, float(y) + 0.5))
	return _opaque_pixel_centers


static func source_pixel_to_world_position(effect: Dictionary, source_pixel: Vector2) -> Vector2:
	var direction: Vector2 = effect.get("direction", effect.get("velocity", Vector2.LEFT))
	if direction.length_squared() <= 0.0:
		direction = Vector2.LEFT
	else:
		direction = direction.normalized()
	var effect_center: Vector2 = effect.get("position", Vector2(effect.get("origin", Vector2.ZERO)) + direction * float(effect.get("radius", 0.0)))
	var local_pixel_position := (source_pixel - _source_size * 0.5) * DRAW_SCALE
	return effect_center + local_pixel_position.rotated(direction.angle() - PI)
