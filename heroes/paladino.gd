class_name PaladinoData
extends HeroData

func _init() -> void:
	hero_name    = "Paladino"
	hero_class   = "Paladin"
	sprite       = preload("res://assets/sprites/hero/paladino/paladino.png")
	portrait     = preload("res://assets/ui/portraits/hero/paladino/paladino.png")
	level        = 4
	base_hp      = 80
	max_hp       = 110
	base_mp      = 40
	max_mp       = 60
	ac           = 16
	initiative   = 6
	speed        = 6
	proficiency  = 3
	strength     = 16
	dexterity    = 10
	intelligence = 8
	wisdom       = 14
	constitution = 15
	damage_reduction = 0
	actions = [AtqDivino.new(), AcaoMover.new()]
	skills  = [SkillSmite.new(), SkillCuraMaos.new()]
