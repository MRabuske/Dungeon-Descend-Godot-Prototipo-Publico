class_name TerrainTile 
extends RefCounted

# Tipos de chão
enum GroundType {
	NORMAL,
	MUD,
	STONE,
	GRASS,
	ELEVATED,
	VOID,
}

# Tipos de objeto
enum ObjectType {
	NONE,
	STATUE,
	OBSTACLE,
	CHEST,
	COVER
}

# Tipos de efeito
enum EffectType {
	NONE,
	TRAP_INACTIVE,   # Armadilha não ativada (invisível)
	TRAP_ACTIVE,     # Armadilha ativada (visível)
	POISON_CLOUD,
	HEAL_ZONE
}

var ground: int = GroundType.NORMAL
var object: int = ObjectType.NONE
var effect: int = EffectType.NONE
var object_data: Dictionary = {}

# Converte do tipo antigo (MapGenerator.TileType) para o novo sistema

static func from_old_type(old_type: int) -> TerrainTile:
	var new_tile := TerrainTile.new()
	
	match old_type:
		MapGenerator.TileType.VOID:
			new_tile.ground = GroundType.VOID 
		MapGenerator.TileType.NORMAL:
			new_tile.ground = GroundType.NORMAL
		MapGenerator.TileType.MUD:
			new_tile.ground = GroundType.MUD
		MapGenerator.TileType.ELEVATED:
			new_tile.ground = GroundType.ELEVATED 
		MapGenerator.TileType.COVER:
			new_tile.ground = GroundType.NORMAL
			new_tile.object = ObjectType.COVER
		MapGenerator.TileType.OBSTACLE:
			new_tile.ground = GroundType.NORMAL
			new_tile.object = ObjectType.OBSTACLE
		MapGenerator.TileType.TRAP:
			new_tile.ground = GroundType.NORMAL
			new_tile.effect = EffectType.TRAP_INACTIVE  # ← começa inativa
	
	return new_tile
	
func is_void() -> bool:
	return ground == GroundType.VOID
