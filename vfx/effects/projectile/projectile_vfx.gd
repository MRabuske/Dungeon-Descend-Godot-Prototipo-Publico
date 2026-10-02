class_name ProjectileVFX
extends VFXEffectBase

@export var sprite_frames: SpriteFrames    # frames da animação
@export var animation_name: String = "default"  # nome da animação

var _anim: AnimatedSprite2D

func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.centered = true
	add_child(_anim)

func _on_restart() -> void:
	print("ImpactFireVFX restart, sprite_frames: ", sprite_frames != null)
	if sprite_frames and sprite_frames.has_animation(animation_name):
		_anim.sprite_frames = sprite_frames
		_anim.play(animation_name)
		# Calcula duração da animação
		var fps := sprite_frames.get_animation_speed(animation_name)
		var frame_count := sprite_frames.get_frame_count(animation_name)
		var duration := float(frame_count) / fps if fps > 0 else 1.0
		# Espera a animação terminar e finaliza
		var timer := get_tree().create_timer(duration)
		await timer.timeout
		if is_instance_valid(self) and is_inside_tree():
			_finish()
	else:
		_finish()
