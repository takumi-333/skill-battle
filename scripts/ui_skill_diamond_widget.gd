@tool
extends Control

class_name HudSkillDiamondWidget

const WIDGET_FONT: FontFile = preload("res://resources/DotGothic16/DotGothic16-Regular.ttf")
const SPACE_KEY_TEXTURE: Texture2D = preload("res://assets/ui/skill_icons/skill_placeholder_square.png")

@export var preview_frame: Texture2D = preload("res://assets/ui/skill_diamond_frames/skill_diamond_large_ready.png")
@export var preview_hole_mask: Texture2D = preload("res://assets/ui/skill_diamond_frames/skill_diamond_large_hole_mask.png")
@export var preview_icon: Texture2D = preload("res://assets/ui/skill_icons/typist_hammer_spin.png")
@export var preview_theme_color := Color("121F18")
@export var preview_key := "1"
@export_range(0.1, 1.0, 0.05) var icon_scale := 0.6

var frame_texture: Texture2D
var icon_rect: TextureRect
var background_rect: TextureRect
var frame_rect: TextureRect
var key_label: Label
var icon_material: ShaderMaterial
var background_material: ShaderMaterial
var badge_disc: BadgeDisc

class BadgeDisc extends Control:
	var center_ratio := Vector2(0.5, 0.78)
	var radius_ratio := 0.06

	func _draw() -> void:
		draw_circle(Vector2(size.x * center_ratio.x, size.y * center_ratio.y), size.x * radius_ratio, Color("05050a"))

func _ready() -> void:
	if icon_rect == null:
		_build_layers()
	if Engine.is_editor_hint():
		_apply_preview()

func _apply_preview() -> void:
	configure(preview_frame, preview_key, size, preview_icon, preview_hole_mask, Vector2(0.5, 0.401), Vector2(0.5, 0.775), 0.081, preview_theme_color)

func configure(texture: Texture2D, binding: String, widget_size: Vector2, icon_texture: Texture2D, hole_mask: Texture2D, hole_center: Vector2, badge_center: Vector2, badge_radius: float, theme_color: Color) -> void:
	frame_texture = texture
	_build_layers()
	background_rect.texture = _make_background(theme_color)
	icon_rect.texture = icon_texture
	icon_rect.visible = icon_texture != null
	frame_rect.texture = frame_texture
	badge_disc.center_ratio = badge_center
	badge_disc.radius_ratio = badge_radius
	badge_disc.position = Vector2.ZERO
	badge_disc.size = size
	key_label.text = binding
	icon_material.set_shader_parameter("hole_mask", hole_mask)
	icon_material.set_shader_parameter("hole_center", hole_center)
	icon_material.set_shader_parameter("icon_scale", icon_scale)
	background_material.set_shader_parameter("hole_mask", hole_mask)
	queue_redraw()

func set_cooldown(remaining: float, duration: float, is_unavailable: bool = false) -> void:
	if icon_material == null:
		return
	var progress := clampf(1.0 - maxf(0.0, remaining) / maxf(0.001, duration), 0.0, 1.0)
	icon_material.set_shader_parameter("progress", 0.0 if is_unavailable else progress)
	icon_material.set_shader_parameter("unavailable", is_unavailable)

func _build_layers() -> void:
	if icon_rect != null:
		return
	# These nodes are authored in the prefab so their layout can be edited in
	# the Inspector. Only materials/textures/state are configured at runtime.
	icon_rect = get_node_or_null("Icon") as TextureRect
	background_rect = get_node_or_null("Background") as TextureRect
	frame_rect = get_node_or_null("Frame") as TextureRect
	key_label = get_node_or_null("KeyLabel") as Label
	if icon_rect != null and background_rect != null and frame_rect != null and key_label != null:
		background_material = _make_material(false)
		background_rect.material = background_material
		icon_material = _make_material(true)
		icon_rect.material = icon_material
		badge_disc = get_node_or_null("BadgeDisc") as BadgeDisc
		if badge_disc == null:
			badge_disc = BadgeDisc.new()
			badge_disc.name = "BadgeDiscRuntime"
			badge_disc.z_index = 1
			badge_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(badge_disc)
		return
	background_rect = TextureRect.new()
	background_rect.z_index = -1
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_SCALE
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_material = _make_material(false)
	background_rect.material = background_material
	add_child(background_rect)
	icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_material = _make_material(true)
	icon_rect.material = icon_material
	add_child(icon_rect)
	badge_disc = BadgeDisc.new()
	badge_disc.z_index = 1
	badge_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge_disc)
	frame_rect = TextureRect.new()
	frame_rect.z_index = 3
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame_rect)
	key_label = Label.new()
	key_label.size = Vector2(72.0, 26.0)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("font", WIDGET_FONT)
	key_label.add_theme_font_size_override("font_size", 15)
	key_label.add_theme_color_override("font_color", Color("fff2b0"))
	key_label.add_theme_color_override("font_outline_color", Color("fff2b0"))
	key_label.add_theme_constant_override("outline_size", 2)
	key_label.z_index = 2
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_label)

func _make_material(with_cooldown: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float progress = 1.0;
	uniform bool unavailable = false;
	uniform sampler2D hole_mask;
	uniform vec2 hole_center = vec2(0.5, 0.43);
	uniform float icon_scale = 0.6;
	void fragment() {
		if (texture(hole_mask, UV).a < 0.5) discard;
		vec2 source_uv = UV;
		if (WITH_COOLDOWN) {
			source_uv = (UV - vec2(0.5)) / icon_scale + vec2(0.5);
		}
		if (source_uv.x < 0.0 || source_uv.x > 1.0 || source_uv.y < 0.0 || source_uv.y > 1.0) {
			COLOR = vec4(0.0);
		} else {
			vec4 source = texture(TEXTURE, source_uv);
			if (WITH_COOLDOWN) {
			vec2 point = UV - hole_center;
			float angle = atan(point.x, -point.y);
			if (angle < 0.0) angle += 6.28318530718;
			float lit = step(angle, progress * 6.28318530718);
			float brightness = unavailable ? 0.16 : mix(0.18, 1.0, lit);
			COLOR = vec4(source.rgb * brightness, source.a);
			} else {
				COLOR = source;
			}
		}
	}
	""".replace("WITH_COOLDOWN", "true" if with_cooldown else "false")
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _make_background(theme_color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([theme_color.lightened(0.08), theme_color.darkened(0.16)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	return texture
