shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 8.0) = 2.5;
uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.0, 1.0);
uniform bool enabled = false;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (!enabled) {
		COLOR = tex;
	} else {
		vec2 size = outline_width / vec2(textureSize(TEXTURE, 0));

		float neighbor_alpha =
			texture(TEXTURE, UV + vec2(-size.x, 0.0)).a +
			texture(TEXTURE, UV + vec2( size.x, 0.0)).a +
			texture(TEXTURE, UV + vec2(0.0, -size.y)).a +
			texture(TEXTURE, UV + vec2(0.0,  size.y)).a +

			// diagonais para outline mais suave
			texture(TEXTURE, UV + vec2(-size.x, -size.y)).a * 0.7 +
			texture(TEXTURE, UV + vec2( size.x, -size.y)).a * 0.7 +
			texture(TEXTURE, UV + vec2(-size.x,  size.y)).a * 0.7 +
			texture(TEXTURE, UV + vec2( size.x,  size.y)).a * 0.7;

		if (tex.a < 0.1 && neighbor_alpha > 0.0) {
			// Pixel transparente com vizinhos opacos → outline
			COLOR = outline_color;
		} else {
			COLOR = tex;
		}
	}
}