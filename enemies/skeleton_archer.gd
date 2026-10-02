class_name SkeletonArcherData
extends EnemyData

func _init() -> void:
	enemy_name   = "Skeleton Archer"
	enemy_type   = "Undead"
	sprite       = preload("res://assets/sprites/enemy/skeleton_archer/skeleton_archer.png")
	portrait     = preload("res://assets/ui/portraits/enemy/skeleton_archer/skeleton_archer.png")
	sprite_frames = preload("res://assets/sprites/enemy/skeleton_archer/skeleton_archer_animation.tres")
	ac           = 12
	max_hp       = 30
	speed        = 5
	attack_bonus = 3
	proficiency  = 2
	crit_threshold = 20
	damage_dice_count = 1
	damage_dice_sides = 6
	attack_damage_attribute = ActionData.DamageAttribute.DEX
	level        = 2
	strength     = 10
	dexterity    = 14
	constitution = 10
	intelligence = 6
	wisdom       = 8
	charisma     = 4
	action_pool = [
		"Shooting an arrow at %s...",
		"Shooting an arrow at %s...",
	]
	action_behaviors = [
		{"range": 5, "damage_mult": 1.0, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "", "buff_value": 0, "buff_turns": 0},
		{"range": 5, "damage_mult": 1.0, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "", "buff_value": 0, "buff_turns": 0},
	]
