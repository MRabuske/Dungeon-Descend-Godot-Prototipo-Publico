class_name GoblinScoutData
extends EnemyData

func _init() -> void:
	enemy_name   = "Goblin Scout"
	enemy_type   = "Goblin"
	sprite       = preload("res://assets/sprites/enemy/goblin_scout/goblin_scout.png")
	portrait     = preload("res://assets/ui/portraits/enemy/goblin_scout/goblin_scout.png")
	ac           = 13
	max_hp       = 20
	speed        = 6
	attack_bonus = 2
	action_pool = [
		"Attacking %s...",
		"Attacking %s...",
		"Throwing a dagger at %s...",
		"Throwing a dagger at %s...",
		"Fleeing!",
	]
	action_behaviors = [
		{"range": 1, "damage_mult": 1.0,  "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.0,  "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 3, "damage_mult": 0.85, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 3, "damage_mult": 0.85, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0,  "aoe_radius": 0, "is_self_buff": false, "is_flee": true,  "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
	]
