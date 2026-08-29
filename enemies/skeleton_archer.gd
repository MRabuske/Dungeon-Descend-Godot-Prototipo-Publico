class_name SkeletonArcherData
extends EnemyData

func _init() -> void:
	enemy_name   = "Skeleton Archer"
	enemy_type   = "Undead"
	sprite       = preload("res://assets/sprites/enemy/skeleton_archer/skeleton_archer.png")
	portrait     = preload("res://assets/ui/portraits/enemy/skeleton_archer/skeleton_archer.png")
	ac           = 12
	max_hp       = 30
	speed        = 5
	attack_bonus = 3
	action_pool = [
		"Shooting an arrow at %s...",
		"Shooting an arrow at %s...",
		"Aiming at %s...",
		"Aiming at %s...",
		"Rattling bones...",
	]
	action_behaviors = [
		{"range": 5, "damage_mult": 1.0, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 5, "damage_mult": 1.0, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "aiming",  "buff_value": 2, "buff_turns": 1},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "aiming",  "buff_value": 2, "buff_turns": 1},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "rattling", "buff_value": 0, "buff_turns": 0},
	]
