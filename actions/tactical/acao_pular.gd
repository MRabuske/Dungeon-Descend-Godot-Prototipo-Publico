class_name AcaoPular
extends ActionData

# Pular (Jump, BG3): Ação Bônus universal. Mira um tile de pouso (atravessa void/
# superfícies). PROVOCA Ataque de Oportunidade como o movimento normal — evita OA
# só o Desengajar. Custo de movimento fixo (2 tiles); alcance por FOR (jump_reach).
# O tile-mode vem de enter_attack_mode reconhecer AcaoPular; a prévia é o arco
# seguindo o mouse + realce dos pousos. Resolução em BattleState.resolve_jump().
func _init() -> void:
	label        = "Pular"
	action_type  = Type.ATTACK
	shape        = SHAPE_ARROW
	color_idx    = COLOR_MOVE
	bonus_action = true
	attack_range = 1
	aoe_radius   = 0
	damage_attribute  = DamageAttribute.NONE
	damage_dice_count = 0
	damage_dice_sides = 0
