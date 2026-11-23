class_name InputRumble
extends RefCounted

# Perfis e decisão de vibração. Lógica pura: o autoload InputDevice só executa o que
# decide() devolver. Vibrações curtas e distintas pela duração/intensidade; eventos
# simultâneos não empilham (cooldown, e só uma prioridade maior interrompe).

const COOLDOWN_MS := 250

const CRIT_DEALT := &"crit_dealt"   # herói do jogador causou crítico
const CRIT_TAKEN := &"crit_taken"   # herói do jogador recebeu crítico
const DOWNED := &"downed"           # herói do jogador ficou Downed

static func profile(kind: StringName) -> Dictionary:
	match kind:
		CRIT_DEALT:
			return {"weak": 0.0, "strong": 0.7, "duration": 0.10, "priority": 1}
		CRIT_TAKEN:
			return {"weak": 0.8, "strong": 0.5, "duration": 0.20, "priority": 2}
		DOWNED:
			return {"weak": 0.6, "strong": 1.0, "duration": 0.45, "priority": 3}
	return {}

# {} = não vibrar. Devolve o perfil quando deve vibrar.
static func decide(kind: StringName, enabled: bool, gamepad_active: bool,
		now_ms: int, last_ms: int, last_priority: int) -> Dictionary:
	if not enabled or not gamepad_active:
		return {}
	var p: Dictionary = profile(kind)
	if p.is_empty():
		return {}
	if now_ms - last_ms < COOLDOWN_MS and int(p["priority"]) <= last_priority:
		return {}
	return p
