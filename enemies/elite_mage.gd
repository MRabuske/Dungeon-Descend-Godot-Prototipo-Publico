class_name EliteMageData
extends EnemyData

func _init() -> void:
	enemy_name   = "Elite Mage"
	enemy_type   = "EliteMage"
	sprite       = preload("res://assets/sprites/enemy/dark_mage/dark_mage.png")
	portrait     = preload("res://assets/ui/portraits/enemy/dark_mage/dark_mage.png")
	ac           = 13
	max_hp       = 55
	speed        = 5
	attack_bonus = 8
	action_pool = [
		"Casting Arcane Bolt at %s...",
		"Casting Arcane Bolt at %s...",
		"Casting Ice Storm!",
		"Casting Ice Storm!",
		"Channeling dark power...",
	]
	action_behaviors = [
		{"range": 6, "damage_mult": 1.4, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 6, "damage_mult": 1.4, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.0, "aoe_radius": 2, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.30, "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.0, "aoe_radius": 2, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.30, "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "raging", "buff_value": 3, "buff_turns": 2},
	]
