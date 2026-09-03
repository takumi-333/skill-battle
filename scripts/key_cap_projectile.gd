class_name KeyCapProjectile
extends Node2D

@onready var key_sprite: Sprite2D = $KeyCap
@onready var character_label: Label = $Character

func set_character(character: String) -> void:
	character_label.text = "␣" if character == " " else character
	character_label.visible = not character.is_empty()

func set_projectile_visible(value: bool) -> void:
	visible = value
