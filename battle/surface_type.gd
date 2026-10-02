class_name SurfaceType

enum Type {
	NONE              = 0,
	FIRE              = 1,
	ICE               = 2,
	WATER             = 3,
	ELECTRIFIED_WATER = 4,
	ACID              = 5,
	POISON            = 6,
	STEAM             = 7,
	CLOUD_OF_DAGGERS  = 8,
}

# Duration in ROUNDS until the surface expires (decremented once per full round,
# not per individual combatant turn — see advance_turn / _acted_this_round)
const DURATION: Dictionary = {
	Type.FIRE:              4,
	Type.ICE:               3,
	Type.WATER:             5,
	Type.ELECTRIFIED_WATER: 3,
	Type.ACID:              4,
	Type.POISON:            4,
	Type.STEAM:             1,
	Type.CLOUD_OF_DAGGERS:  10,
}

# Tick damage at turn start: {count, sides} -> roll count d sides.
# FIRE is intentionally absent: standing on fire is a SINGLE damage source — it
# (re)applies the "burning" condition (see _ignite / _apply_surface_tick), and the
# per-turn 1d4 fire damage comes from the burning tick in advance_turn.
const TICK_DAMAGE: Dictionary = {
	Type.ELECTRIFIED_WATER: {"count": 1, "sides": 4},
	Type.CLOUD_OF_DAGGERS:  {"count": 4, "sides": 4},
}

# Semi-transparent tile tint for visual rendering
const TINT: Dictionary = {
	Type.FIRE:              Color(1.0, 0.3, 0.0, 0.45),
	Type.ICE:               Color(0.5, 0.8, 1.0, 0.45),
	Type.WATER:             Color(0.2, 0.5, 1.0, 0.40),
	Type.ELECTRIFIED_WATER: Color(0.8, 0.9, 0.2, 0.50),
	Type.ACID:              Color(0.3, 0.9, 0.1, 0.45),
	Type.POISON:            Color(0.6, 0.2, 0.8, 0.40),
	Type.STEAM:             Color(0.9, 0.9, 0.9, 0.30),
	Type.CLOUD_OF_DAGGERS:  Color(0.45, 0.05, 0.80, 0.70),
}
