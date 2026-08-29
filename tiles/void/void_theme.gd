# VoidTheme.gd
class_name VoidTheme
extends RefCounted

enum ThemeType {
	ABYSS,      # Padrão (roxo/escuro)
	FIRE,       # Lava/fogo
	FOREST,     # Floresta/veneno
	ICE,        # Gelo/neve
	HOLY,       # Luz sagrada
	POISON,     # Veneno/pântano
}

static func get_colors(theme: int) -> Dictionary:
	match theme:
		ThemeType.FIRE:
			return {
				"primary": Color(0.9, 0.2, 0.1),
				"secondary": Color(0.8, 0.4, 0.1),
				"tertiary": Color(0.5, 0.1, 0.0),
				"particle": Color(0.95, 0.4, 0.1),
			}
		ThemeType.FOREST:
			return {
				"primary": Color(0.2, 0.5, 0.2),
				"secondary": Color(0.3, 0.7, 0.3),
				"tertiary": Color(0.1, 0.3, 0.1),
				"particle": Color(0.4, 0.9, 0.4),
			}
		ThemeType.ICE:
			return {
				"primary": Color(0.2, 0.6, 0.9),
				"secondary": Color(0.4, 0.8, 1.0),
				"tertiary": Color(0.1, 0.3, 0.5),
				"particle": Color(0.5, 0.9, 1.0),
			}
		ThemeType.HOLY:
			return {
				"primary": Color(1.0, 0.9, 0.5),
				"secondary": Color(1.0, 0.8, 0.6),
				"tertiary": Color(0.8, 0.6, 0.3),
				"particle": Color(1.0, 0.9, 0.4),
			}
		ThemeType.POISON:
			return {
				"primary": Color(0.4, 0.8, 0.3),
				"secondary": Color(0.6, 0.9, 0.4),
				"tertiary": Color(0.2, 0.5, 0.1),
				"particle": Color(0.5, 0.9, 0.2),
			}
		_:  # ABYSS
			return {
				"primary": Color(0.3, 0.2, 0.5),
				"secondary": Color(0.5, 0.3, 0.7),
				"tertiary": Color(0.2, 0.1, 0.3),
				"particle": Color(0.6, 0.4, 0.9),
			}

static func get_texture_path(theme: int) -> String:
	var base_path = "res://assets/textures/terrain/void/"
	match theme:
		ThemeType.FIRE: return base_path + "void_fire.png"
		ThemeType.FOREST: return base_path + "void_forest.png"
		ThemeType.ICE: return base_path + "void_ice.png"
		ThemeType.HOLY: return base_path + "void_holy.png"
		ThemeType.POISON: return base_path + "void_poison.png"
		_: return base_path + "void_abyss.png"
