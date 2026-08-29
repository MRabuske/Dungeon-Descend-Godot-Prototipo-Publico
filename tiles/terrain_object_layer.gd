class_name TerrainObjectLayer
extends Node2D

var battle_area: Control = null

func _ready() -> void:
	y_sort_enabled = true
	z_index = 1

func sync_transform(pivot: Vector2, zoom: float, pan_offset: Vector2) -> void:
	var _translate := pivot * (1.0 - zoom) + pan_offset
	transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, _translate)

func add_object_sprite(sprite: Sprite2D) -> void:
	add_child(sprite)

func clear_all() -> void:
	for child in get_children():
		child.queue_free()

	# ======================================================
# NOVO MÉTODO: Criar objetos do terreno a partir do state
# ======================================================
func create_objects_from_state(
	state: BattleState,
	offset: Vector2,
	get_texture_callback: Callable,
	get_size_callback: Callable
) -> void:
	clear_all()
	
	const TILE_HALF_H := 18.0  # mesmo valor do BattleArea
	
	for row in range(state.grid_rows):
		for col in range(state.grid_cols):
			var tile: TerrainTile = state.tile_data_map[col][row]
			if tile == null or tile.object == TerrainTile.ObjectType.NONE:
				continue
			
			var texture: Texture2D = get_texture_callback.call(tile.object)
			if not texture:
				continue
			
			# Calcula posição (mesma lógica que estava no BattleArea)
			var center := _tile_center(col, row, offset)  # 👈 REMOVIDO TILE_HALF_H daqui
			var obj_size: Vector2 = get_size_callback.call(tile.object)
			
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			
			var texture_size := texture.get_size()
			sprite.scale = Vector2(obj_size.x / texture_size.x, obj_size.y / texture_size.y)
			
			var base_y := center.y + (TILE_HALF_H * 0.5)
			var draw_pos := Vector2(
				center.x - (obj_size.x / 2.0),
				base_y - obj_size.y
			)
			
			match tile.object:
				TerrainTile.ObjectType.STATUE:
					draw_pos.y -= 8
				TerrainTile.ObjectType.OBSTACLE:
					draw_pos.y -= 4
				TerrainTile.ObjectType.COVER:
					draw_pos.y += 2
			
			sprite.position = draw_pos
			
			var depth := col + row
			if tile.object == TerrainTile.ObjectType.COVER:
				depth += 1
			sprite.z_index = depth
			add_object_sprite(sprite)

# ======================================================
# HELPER: Calcula centro do tile isométrico
# ======================================================
func _tile_center(col: int, row: int, offset: Vector2) -> Vector2:
	const TILE_HALF_W := 36.0  # mesmo valor do BattleArea
	const TILE_HALF_H := 18.0  # 👈 ADICIONADO AQUI
	return offset + Vector2((col - row) * TILE_HALF_W, (col + row) * TILE_HALF_H) + Vector2(0.0, TILE_HALF_H)

func sync_positions(state: BattleState, offset: Vector2) -> void:
	const TILE_HALF_H := 18.0
	var children := get_children()
	var child_idx := 0
	
	for row in range(state.grid_rows):
		for col in range(state.grid_cols):
			var tile: TerrainTile = state.tile_data_map[col][row]
			if tile == null or tile.object == TerrainTile.ObjectType.NONE:
				continue
			
			if child_idx >= children.size():
				continue
			
			var sprite := children[child_idx] as Sprite2D
			if not sprite:
				child_idx += 1
				continue
			
			var center := _tile_center(col, row, offset)
			var obj_size: Vector2
			match tile.object:
				TerrainTile.ObjectType.STATUE:
					obj_size = Vector2(48, 64)
				TerrainTile.ObjectType.OBSTACLE:
					obj_size = Vector2(56, 64)
				TerrainTile.ObjectType.COVER:
					obj_size = Vector2(56, 38)
				_:
					obj_size = Vector2(48, 48)
			
			var texture_size := sprite.texture.get_size()
			sprite.scale = Vector2(obj_size.x / texture_size.x, obj_size.y / texture_size.y)
			
			var base_y := center.y + (TILE_HALF_H * 0.5)
			var draw_pos := Vector2(
				center.x - (obj_size.x / 2.0),
				base_y - obj_size.y
			)
			
			match tile.object:
				TerrainTile.ObjectType.STATUE:
					draw_pos.y -= 8
				TerrainTile.ObjectType.OBSTACLE:
					draw_pos.y -= 4
				TerrainTile.ObjectType.COVER:
					draw_pos.y += 2
			
			sprite.position = draw_pos
			sprite.z_index = col + row + (1 if tile.object == TerrainTile.ObjectType.COVER else 0)
			
			child_idx += 1
