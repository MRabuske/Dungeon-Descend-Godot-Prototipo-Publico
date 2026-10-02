class_name ClérigoData
extends HeroData

func _init() -> void:
	hero_name    = "Clérigo"
	hero_class   = "Cleric"
	sprite       = preload("res://assets/sprites/hero/clerigo/clerigo.png")
	portrait     = preload("res://assets/ui/portraits/hero/clerigo/clerigo.png")
	sprite_frames = preload("res://assets/sprites/hero/clerigo/clerigo_animation.tres")
	level        = 4
	base_hp      = 75
	max_hp       = 100
	caster_type  = CasterType.FULL
	ac           = 15
	initiative   = 6
	speed        = 7
	proficiency  = 3
	strength     = 12
	dexterity    = 10
	intelligence = 12
	wisdom       = 16
	constitution = 14
	charisma     = 13
	save_proficiencies = ["WIS", "CHA"]
	weapon = HeroData.make_weapon("Mace", 1, 6, ActionData.DamageAttribute.STR)
	actions = [AtqDivino.new(), AcaoMover.new()]
	skills  = [SpellCura.new(), SkillCuraArea.new()]
