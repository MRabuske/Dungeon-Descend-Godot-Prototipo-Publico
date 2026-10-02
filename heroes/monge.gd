class_name MongeData
extends HeroData

func _init() -> void:
	hero_name    = "Monge"
	hero_class   = "Monk"
	sprite       = preload("res://assets/sprites/hero/monge/monge.png")
	portrait     = preload("res://assets/ui/portraits/hero/monge/monge.png")
	sprite_frames = preload("res://assets/sprites/hero/monge/monge_animation.tres")
	level        = 4
	base_hp      = 65
	max_hp       = 90
	ki_per_level = 1
	ac           = 14
	initiative   = 11
	speed        = 10
	proficiency  = 3
	strength     = 12
	dexterity    = 18
	intelligence = 10
	wisdom       = 14
	constitution = 13
	charisma     = 10
	save_proficiencies = ["STR", "DEX"]
	damage_reduction = 0
	weapon = HeroData.make_weapon("Unarmed", 1, 6, ActionData.DamageAttribute.DEX, true)
	actions = [AtqSoco.new(), AtqRapido.new(), AcaoMover.new()]
	skills  = [SkillFlurry.new(), SkillPassoVento.new()]
	reactions = [ReactionDeflectMissiles.new(), ReactionStunningStrike.new()]
