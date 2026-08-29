// hit_flash.gdshader
// Aplica via ShaderMaterial no Sprite2D do combatente.
// Controle via: material.set_shader_parameter("flash_amount", 0.0..1.0)
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4  flash_color  : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Descarta pixels totalmente transparentes
	if (tex.a < 0.01) discard;
	// Mistura a cor do flash preservando o alpha original do sprite
	COLOR = mix(tex, vec4(flash_color.rgb, tex.a), flash_amount * tex.a);
}
