class_name EnemyData
extends Resource

@export var enemy_name: String = ""
@export var enemy_type: String = ""

@export_group("Visual")
@export var portrait: Texture2D
@export var sprite: Texture2D
@export var sprite_scale: float = 1.0
@export var sprite_frames: SpriteFrames 

@export_group("Stats")
@export var ac: int = 10
@export var max_hp: int = 30
@export var speed: int = 5
@export var attack_bonus: int = 2
@export var proficiency: int = 2
@export var crit_threshold: int = 20
@export var damage_dice_count: int = 1
@export var damage_dice_sides: int = 6
@export var attack_damage_attribute: ActionData.DamageAttribute = ActionData.DamageAttribute.STR
@export var level: int = 1
@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10

@export_group("Examine Data")
@export var resistances: Array[String] = []
@export var vulnerabilities: Array[String] = []
@export var immunities: Array[String] = []
@export var passive_features: Array[String] = []

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
		"proficiency": proficiency,
		"crit_threshold": crit_threshold,
		"damage_dice_count": damage_dice_count,
		"damage_dice_sides": damage_dice_sides,
		"attack_damage_attribute": attack_damage_attribute,
		"action_pool": action_pool,
		"action_behaviors": action_behaviors,
		"sprite": sprite,
		"portrait": portrait,
		"sprite_scale": sprite_scale,
		"level": level,
		"strength": strength,
		"dexterity": dexterity,
		"constitution": constitution,
		"intelligence": intelligence,
		"wisdom": wisdom,
		"charisma": charisma,
		"resistances": resistances,
		"vulnerabilities": vulnerabilities,
		"immunities": immunities,
		"passive_features": passive_features,
		"sprite_frames": sprite_frames, 
	}
