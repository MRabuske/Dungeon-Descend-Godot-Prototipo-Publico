class_name MagoData
extends HeroData

func _init() -> void:
	hero_name    = "Mago"
	hero_class   = "Wizard"
	sprite       = preload("res://assets/sprites/hero/mago/mago.png")
	portrait     = preload("res://assets/ui/portraits/hero/mago/mago.png")
	sprite_frames = preload("res://assets/sprites/hero/mago/mago_animation.tres")
	level        = 4
	base_hp      = 60
	max_hp       = 100
	caster_type  = CasterType.FULL
	ac           = 12
	initiative   = 5
	speed        = 6
	proficiency  = 3
	strength     = 8
	dexterity    = 14
	intelligence = 18
	wisdom       = 12
	constitution = 10
	charisma     = 10
	save_proficiencies = ["INT", "WIS"]
	weapon = HeroData.make_weapon("Quarterstaff", 1, 6, ActionData.DamageAttribute.STR, false, 8)
	actions = [AtqArcano.new(), AcaoMover.new()]
	skills  = [SpellFogo.new(), SpellGelo.new(), SpellTrovao.new(), SpellCura.new(), SpellCloudOfDaggers.new()]
