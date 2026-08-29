class_name MapGenerator
extends RefCounted

enum TileType { VOID, NORMAL, MUD, ELEVATED, COVER, TRAP, OBSTACLE }

class MapData:
	var grid_cols: int
	var grid_rows: int
	var tile_data_map: Array
	var hero_spawns: Array[Vector2i]
	var enemy_spawns: Array[Vector2i]

func generate(seed_val: int = -1) -> MapData:
	if seed_val >= 0:
		seed(seed_val)

	var attempts := 0
	while attempts < 100:
		attempts += 1
		var result := _try_generate()
		if result != null:
			return result

	# Fallback: flat 12x7 NORMAL map with fixed spawns
	return _fallback_map()

func _try_generate() -> MapData:
	var cols: int = randi_range(12, 18)
	var rows: int = randi_range(8, 11)

	# Step 1: fill with NORMAL
	var tmap: Array = []
	for col in range(cols):
		var column: Array[int] = []
		for row in range(rows):
			column.append(TileType.NORMAL)
		tmap.append(column)

	# Step 2: border erosion
	for col in range(cols):
		for row in range(rows):
			var border_dist := mini(mini(col, cols - 1 - col), mini(row, rows - 1 - row))
			if border_dist == 0 and randf() < 0.40:
				tmap[col][row] = TileType.VOID
			elif border_dist == 1 and randf() < 0.15:
				tmap[col][row] = TileType.VOID

	# Step 3: connectivity — flood-fill from center
	var cx := int(cols / 2.0)
	var cy := int(rows / 2.0)
	if tmap[cx][cy] == TileType.VOID:
		# Find nearest non-VOID tile
		var found := false
		for r in range(1, maxi(cols, rows)):
			for dc in range(-r, r + 1):
				for dr in range(-r, r + 1):
					var tc := cx + dc
					var _tr := cy + dr
					if tc >= 0 and tc < cols and _tr >= 0 and _tr < rows:
						if tmap[tc][_tr] != TileType.VOID:
							cx = tc
							cy = _tr
							found = true
							break
				if found:
					break
			if found:
				break

	var reachable := _flood_fill(tmap, cols, rows, Vector2i(cx, cy))
	for col in range(cols):
		for row in range(rows):
			if tmap[col][row] != TileType.VOID:
				if not (Vector2i(col, row) in reachable):
					tmap[col][row] = TileType.VOID

	# Step 4: terrain distribution on non-VOID tiles
	var weights := [
		[TileType.NORMAL,   55],
		[TileType.MUD,      12],
		[TileType.ELEVATED, 12],
		[TileType.COVER,    10],
		[TileType.TRAP,      6],
		[TileType.OBSTACLE,  5],
	]
	for col in range(cols):
		for row in range(rows):
			if tmap[col][row] == TileType.VOID:
				continue
			tmap[col][row] = _weighted_pick(weights)

	# Step 4b: re-check connectivity — OBSTACLEs placed in Step 4 can sever the map
	var cxb := int(cols / 2.0)
	var cyb := int(rows / 2.0)
	if tmap[cxb][cyb] == TileType.VOID or tmap[cxb][cyb] == TileType.OBSTACLE:
		var found2 := false
		for rr in range(1, maxi(cols, rows)):
			for dcc in range(-rr, rr + 1):
				for drr in range(-rr, rr + 1):
					var tc := cxb + dcc
					var trr := cyb + drr
					if tc >= 0 and tc < cols and trr >= 0 and trr < rows:
						if tmap[tc][trr] != TileType.VOID and tmap[tc][trr] != TileType.OBSTACLE:
							cxb = tc
							cyb = trr
							found2 = true
							break
				if found2:
					break
			if found2:
				break
		if not found2:
			return null
	var reachable2 := _flood_fill(tmap, cols, rows, Vector2i(cxb, cyb))
	for col in range(cols):
		for row in range(rows):
			if tmap[col][row] != TileType.VOID and tmap[col][row] != TileType.OBSTACLE:
				if not (Vector2i(col, row) in reachable2):
					tmap[col][row] = TileType.VOID

	# Step 5: spawn clusters
	var split := int(cols / 2.0)
	var sdirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var left_tiles: Array[Vector2i] = []
	var right_tiles: Array[Vector2i] = []
	for col in range(cols):
		for row in range(rows):
			if tmap[col][row] == TileType.VOID or tmap[col][row] == TileType.OBSTACLE:
				continue
			var free_neighbors := 0
			for d in sdirs:
				var nx: int = col + d.x
				var ny: int = row + d.y
				if nx >= 0 and nx < cols and ny >= 0 and ny < rows:
					if tmap[nx][ny] != TileType.VOID and tmap[nx][ny] != TileType.OBSTACLE:
						free_neighbors += 1
			if free_neighbors < 2:
				continue
			if col < split:
				left_tiles.append(Vector2i(col, row))
			else:
				right_tiles.append(Vector2i(col, row))

	if left_tiles.size() < 4 or right_tiles.size() < 4:
		return null  # degenerate — retry

	var left_spawns := _pick_cluster(left_tiles, 4)
	var right_spawns := _pick_cluster(right_tiles, 4)

	var tile_data_map: Array[Array] = []
	for col in range(cols):
		var column: Array[TerrainTile] = []
		for row in range(rows):
			var old_type: int = tmap[col][row]
			var new_tile := TerrainTile.from_old_type(old_type)
			column.append(new_tile)
		tile_data_map.append(column)

	var md := MapData.new()
	md.grid_cols = cols
	md.grid_rows = rows
	md.tile_data_map = tile_data_map
	if randi() % 2 == 0:
		md.hero_spawns = left_spawns
		md.enemy_spawns = right_spawns
	else:
		md.hero_spawns = right_spawns
		md.enemy_spawns = left_spawns
	return md

