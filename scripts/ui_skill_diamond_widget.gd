@tool
extends Control

class_name HudSkillDiamondWidget

signal activation_requested(slot: int)

const WIDGET_FONT: FontFile = preload("res://resources/DotGothic16/DotGothic16-Regular.ttf")
const SPACE_KEY_TEXTURE: Texture2D = preload("res://assets/ui/skill_icons/skill_placeholder_square.png")
const HOVER_SCALE := 1.045
const PRESSED_SCALE := 0.965

@export var preview_frame: Texture2D = preload("res://assets/ui/skill_diamond_frames/skill_diamond_large_ready.png")
@export var preview_hole_mask: Texture2D = preload("res://assets/ui/skill_diamond_frames/skill_diamond_large_hole_mask.png")
@export var preview_icon: Texture2D = preload("res://assets/ui/skill_icons/typist_hammer_spin.png")
@export var preview_theme_color := Color("121F18")
@export var preview_key := "1"
@export_range(0.1, 1.0, 0.05) var icon_scale := 0.6
@export var preview_equation_lock := false:
	set(value):
		preview_equation_lock = value
		if Engine.is_editor_hint() and equation_lock_overlay != null:
			equation_lock_overlay.visible = value

var frame_texture: Texture2D
var icon_rect: TextureRect
var background_rect: TextureRect
var frame_rect: TextureRect
var key_label: Label
var icon_material: ShaderMaterial
var background_material: ShaderMaterial
var badge_disc: BadgeDisc
var equation_lock_overlay: TextureRect
var interaction_mask_image: Image
var skill_slot := -1
var interaction_enabled := false
var is_hovering := false
var is_pressing := false
var interaction_tween: Tween

class BadgeDisc extends Control:
	var center_ratio := Vector2(0.5, 0.78)
	var radius_ratio := 0.06

	func _draw() -> void:
		draw_circle(Vector2(size.x * center_ratio.x, size.y * center_ratio.y), size.x * radius_ratio, Color("05050a"))

func _ready() -> void:
	if icon_rect == null:
		_build_layers()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	_refresh_interaction_visuals(false)
	if Engine.is_editor_hint():
		_apply_preview()

func _apply_preview() -> void:
	configure(preview_frame, preview_key, size, preview_icon, preview_hole_mask, Vector2(0.5, 0.401), Vector2(0.5, 0.775), 0.081, preview_theme_color)
	set_equation_lock(preview_equation_lock)

func configure(texture: Texture2D, binding: String, widget_size: Vector2, icon_texture: Texture2D, hole_mask: Texture2D, hole_center: Vector2, badge_center: Vector2, badge_radius: float, theme_color: Color) -> void:
	frame_texture = texture
	interaction_mask_image = hole_mask.get_image() if hole_mask != null else null
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


func configure_interaction(slot: int) -> void:
	skill_slot = slot


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not interaction_enabled:
		is_hovering = false
		is_pressing = false
	mouse_filter = Control.MOUSE_FILTER_STOP if interaction_enabled else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interaction_enabled else Control.CURSOR_ARROW
	_refresh_interaction_visuals()


func contains_input_point(global_point: Vector2) -> bool:
	if not interaction_enabled or not is_visible_in_tree():
		return false
	var global_rect := get_global_rect()
	if not global_rect.has_point(global_point) or global_rect.size.x <= 0.0 or global_rect.size.y <= 0.0:
		return false
	var normalized := (global_point - global_rect.position) / global_rect.size
	return _has_point(normalized * size)


func _has_point(point: Vector2) -> bool:
	if not interaction_enabled or size.x <= 0.0 or size.y <= 0.0:
		return false
	var normalized := Vector2(point.x / size.x, point.y / size.y)
	if normalized.x < 0.0 or normalized.x > 1.0 or normalized.y < 0.0 or normalized.y > 1.0:
		return false
	# The authored mask is also used by the UI shaders to discard the
	# transparent corners, so sampling it keeps hover/click geometry in sync
	# with the visible diamond instead of treating the whole Control rectangle
	# as interactive.
	if interaction_mask_image != null and not interaction_mask_image.is_empty():
		var pixel := Vector2i(
			clampi(int(normalized.x * interaction_mask_image.get_width()), 0, interaction_mask_image.get_width() - 1),
			clampi(int(normalized.y * interaction_mask_image.get_height()), 0, interaction_mask_image.get_height() - 1)
		)
		return interaction_mask_image.get_pixelv(pixel).a >= 0.5
	return absf(normalized.x - 0.5) + absf(normalized.y - 0.5) <= 0.5

