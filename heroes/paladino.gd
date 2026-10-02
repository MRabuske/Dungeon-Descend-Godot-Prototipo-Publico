class_name PaladinoData
extends HeroData

func _init() -> void:
	hero_name    = "Paladino"
	hero_class   = "Paladin"
	sprite       = preload("res://assets/sprites/hero/paladino/paladino.png")
	portrait     = preload("res://assets/ui/portraits/hero/paladino/paladino.png")
	sprite_frames = preload("res://assets/sprites/hero/paladino/paladino_animation.tres")
	level        = 4
	base_hp      = 80
	max_hp       = 110
	caster_type  = CasterType.HALF
	ac           = 16
	initiative   = 6
	speed        = 6
	proficiency  = 3
	strength     = 16
	dexterity    = 10
	intelligence = 8
	wisdom       = 14
	constitution = 15
	charisma     = 16
	save_proficiencies = ["WIS", "CHA"]
	damage_reduction = 0
	weapon = HeroData.make_weapon("Longsword", 1, 8, ActionData.DamageAttribute.STR, false, 10)
	actions = [AtqDivino.new(), AcaoMover.new()]
	skills  = [SkillSmite.new(), SkillCuraMaos.new()]
	reactions = [ReactionDivineSmite.new()]