func _flood_fill(tmap: Array, cols: int, rows: int, start: Vector2i) -> Array:
	var visited := {}
	var frontier: Array[Vector2i] = [start]
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if visited.has(cur):
			continue
		visited[cur] = true
		for d in dirs:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= cols or nxt.y < 0 or nxt.y >= rows:
				continue
			var nt: int = tmap[nxt.x][nxt.y]
			if nt == TileType.VOID or nt == TileType.OBSTACLE:
				continue
			if not visited.has(nxt):
				frontier.append(nxt)
	return visited.keys()

func _weighted_pick(weights: Array) -> int:
	var total := 0
	for entry in weights:
		total += entry[1]
	var roll := randi_range(0, total - 1)
	var acc := 0
	for entry in weights:
		acc += entry[1]
		if roll < acc:
			return entry[0]
	return weights[-1][0]

func _pick_cluster(tiles: Array[Vector2i], count: int) -> Array[Vector2i]:
	if tiles.size() <= count:
		var copy: Array[Vector2i] = []
		copy.assign(tiles)
		return copy
	var result: Array[Vector2i] = []
	result.append(tiles[randi() % tiles.size()])
	while result.size() < count:
		var best_tile: Vector2i = tiles[0]
		var best_min_dist := -1
		for t in tiles:
			var min_dist := 999999
			for s in result:
				var d := absi(t.x - s.x) + absi(t.y - s.y)
				if d < min_dist:
					min_dist = d
			if min_dist > best_min_dist:
				best_min_dist = min_dist
				best_tile = t
		result.append(best_tile)
	return result

func _fallback_map() -> MapData:
	var md := MapData.new()
	md.grid_cols = 12
	md.grid_rows = 7
	var tile_data_map: Array[Array] = []
	for col in range(12):
		var column: Array[TerrainTile] = []
		for row in range(7):
			var tile := TerrainTile.new()
			tile.ground = TerrainTile.GroundType.NORMAL
			column.append(tile)
		tile_data_map.append(column)
	md.tile_data_map = tile_data_map
	md.hero_spawns  = [Vector2i(2,3), Vector2i(1,1), Vector2i(1,5), Vector2i(3,4)]
	md.enemy_spawns = [Vector2i(9,1), Vector2i(10,3), Vector2i(9,5), Vector2i(11,3)]
	return md
