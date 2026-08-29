class_name ChallengeDefinition
extends Resource

@export_enum("typing", "arithmetic", "tracing") var challenge_type: String = "typing"
@export var prompt: String
@export var time_limit_seconds: float = 6.0
@export var passing_score: int = 60
