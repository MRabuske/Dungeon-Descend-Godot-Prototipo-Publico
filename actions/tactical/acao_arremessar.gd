class_name AcaoArremessar
extends ActionData

# Arremessar (Throw, BG3): Ação universal. Joga um item a distância, com efeito
# em área no tile-alvo. Esta versão genérica arremessa um frasco incendiário
# (cria superfície de Fogo + dano). Itens da barra preenchem estes dados.
# Resolução em BattleState.resolve_throw().
func _init() -> void:
	label             = "Arremessar"
	action_type       = Type.ATTACK
	shape             = SHAPE_CIRCLE
	color_idx         = COLOR_ITEM
	attack_range      = 6
	aoe_radius        = 1
	damage_attribute  = DamageAttribute.NONE
	damage_type       = DamageType.FIRE
	damage_dice_count = 2
	damage_dice_sides = 6
	creates_surface   = SurfaceType.Type.FIRE
