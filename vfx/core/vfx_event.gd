class_name VFXEvent
extends RefCounted

# ======================================================
# Contrato entre gameplay e visual.
# Adicionar nova habilidade = adicionar 1 linha aqui.
# ======================================================
enum Type {
	# Ataques corpo a corpo
	SLASH_LIGHT,
	SLASH_MEDIUM,
	SLASH_HEAVY,
	SLASH_CRIT,

	# Projéteis
	PROJECTILE_ARROW,
	PROJECTILE_MAGIC,

	# Impacto no alvo
	IMPACT_LIGHT,
	IMPACT_HEAVY,
	IMPACT_CRIT,

	# Skills por elemento
	SKILL_FIRE,
	SKILL_ICE,
	SKILL_LIGHTNING,
	SKILL_HOLY,

	# Status
	BUFF_APPLY,
	DEBUFF_APPLY,
	POISON_TICK,
	STUN_APPLY,

	# Câmera e tela
	SCREEN_SHAKE_LIGHT,
	SCREEN_SHAKE_HEAVY,
	SCREEN_FLASH_WHITE,
	SCREEN_FLASH_RED,

	# Personagem
	DEATH_HERO,
	DEATH_ENEMY,
	MOVE_STEP,
	MOVE_DASH,
}
