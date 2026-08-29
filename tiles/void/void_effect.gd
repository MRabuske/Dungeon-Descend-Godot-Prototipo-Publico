# VoidEffect.gd
class_name VoidEffect
extends RefCounted

var theme: int = VoidTheme.ThemeType.ABYSS
var pulse_time: float = 0.0
var y_offset: float = 4.0

func update(delta: float) -> void:
	pulse_time += delta

func draw(col: int, row: int, offset: Vector2, battle_area: BattleArea) -> void:
	var texture = _load_texture()
	var theme_colors = VoidTheme.get_colors(theme)
	
	var pulse = sin(pulse_time * 2.0) * 0.15 + 0.5
	var mist_pulse = sin(pulse_time * 1.2) * 0.15 + 0.3  # ✅ Menos intenso
	var particle_pulse = sin(pulse_time * 3.0)
	
	var center = battle_area._tile_center(col, row, offset)
	var mist_center = center + Vector2(0, y_offset + 5)
	
	# Desenha o tile base
	_draw_base_tile(col, row, offset, battle_area, texture, pulse)
	
	# Desenha névoa (mais natural)
	_draw_mist_natural(mist_center, theme_colors, mist_pulse, battle_area)
	
	# Desenha partículas
	_draw_particles(center, theme_colors, particle_pulse, battle_area)

func _load_texture() -> Texture2D:
	var path = VoidTheme.get_texture_path(theme)
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _draw_base_tile(col: int, row: int, offset: Vector2, battle_area: BattleArea, texture: Texture2D, pulse: float) -> void:
	var diamond = battle_area._tile_diamond(col, row, offset)
	var diamond_rect = battle_area._get_texture_rect_from_diamond(diamond)
	diamond_rect.position.y += y_offset
	
	if texture:
		battle_area.draw_texture_rect_region(texture, diamond_rect, Rect2(Vector2.ZERO, texture.get_size()), Color(1, 1, 1, pulse))
	else:
		var color = VoidTheme.get_colors(theme)["primary"]
		var points = diamond
		for i in range(points.size()):
			points[i].y += y_offset
		battle_area.draw_polygon(points, PackedColorArray([Color(color.r, color.g, color.b, pulse)]))

# ==========================================
# NÉVOA MAIS NATURAL (MENOS DENSA)
# ==========================================
func _draw_mist_natural(center: Vector2, colors: Dictionary, mist_pulse: float, battle_area: BattleArea) -> void:
	var mist_width := 28.0   # Ligeiramente maior
	var mist_height := 18.0  # Ligeiramente maior
	var mist_angle := pulse_time * 0.3  # Rotação mais lenta
	
	# Camada única com opacidade reduzida (em vez de 3 camadas sobrepostas)
	var base_opacity := mist_pulse * 0.25  # Opacidade mais baixa
	
	# Elipse principal (mais suave)
	_draw_soft_ellipse(battle_area, center, mist_width, mist_height, mist_angle, Color(colors["primary"].r, colors["primary"].g, colors["primary"].b, base_opacity))
	
	# Pequenas nuvens irregulares ao redor (em vez de camadas concêntricas)
	for i in range(5):
		var offset_angle := (pulse_time * 0.5 + i * 1.2) * PI
		var cloud_dist_x := cos(offset_angle) * (mist_width * 0.6)
		var cloud_dist_y := sin(offset_angle) * (mist_height * 0.4)
		var cloud_center := center + Vector2(cloud_dist_x, cloud_dist_y - 4)
		var cloud_size := 8.0 + sin(pulse_time * 2.0 + i) * 3.0
		var cloud_opacity := mist_pulse * 0.15
		
		_draw_soft_circle(battle_area, cloud_center, cloud_size, Color(colors["secondary"].r, colors["secondary"].g, colors["secondary"].b, cloud_opacity))

func _draw_particles(center: Vector2, colors: Dictionary, particle_pulse: float, battle_area: BattleArea) -> void:
	for i in range(4):
		var angle := (pulse_time * 1.5 + i * 1.57) * PI
		var radius := fmod(pulse_time * 5.0, 18.0)
		var px := center.x + cos(angle) * (radius * 0.5)
		var py := center.y + sin(angle) * (radius * 0.3) - (radius * 0.7) + y_offset
		var particle_size := 2.0 if particle_pulse > 0 else 1.5
		var particle_color := Color(colors["particle"].r, colors["particle"].g, colors["particle"].b, 0.4 - radius * 0.015)
		battle_area.draw_circle(Vector2(px, py), particle_size, particle_color)

# ==========================================
# ELIPSE SUAVE (SEM BORDAS DURAS)
# ==========================================
func _draw_soft_ellipse(battle_area: BattleArea, center: Vector2, width: float, height: float, angle: float, color: Color) -> void:
	var segments := 24
	var points := PackedVector2Array()
	var cos_ang := cos(angle)
	var sin_ang := sin(angle)
	
	for i in range(segments + 1):
		var t := i * PI * 2.0 / segments
		var x := cos(t) * width
		var y := sin(t) * height
		var rotated_x := x * cos_ang - y * sin_ang
		var rotated_y := x * sin_ang + y * cos_ang
		points.append(center + Vector2(rotated_x, rotated_y))
	
	battle_area.draw_polygon(points, PackedColorArray([color]))

# ==========================================
# CÍRCULO SUAVE (SEM BORDAS DURAS)
# ==========================================
func _draw_soft_circle(battle_area: BattleArea, center: Vector2, radius: float, color: Color) -> void:
	var segments := 16
	var points := PackedVector2Array()
	
	for i in range(segments + 1):
		var angle := i * PI * 2.0 / segments
		var x := center.x + cos(angle) * radius
		var y := center.y + sin(angle) * radius
		points.append(Vector2(x, y))
	
	battle_area.draw_polygon(points, PackedColorArray([color]))
