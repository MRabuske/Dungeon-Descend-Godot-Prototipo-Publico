class_name EliteWarriorData
extends EnemyData

func _init() -> void:
	enemy_name   = "Elite Warrior"
	enemy_type   = "EliteWarrior"
	sprite       = preload("res://assets/sprites/enemy/stone_golem/stone_golem.png")
	portrait     = preload("res://assets/ui/portraits/enemy/stone_golem/stone_golem.png")
	sprite_frames = preload("res://assets/sprites/enemy/stone_golem/stone_golem_animation.tres")
	sprite_scale = 1.5
	ac           = 17
	max_hp       = 70
	speed        = 4
	attack_bonus = 7
	proficiency  = 3
	crit_threshold = 19
	damage_dice_count = 1
	damage_dice_sides = 10
	attack_damage_attribute = ActionData.DamageAttribute.STR
	level        = 5
	strength     = 18
	dexterity    = 12
	constitution = 16
	intelligence = 10
	wisdom       = 10
	charisma     = 10
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
