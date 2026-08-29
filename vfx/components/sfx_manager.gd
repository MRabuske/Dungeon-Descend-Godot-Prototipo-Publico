
extends Node

# ======================================================
# Gerencia variações de SFX com anti-repetição e pitch shift.
# Registre como autoload:
#   SFXManager="*res://vfx/components/sfx_manager.gd"
# ======================================================

# ──────────────────────────────────────────────────────
# 🔧 BANCOS DE SFX
# Adicione variações aqui conforme criar os arquivos de áudio.
# Cada banco tem 1+ variações — nunca a mesma toca duas vezes seguidas.
# ──────────────────────────────────────────────────────
const SFX_BANKS: Dictionary = {
	# Impactos
	"impact_light": [
		# preload("res://audio/sfx/impacts/hit_light_1.ogg"),
		# preload("res://audio/sfx/impacts/hit_light_2.ogg"),
		# preload("res://audio/sfx/impacts/hit_light_3.ogg"),
	],
	"impact_heavy": [
		# preload("res://audio/sfx/impacts/hit_heavy_1.ogg"),
		# preload("res://audio/sfx/impacts/hit_heavy_2.ogg"),
	],
	"impact_crit": [
		# preload("res://audio/sfx/impacts/hit_crit_1.ogg"),
		# preload("res://audio/sfx/impacts/hit_crit_2.ogg"),
	],
	# Whoosh de arma
	"whoosh_sword": [
		# preload("res://audio/sfx/movement/whoosh_1.ogg"),
		# preload("res://audio/sfx/movement/whoosh_2.ogg"),
	],
	"whoosh_magic": [
		# preload("res://audio/sfx/movement/whoosh_magic_1.ogg"),
	],
	# Passos
	"step_stone": [
		# preload("res://audio/sfx/movement/step_stone_1.ogg"),
		# preload("res://audio/sfx/movement/step_stone_2.ogg"),
	],
	# Skills
	"skill_cast": [
		# preload("res://audio/sfx/skills/cast_1.ogg"),
	],
	# Morte
	"death_hero": [
		# preload("res://audio/sfx/death/hero_death_1.ogg"),
	],
	"death_enemy": [
		preload("res://audio/sfx/death/enemy_death_1.ogg"),
		# preload("res://audio/sfx/death/enemy_death_2.ogg"),
	],
}

# ──────────────────────────────────────────────────────
# 🔧 PRESETS DE PITCH POR EVENTO
# ──────────────────────────────────────────────────────
const PITCH_NORMAL := 1.00
const PITCH_CRIT   := 1.10   # crit soa mais agudo
const PITCH_MISS   := 0.85   # miss soa mais grave e suave
const PITCH_DEATH  := 0.80   # morte soa grave

# Micro-variação aleatória para soar mais orgânico
const PITCH_VARIANCE := 0.05

# ======================================================
# VARS
# ======================================================
var _last_played: Dictionary = {}   # bank_name → último índice (anti-repetição)
var _pool: Array[AudioStreamPlayer2D] = []
const POOL_SIZE := 8

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	# Pré-aloca pool de AudioStreamPlayer2D
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		add_child(p)
		p.bus = "SFX_Combat"
		_pool.append(p)

# ======================================================
# PUBLIC — play
# bank: chave em SFX_BANKS
# pos:  posição global (para áudio 2D)
# pitch_override: se > 0 usa esse pitch, senão usa o padrão
# ======================================================
func play(bank: String, pos: Vector2 = Vector2.ZERO,
		pitch: float = PITCH_NORMAL, volume_db: float = 0.0) -> void:

	if not SFX_BANKS.has(bank):
		return
	var streams: Array = SFX_BANKS[bank]
	if streams.is_empty():
		return   # banco ainda sem assets

	var idx  := _pick_no_repeat(bank, streams.size())
	var player := _get_free_player()
	if player == null:
		return

	player.stream            = streams[idx]
	player.global_position   = pos
	player.pitch_scale       = pitch + randf_range(-PITCH_VARIANCE, PITCH_VARIANCE)
	player.volume_db         = volume_db
	player.play()

# Atalhos semânticos
func play_impact_light(pos: Vector2) -> void: play("impact_light", pos)
func play_impact_heavy(pos: Vector2) -> void: play("impact_heavy", pos)
func play_impact_crit(pos: Vector2)  -> void: play("impact_crit",  pos, PITCH_CRIT)
func play_whoosh(pos: Vector2)       -> void: play("whoosh_sword", pos)
func play_death_hero(pos: Vector2)   -> void: play("death_hero",   pos, PITCH_DEATH)
func play_death_enemy(pos: Vector2)  -> void: play("death_enemy",  pos, PITCH_DEATH)

# ======================================================
# HELPERS
# ======================================================
func _pick_no_repeat(bank: String, size: int) -> int:
	if size == 1:
		return 0
	var last: int = _last_played.get(bank, -1)
	var idx  := randi() % size
	while idx == last:
		idx = randi() % size
	_last_played[bank] = idx
	return idx

func _get_free_player() -> AudioStreamPlayer2D:
	for p: AudioStreamPlayer2D in _pool:
		if not p.playing:
			return p
	# Todos ocupados: interrompe o mais antigo
	_pool[0].stop()
	return _pool[0]
