shader_type canvas_item;

// Névoa preta ANIMADA com "janela crescente": tudo acima de `reveal_y` (a partir
// do topo) está descoberto (transparente); abaixo permanece coberto. Duas camadas
// de ruído rolando em direções/velocidades diferentes dão turbulência (fumaça
// densa / fogo sombrio), e um brilho de brasa percorre a borda que recua.
//
// reveal_y: fração vertical (0..1) já descoberta a partir do topo.
//   0.0 = quase tudo encoberto · 1.0 = mapa inteiro limpo.
uniform sampler2D noise_tex : repeat_enable;
uniform float reveal_y : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.13;
uniform float noise_scale = 3.0;
uniform float fog_alpha : hint_range(0.0, 1.0) = 1.0;

// Animação
uniform float anim_speed = 0.05;                 // velocidade do deslocamento
uniform float boundary_wobble : hint_range(0.0, 0.1) = 0.025;  // ondular da fronteira
uniform vec4 ember_color : source_color = vec4(0.55, 0.14, 0.05, 1.0); // brasa sombria
uniform float ember_strength : hint_range(0.0, 2.0) = 0.9;

void fragment() {
	// Duas amostras de ruído rolando em sentidos opostos => turbulência viva.
	vec2 uv1 = UV * noise_scale + vec2(TIME * anim_speed, TIME * anim_speed * 0.6);
	vec2 uv2 = UV * noise_scale * 1.7 - vec2(TIME * anim_speed * 0.8, TIME * anim_speed * 1.3);
	float n1 = texture(noise_tex, uv1).r;
	float n2 = texture(noise_tex, uv2).r;
	float n = mix(n1, n2, 0.5);

	// Fronteira irregular que ondula com o tempo (a névoa "respira").
	float wobble = (n - 0.5) * edge_softness + sin(TIME * 0.8 + UV.x * 12.0) * boundary_wobble;
	float boundary = reveal_y + wobble;

	// alpha 0 acima da fronteira (descoberto), 1 abaixo (névoa).
	float a = smoothstep(boundary - 0.03, boundary + 0.03, UV.y);

	// Densidade interna varia com o ruído, mas com piso alto => névoa bem densa
	// (quase opaca) em vez de preto translúcido.
	float density = mix(0.94, 1.0, n);

	// Brilho de brasa logo abaixo da borda que recua.
	float edge_band = 1.0 - smoothstep(0.0, 0.07, abs(UV.y - boundary));
	vec3 col = ember_color.rgb * edge_band * ember_strength * (n * 0.6 + 0.4);

	COLOR = vec4(col, a * density * fog_alpha);
}
