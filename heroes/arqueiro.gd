class_name ArqueiroData
extends HeroData

func _init() -> void:
	hero_name    = "Arqueiro"
	hero_class   = "Ranger"
	sprite = preload("res://assets/sprites/hero/arqueiro/arqueiro.png")
	portrait = preload("res://assets/ui/portraits/hero/arqueiro/arqueiro.png")
	sprite_frames = preload("res://assets/sprites/hero/arqueiro/arqueiro_animation.tres")
	level        = 4
	base_hp      = 70
	max_hp       = 100
	caster_type  = CasterType.HALF
	ac           = 14
	initiative   = 10
	speed        = 8
	proficiency  = 3
	strength     = 12
	dexterity    = 18
	intelligence = 10
	wisdom       = 13
	constitution = 12
	charisma     = 10
	save_proficiencies = ["STR", "DEX"]
	weapon = HeroData.make_weapon("Longbow", 1, 8, ActionData.DamageAttribute.DEX)
	actions = [AtqRapido.new(), AtqPreciso.new(), AcaoMover.new()]
	skills  = [SkillChuvaFlechas.new()]
