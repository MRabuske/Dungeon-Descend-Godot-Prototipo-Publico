// dissolve.gdshader
// Efeito de dissolução para morte de personagens.
// dissolve_amount: 0.0 = normal, 1.0 = completamente dissolvido.
// Requer uma noise_texture (PNG de ruído).
shader_type canvas_item;

uniform float     dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture   : hint_default_white;
uniform vec4      edge_color      : source_color = vec4(1.0, 0.35, 0.08, 1.0);
uniform float     edge_width      : hint_range(0.0, 0.15) = 0.06;

void fragment() {
	vec4 tex   = texture(TEXTURE, UV);
	float noise = texture(noise_texture, UV).r;

	if (tex.a < 0.01) discard;

	if (noise < dissolve_amount - edge_width) {
		// Pixel completamente dissolvido
		discard;
	} else if (noise < dissolve_amount) {
		// Borda de dissolução com glow
		float edge_t = (noise - (dissolve_amount - edge_width)) / edge_width;
		COLOR = mix(edge_color, tex, edge_t);
	} else {
		COLOR = tex;
	}
}
