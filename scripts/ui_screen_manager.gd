class_name UIScreenManager
extends Node

signal screen_changed(screen_name: String)

var panels: Dictionary = {}
var menu_background_root: Control
var menu_background: Control
var title_logo: Control
var hud_root: Control
var challenge_dimmer: Control
var challenge_panel: Control


func configure(screen_panels: Dictionary, background_root: Control, background: Control, logo: Control, hud: Control, dimmer: Control, challenge: Control) -> void:
	panels = screen_panels
	menu_background_root = background_root
	menu_background = background
	title_logo = logo
	hud_root = hud
	challenge_dimmer = dimmer
	challenge_panel = challenge


func show_screen(next_screen: String) -> void:
	for panel in panels.values():
		(panel as Control).visible = false
	var active_panel: Control = panels.get(next_screen) as Control
	if active_panel:
		active_panel.visible = true
	var is_gameplay_screen := next_screen in ["match", "countdown"]
	hud_root.visible = is_gameplay_screen
	var show_menu_background := next_screen in ["title", "home", "practice_select", "debug_select", "connection", "online_waiting", "debug_waiting"]
	menu_background_root.visible = show_menu_background
	menu_background.visible = show_menu_background
	title_logo.visible = next_screen == "title"
	if not is_gameplay_screen:
		challenge_dimmer.visible = false
		challenge_panel.visible = false
	screen_changed.emit(next_screen)
