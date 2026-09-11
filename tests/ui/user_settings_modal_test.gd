extends SceneTree


const SETTINGS_PATH := "user://settings.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var had_settings := FileAccess.file_exists(SETTINGS_PATH)
	var original_settings := FileAccess.get_file_as_bytes(SETTINGS_PATH) if had_settings else PackedByteArray()
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)
	var prototype := main_scene.instantiate()
	root.add_child(prototype)
	await process_frame

	var modal := prototype.get_node("UIRoot/Home/UserSettingsModal") as Control
	var dimmer := prototype.get_node("UIRoot/Home/UserSettingsModal/Dimmer") as Control
	var panel := prototype.get_node("UIRoot/Home/UserSettingsModal/Panel") as Control
	assert(modal.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(dimmer.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(panel.mouse_filter == Control.MOUSE_FILTER_STOP)

	var debug_button := prototype.get_node("UIRoot/Home/DebugButton") as Button
	var original_debug_disabled := debug_button.disabled
	var original_debug_mouse_filter := debug_button.mouse_filter
	prototype.call("show_home")
	prototype.call("open_user_settings")
	var name_input := prototype.get_node("UIRoot/Home/UserSettingsModal/Panel/NameInput") as LineEdit
	var url_input := prototype.get_node("UIRoot/Home/UserSettingsModal/Panel/LobbyUrlInput") as LineEdit
	var token_input := prototype.get_node("UIRoot/Home/UserSettingsModal/Panel/InviteTokenInput") as LineEdit
	var save_button := prototype.get_node("UIRoot/Home/UserSettingsModal/Panel/SaveButton") as Button
	assert(debug_button.disabled)
	assert(debug_button.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var panel_position := (save_button.get_parent() as Control).position
	var save_rect := Rect2(panel_position + save_button.position, save_button.size)
	var debug_rect := Rect2(debug_button.position, debug_button.size)
	# The two buttons intentionally overlap in the home-scene coordinate space;
	# the modal input barrier, not a layout workaround, prevents click-through.
	assert(save_rect.intersects(debug_rect))

	name_input.text = "modal-test"
	url_input.text = "https://lobby.example.test"
	token_input.text = "a".repeat(32)
	save_button.pressed.emit()

	# SaveButton emits pressed during its mouse-release event. The modal must
	# still block input until that event has finished dispatching.
	assert(modal.visible)
	assert(str(prototype.get("screen")) == "home")
	await process_frame
	await process_frame
	assert(not modal.visible)
	assert(str(prototype.get("screen")) == "home")
	assert(debug_button.disabled == original_debug_disabled)
	assert(debug_button.mouse_filter == original_debug_mouse_filter)
	prototype.set("user_display_name", "")
	prototype.set("lobby_api_url", "")
	prototype.set("lobby_access_token", "")
	prototype.call("load_user_settings")
	assert(str(prototype.get("user_display_name")) == "modal-test")
	assert(str(prototype.get("lobby_api_url")) == "https://lobby.example.test")
	assert(str(prototype.get("lobby_access_token")) == "a".repeat(32))
	prototype.queue_free()
	_restore_settings(had_settings, original_settings)
	print("user settings modal tests passed")
	quit()
func _restore_settings(had_settings: bool, original_settings: PackedByteArray) -> void:
	if had_settings:
		var restore_file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		assert(restore_file != null)
		restore_file.store_buffer(original_settings)
		return
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
