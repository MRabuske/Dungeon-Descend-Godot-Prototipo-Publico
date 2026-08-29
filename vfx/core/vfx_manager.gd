class_name VFXManager
extends Node

# ======================================================
# Singleton central de VFX.
# Autoload em project.godot:
#   VFXManager="*res://vfx/core/vfx_manager.gd"
# ======================================================

const POOL_PREALLOC := 3

# ──────────────────────────────────────────────────────
# Mapa de efeitos registrados.
# Efeitos procedurais já funcionam — sem spritesheet.
# Para adicionar asset real: crie a .tscn e registre aqui.
# ──────────────────────────────────────────────────────
const EFFECT_SCENES: Dictionary = {
	VFXEvent.Type.SLASH_LIGHT:  preload("res://vfx/effects/slash/slash_light.tscn"),
	VFXEvent.Type.IMPACT_LIGHT: preload("res://vfx/effects/impact/impact_light.tscn"),
	VFXEvent.Type.IMPACT_CRIT:  preload("res://vfx/effects/impact/impact_crit.tscn"),
}

var _pools:      Dictionary = {}
var _vfx_parent: Node = null

func _ready() -> void:
	# Espera um frame para a árvore estar pronta
	await get_tree().process_frame
	_setup_vfx_parent()

func _setup_vfx_parent() -> void:
	# Sempre cria um CanvasLayer top-level, nunca filho de nó com transform
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "VFXCanvasLayer"
	canvas_layer.layer = 100
	# top_level = true no CanvasLayer não existe, mas ele já é independente
	get_tree().root.add_child(canvas_layer)
	_vfx_parent = canvas_layer
	print("VFXManager: CanvasLayer criado como filho de root")

# ──────────────────────────────────────────────────────
# PUBLIC
# pos : posição global (world space)
# dir : rotação em radianos
# ──────────────────────────────────────────────────────
func spawn(type: VFXEvent.Type, pos: Vector2, dir: float = 0.0) -> VFXEffectBase:
	if not EFFECT_SCENES.has(type):
		return null

	if not _vfx_parent:
		_setup_vfx_parent()

	var effect := _get_from_pool(type)
	if effect == null:
		return null
	
	if effect.get_parent() != _vfx_parent:
		if effect.get_parent():
			effect.get_parent().remove_child(effect)
		_vfx_parent.add_child(effect)

	effect.position = pos
	effect.rotation = dir
	effect.restart()
	
	return effect

func _warmup_pool(type: int) -> void:
	if not _pools.has(type):
		_pools[type] = []
	for _i in POOL_PREALLOC:
		var inst := _instantiate(type)
		if inst:
			_pools[type].append(inst)

func _get_from_pool(type: VFXEvent.Type) -> VFXEffectBase:
	if not _pools.has(type):
		_pools[type] = []
		
	var pool: Array = _pools[type]
	
	# Loop backwards so we can safely remove dead instances while iterating
	for i in range(pool.size() - 1, -1, -1):
		if not is_instance_valid(pool[i]):
			pool.remove_at(i)
		
	for effect in pool:
		if is_instance_valid(effect) and not effect.is_active():
			return effect
	
	# Cria um novo
	var inst := _instantiate(type)
	if inst:
		pool.append(inst)
	return inst

func _instantiate(type: int) -> VFXEffectBase:
	if not EFFECT_SCENES.has(type):
		return null
	
	if not _vfx_parent:
		_setup_vfx_parent()
	
	var inst := (EFFECT_SCENES[type] as PackedScene).instantiate() as VFXEffectBase
	if _vfx_parent:
		_vfx_parent.add_child(inst)
	inst.visible = false
	return inst