func set_cooldown(remaining: float, duration: float, is_unavailable: bool = false) -> void:
	if icon_material == null:
		return
	var progress := clampf(1.0 - maxf(0.0, remaining) / maxf(0.001, duration), 0.0, 1.0)
	icon_material.set_shader_parameter("progress", 0.0 if is_unavailable else progress)
	icon_material.set_shader_parameter("unavailable", is_unavailable)
	background_material.set_shader_parameter("progress", 0.0 if is_unavailable else progress)
	background_material.set_shader_parameter("unavailable", is_unavailable)

func set_equation_lock(locked: bool) -> void:
	_build_layers()
	if equation_lock_overlay == null:
		push_warning("EquationDominationLockOverlay must be authored in the skill diamond scene.")
		return
	equation_lock_overlay.visible = locked


func _on_mouse_entered() -> void:
	if not interaction_enabled:
		return
	is_hovering = true
	_refresh_interaction_visuals()


func _on_mouse_exited() -> void:
	is_hovering = false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_pressing = false
	_refresh_interaction_visuals()


func _on_gui_input(event: InputEvent) -> void:
	if not interaction_enabled or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		is_pressing = true
		_refresh_interaction_visuals()
		accept_event()
		if skill_slot >= 0:
			activation_requested.emit(skill_slot)
		return
	is_pressing = false
	_refresh_interaction_visuals()
	accept_event()


func _refresh_interaction_visuals(animate := true) -> void:
	var target_scale := Vector2.ONE
	var target_modulate := Color.WHITE
	if interaction_enabled and is_pressing:
		target_scale *= PRESSED_SCALE
		target_modulate = Color(1.18, 1.18, 1.18, 1.0)
	elif interaction_enabled and is_hovering:
		target_scale *= HOVER_SCALE
		target_modulate = Color(1.12, 1.12, 1.12, 1.0)
	if interaction_tween and interaction_tween.is_valid():
		interaction_tween.kill()
	if not animate or not is_inside_tree():
		scale = target_scale
		modulate = target_modulate
		return
	interaction_tween = create_tween().set_parallel()
	interaction_tween.tween_property(self, "scale", target_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	interaction_tween.tween_property(self, "modulate", target_modulate, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_layers() -> void:
	if icon_rect != null:
		return
	# These nodes are authored in the prefab so their layout can be edited in
	# the Inspector. Only materials/textures/state are configured at runtime.
	icon_rect = get_node_or_null("Icon") as TextureRect
	background_rect = get_node_or_null("Background") as TextureRect
	frame_rect = get_node_or_null("Frame") as TextureRect
	key_label = get_node_or_null("KeyLabel") as Label
	equation_lock_overlay = get_node_or_null("EquationDominationLockOverlay") as TextureRect
	if icon_rect != null and background_rect != null and frame_rect != null and key_label != null:
		background_material = _make_material(true, false)
		background_rect.material = background_material
		icon_material = _make_material(true, true)
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
	background_material = _make_material(true, false)
	background_rect.material = background_material
	add_child(background_rect)
	icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_material = _make_material(true, true)
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

func _make_material(with_cooldown: bool, scale_icon: bool) -> ShaderMaterial:
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
		if (WITH_ICON_SCALE) {
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
			float brightness = unavailable ? UNAVAILABLE_BRIGHTNESS : mix(COOLDOWN_BRIGHTNESS, 1.0, lit);
			COLOR = vec4(source.rgb * brightness, source.a);
			} else {
				COLOR = source;
			}
		}
	}
	""".replace("WITH_ICON_SCALE", "true" if scale_icon else "false") \
		.replace("WITH_COOLDOWN", "true" if with_cooldown else "false") \
		.replace("UNAVAILABLE_BRIGHTNESS", "0.16" if scale_icon else "0.22") \
		.replace("COOLDOWN_BRIGHTNESS", "0.18" if scale_icon else "0.35")
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
