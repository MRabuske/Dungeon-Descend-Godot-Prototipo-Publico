class_name EnemyData
extends Resource

@export var enemy_name: String = ""
@export var enemy_type: String = ""

@export_group("Visual")
@export var portrait: Texture2D
@export var sprite: Texture2D
@export var sprite_scale: float = 1.0

@export_group("Stats")
@export var ac: int = 10
@export var max_hp: int = 30
@export var speed: int = 5
@export var attack_bonus: int = 2

@export_group("Actions")
@export var action_pool: Array[String] = []
@export var action_behaviors: Array[Dictionary] = []


func to_combat_dict() -> Dictionary:
	return {
		"name": enemy_name,
		"type": enemy_type,
		"ac": ac,
		"max_hp": max_hp,
		"speed": speed,
		"attack_bonus": attack_bonus,
		"action_pool": action_pool,
		"action_behaviors": action_behaviors,
		"sprite": sprite,
		"portrait": portrait,
		"sprite_scale": sprite_scale,
	}
