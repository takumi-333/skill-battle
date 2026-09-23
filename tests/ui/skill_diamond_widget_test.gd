extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var prototype = MAIN_SCENE.instantiate()
	root.add_child(prototype)
	await process_frame
	prototype.phase = "match"
	prototype.call("apply_screen_state", "match")
	prototype.network_mode = "local"
	prototype.debug_controlled_player_id = 1
	prototype.call("set_gameplay_hud_visible", true)
	prototype.update_hud()

	var widget = prototype.skill_widgets[1]
	assert(widget.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(widget.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	assert(bool(widget.call("_has_point", widget.size * 0.5)))
	assert(not bool(widget.call("_has_point", Vector2(1.0, 1.0))))
	widget.call("_on_mouse_entered")
	await process_frame
	assert(widget.scale.x > 1.0)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = widget.get_global_rect().get_center()
	click.pressed = true
	widget.call("_on_gui_input", click)
	assert(bool(widget.get("is_pressing")))
	assert(int(prototype.challenge_owner) == 1)
	click.pressed = false
	widget.call("_on_gui_input", click)
	assert(str(prototype.challenge_skill).contains("small"))
	prototype.update_hud()
	assert(widget.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	prototype.call("clear_active_challenge_state")
	_reset_player_after_challenge(prototype)
	prototype.call("configure_player", 1, 2)
	prototype.update_hud()
	assert(widget.mouse_filter == Control.MOUSE_FILTER_STOP)
	prototype.call("request_skill_activation", 1, 1)
	assert(int(prototype.challenge_owner) == 1)
	var trace_canvas: Control = prototype.challenge_trace_canvas
	assert(trace_canvas.visible)
	prototype.update_hud()
	assert(widget.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	prototype.call("clear_active_challenge_state")
	_reset_player_after_challenge(prototype)
	prototype.update_hud()
	var hud_press := InputEventMouseButton.new()
	hud_press.button_index = MOUSE_BUTTON_LEFT
	hud_press.position = widget.get_global_rect().get_center()
	hud_press.pressed = true
	widget.call("set_interaction_enabled", true)
	assert(bool(widget.call("contains_input_point", hud_press.position)))
	prototype.call("_input", hud_press)
	assert(int(prototype.challenge_owner) == 1)
	prototype.call("clear_active_challenge_state")
	_reset_player_after_challenge(prototype)
	prototype.update_hud()
	widget.call("set_interaction_enabled", false)
	assert(widget.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	widget.call("_on_gui_input", click)
	assert(int(prototype.challenge_owner) == 0)

	prototype.network_mode = "client"
	prototype.pending_client_skill_requests.fill(false)
	prototype.call("request_skill_activation", 2)
	assert(bool(prototype.pending_client_skill_requests[2]))
	prototype.challenge_owner = 1
	prototype.call("request_skill_activation", 3)
	assert(not bool(prototype.pending_client_skill_requests[3]))

	prototype.queue_free()
	print("skill diamond widget test passed")
	quit()


func _reset_player_after_challenge(prototype) -> void:
	var player: Dictionary = prototype.players[1]
	player["focused"] = false
	player["small_cooldown"] = 0.0
	prototype.players[1] = player
