class_name SpriteProvider
extends RefCounted

# ======================================================
# Provedor de sprites para combatentes e objetos
# Centraliza a lógica de busca/criação de texturas
# ======================================================

const PLAYER_COLORS := [
	Color(0.30, 0.55, 1.00),
	Color(0.30, 0.85, 0.50),
	Color(0.95, 0.75, 0.20),
	Color(0.85, 0.40, 0.90),
]

const DOT_RADIUS := 10.0

# ======================================================
# MÉTODOS PÚBLICOS
# ======================================================

static func get_combatant_sprite(combatant: Dictionary, _idx: int) -> Texture2D:
	if combatant["is_player"]:
		var player_idx = _find_player_index(combatant["name"])
		if player_idx >= 0:
			var player_data = BattleState.PLAYERS[player_idx]
			var sprite = player_data.get("sprite")
			if sprite and sprite is Texture2D:
				return sprite
	else:
		var enemy_type = combatant.get("type", "")
		if BattleState.ALL_ENEMIES.has(enemy_type):
			var enemy_data = BattleState.ALL_ENEMIES[enemy_type]
			if enemy_data.has_method("to_combat_dict"):
				var enemy_dict = enemy_data.to_combat_dict()
				var sprite = enemy_dict.get("sprite")
				if sprite and sprite is Texture2D:
					return sprite
			elif enemy_data.has("sprite"):
				return enemy_data.sprite
	return null

static func create_fallback_texture(combatant: Dictionary, _idx: int) -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var color: Color
	if combatant["is_player"]:
		var player_idx = _find_player_index(combatant["name"])
		color = PLAYER_COLORS[player_idx] if player_idx >= 0 else PLAYER_COLORS[0]
	else:
		color = Color(0.85, 0.25, 0.25)
	
	var center := Vector2i(32, 32)
	for x in range(64):
		for y in range(64):
			var dist := Vector2(x - center.x, y - center.y).length()
			if dist <= DOT_RADIUS:
				image.set_pixel(x, y, color)
			elif dist <= DOT_RADIUS + 2.0:
				image.set_pixel(x, y, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9))
	
	return ImageTexture.create_from_image(image)

# ======================================================
# HELPERS PRIVADOS
# ======================================================

static func _find_player_index(player_name: String) -> int:
	for i in range(BattleState.PLAYERS.size()):
		if BattleState.PLAYERS[i]["name"] == player_name:
			return i
	return -1
