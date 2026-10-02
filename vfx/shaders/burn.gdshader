shader_type canvas_item;
render_mode blend_mix;

uniform float burn_amount : hint_range(0.0, 2.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(25.0, 0.0, 0.0, 1.0); // Vermelho Puro HDR
uniform float edge_width : hint_range(0.0, 0.5) = 0.25; // Borda larga para espalhar as veias de fogo

uniform float noise_scale = 1.0;
uniform float speed = 3.0; // Controla a velocidade da pulsação/vento
uniform float emission_boost = 2.5;
uniform sampler2D noise_texture;

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    
    if (texture_color.a == 0.0) {
        discard;
    }

    // --- ANCORAGEM FIXA COM MOVIMENTO DE VENTO ---
    // Em vez de subtrair o TIME no eixo Y para o fogo subir, usamos sin/cos 
    // para fazer o mapa de ruído "orbitar" de forma bem sutil no próprio lugar.
    vec2 wind_offset = vec2(
        sin(TIME * speed) * 0.03,
        cos(TIME * speed * 0.8) * 0.03
    );
    
    // Aplicamos o ruído fixado no UV do objeto + o balanço do vento
    vec2 fixed_uv = UV * noise_scale + wind_offset;
    
    // Adiciona uma micro-distorção orgânica para as bordas das chamas não ficarem estáticas
    fixed_uv.x += sin(TIME * speed * 1.5 + UV.y * 10.0) * 0.01;

    // Amostra o ruído (sua textura de FastNoiseLite celular)
    float n = texture(noise_texture, fixed_uv).r;
    
    // Faz a intensidade da queima pulsar levemente ao longo do tempo (efeito brasa viva)
    float pulse = sin(TIME * speed * 2.0) * 0.05 + 0.95;
    float burn_threshold = burn_amount * pulse;
    
    // Calcula a máscara das fendas acesas
    float edge_mask = smoothstep(burn_threshold - edge_width, burn_threshold, n) - 
                      smoothstep(burn_threshold, burn_threshold + 0.02, n);
    
    vec3 final_color = texture_color.rgb;
    
    if (edge_mask > 0.0) {
        // --- CORES DE BRASA PURA (100% VERMELHO/CRIMSON) ---
        vec3 red_dark = vec3(2.5, 0.0, 0.0);       // Vermelho brasa profunda
        vec3 red_pure = edge_color.rgb;            // Vermelho vivo incandescente
        vec3 red_hot  = vec3(12.0, 0.8, 0.0);      // No máximo um laranja no miolo da rachadura
        
        // Interpolação para dar profundidade às fendas
        vec3 fire_gradient = mix(red_dark, red_pure, edge_mask);
        fire_gradient = mix(fire_gradient, red_hot, pow(edge_mask, 5.0));
        
        // Aplica o fogo sobre o sprite original
        final_color = mix(final_color, fire_gradient * emission_boost, edge_mask);
    }
    
    // --- TEXTURA DE CARVÃO QUEIMADO ---
    // Onde o fogo está ativo ou passou, o sprite fica preto/chamuscado como um tronco carbonizado
    float burn_trace = smoothstep(burn_threshold - 0.2, burn_threshold, n);
    
    // Criamos um tom cinza-escuro/preto de carvão, mantendo uma pitada minúscula do vermelho de fundo
    vec3 charcoal = texture_color.rgb * vec3(0.04, 0.01, 0.01); 
    
    final_color = mix(charcoal, final_color, burn_trace);

    COLOR = vec4(final_color, texture_color.a);
}