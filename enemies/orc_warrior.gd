class_name OrcWarriorData
extends EnemyData

func _init() -> void:
	enemy_name   = "Orc Warrior"
	enemy_type   = "Orc"
	sprite       = preload("res://assets/sprites/enemy/orc_warrior/orc_warrior.png")
	portrait     = preload("res://assets/ui/portraits/enemy/orc_warrior/orc_warrior.png")
	ac           = 15
	max_hp       = 40
	speed        = 4
	attack_bonus = 4
	action_pool = [
		"Smashing %s...",
		"Smashing %s...",
		"Charging at %s...",
		"Charging at %s...",
		"Raging!",
	]
	action_behaviors = [
		{"range": 1, "damage_mult": 1.2, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.2, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.5, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.2, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.5, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.2, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "raging", "buff_value": 3, "buff_turns": 2},
	]
