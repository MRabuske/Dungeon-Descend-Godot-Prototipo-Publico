
extends Node

# ======================================================
# Freeze frame — pausa o Engine.time_scale por alguns ms.
# Cria a sensação de peso no impacto.
#
# Uso:
#   HitStop.trigger(0.05)   # hit leve  (~50ms)
#   HitStop.trigger(0.10)   # hit pesado (~100ms)
#   HitStop.trigger(0.14)   # crit / habilidade especial
# ======================================================

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE
# ──────────────────────────────────────────────────────
const DURATION_LIGHT  := 0.05   # segundos — hit leve
const DURATION_MEDIUM := 0.08   # segundos — hit médio
const DURATION_HEAVY  := 0.12   # segundos — hit pesado / crit
const DURATION_DEATH  := 0.18   # segundos — morte
# ──────────────────────────────────────────────────────

var _active := false

# ======================================================
# PUBLIC
# ======================================================
func trigger(duration: float = DURATION_LIGHT) -> void:
	# Evita empilhar múltiplos hit stops
	if _active:
		return
	_active = true
	Engine.time_scale = 0.0
	# process_always = true garante que o timer corra mesmo com time_scale = 0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_active = false

func trigger_light()  -> void: trigger(DURATION_LIGHT)
func trigger_medium() -> void: trigger(DURATION_MEDIUM)
func trigger_heavy()  -> void: trigger(DURATION_HEAVY)
func trigger_death()  -> void: trigger(DURATION_DEATH)
