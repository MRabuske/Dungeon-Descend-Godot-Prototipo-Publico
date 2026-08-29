class_name DarkMageData
extends EnemyData

func _init() -> void:
	enemy_name   = "Dark Mage"
	enemy_type   = "Mage"
	sprite       = preload("res://assets/sprites/enemy/dark_mage/dark_mage.png")
	portrait     = preload("res://assets/ui/portraits/enemy/dark_mage/dark_mage.png")
	ac           = 11
	max_hp       = 25
	speed        = 5
	attack_bonus = 5
	action_pool = [
		"Casting Shadow Bolt at %s...",
		"Casting Shadow Bolt at %s...",
		"Casting Frost Nova!",
		"Casting Frost Nova!",
		"Teleporting...",
	]
	action_behaviors = [
		{"range": 5, "damage_mult": 1.2, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",           "buff_value": 0, "buff_turns": 0},
		{"range": 5, "damage_mult": 1.2, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",           "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 0.8, "aoe_radius": 1, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.4, "buff_type": "",           "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 0.8, "aoe_radius": 1, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.4, "buff_type": "",           "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "teleporting", "buff_value": 0, "buff_turns": 0},
	]
