class_name DungeonGuardianData
extends EnemyData

func _init() -> void:
	enemy_name   = "Dungeon Guardian"
	enemy_type   = "DungeonGuardian"
	sprite       = preload("res://assets/sprites/enemy/dragon/dragon.png")
	portrait     = preload("res://assets/ui/portraits/enemy/dragon/dragon.png")
	sprite_scale = 2.0
	ac           = 18
	max_hp       = 180
	speed        = 3
	attack_bonus = 9
	action_pool = [
		"Guardian Smash on %s...",
		"Guardian Smash on %s...",
		"Shockwave!",
		"Shockwave!",
		"Enraging!",
		"Ground Slam at %s...",
	]
	action_behaviors = [
		{"range": 1, "damage_mult": 1.6, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.6, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.2, "aoe_radius": 2, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.2, "aoe_radius": 2, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "raging", "buff_value": 5, "buff_turns": 3},
		{"range": 2, "damage_mult": 2.0, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.40, "buff_type": "",       "buff_value": 0, "buff_turns": 0},
	]
