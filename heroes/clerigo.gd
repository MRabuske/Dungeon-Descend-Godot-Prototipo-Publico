class_name ClérigoData
extends HeroData

func _init() -> void:
	hero_name    = "Clérigo"
	hero_class   = "Cleric"
	sprite       = preload("res://assets/sprites/hero/clerigo/clerigo.png")
	portrait     = preload("res://assets/ui/portraits/hero/clerigo/clerigo.png")
	level        = 4
	base_hp      = 75
	max_hp       = 100
	base_mp      = 90
	max_mp       = 100
	ac           = 15
	initiative   = 6
	speed        = 7
	proficiency  = 3
	strength     = 12
	dexterity    = 10
	intelligence = 12
	wisdom       = 16
	constitution = 14
	actions = [AtqDivino.new(), AcaoMover.new()]
	skills  = [SpellCura.new(), SkillCuraArea.new()]
