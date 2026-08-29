class_name EliteWarriorData
extends EnemyData

func _init() -> void:
	enemy_name   = "Elite Warrior"
	enemy_type   = "EliteWarrior"
	sprite       = preload("res://assets/sprites/enemy/orc_warrior/orc_warrior.png")
	portrait     = preload("res://assets/ui/portraits/enemy/orc_warrior/orc_warrior.png")
	ac           = 17
	max_hp       = 70
	speed        = 4
	attack_bonus = 7
	action_pool = [
		"Crushing Blow on %s...",
		"Crushing Blow on %s...",
		"Sweeping Strike!",
		"Charging at %s...",
		"Enraging!",
	]
	action_behaviors = [
		{"range": 1, "damage_mult": 1.4, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.4, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.0, "aoe_radius": 1, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.6, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.25, "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "raging", "buff_value": 4, "buff_turns": 2},
	]
