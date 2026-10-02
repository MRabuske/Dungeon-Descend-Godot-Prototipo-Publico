class_name LadraoData
extends HeroData

func _init() -> void:
	hero_name    = "Ladrao"
	hero_class   = "Rogue"
	sprite       = preload("res://assets/sprites/hero/ladrao/ladrao.png")
	portrait     = preload("res://assets/ui/portraits/hero/ladrao/ladrao.png")
	sprite_frames = preload("res://assets/sprites/hero/ladrao/ladrao_animation.tres")
	level        = 4
	base_hp      = 55
	max_hp       = 100
	ac           = 13
	initiative   = 9
	speed        = 9
	proficiency  = 3
	strength     = 10
	dexterity    = 18
	intelligence = 12
	wisdom       = 11
	constitution = 11
	charisma     = 15
	save_proficiencies = ["DEX", "INT"]

	weapon = HeroData.make_weapon("Shortsword", 1, 6, ActionData.DamageAttribute.DEX, true)
	var an := AtqNormal.new()
	an.damage_attribute = ActionData.DamageAttribute.DEX
	actions = [an, AtqRapido.new(), AcaoMover.new()]
	skills  = []
	reactions = [ReactionUncannyDodge.new()]
