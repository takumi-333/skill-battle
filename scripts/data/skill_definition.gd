class_name SkillDefinition
extends Resource

@export var skill_id: StringName
@export var display_name: String
@export_enum("typing", "arithmetic", "tracing") var challenge_type: String = "typing"
@export var cooldown_seconds: float = 2.0
@export var interruption_gauge: float = 30.0
@export var time_limit_seconds: float = 6.0
@export var challenge_panel_position: Vector2 = Vector2(250.0, 185.0)
@export var challenge_panel_size: Vector2 = Vector2(780.0, 400.0)
