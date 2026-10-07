// Pós-processo aplicado ao mundo 3D renderizado em 320x240:
// cor de 15 bits com pontilhado ordenado (Bayer 4x4), grão leve, vinheta,
// olhos fechados, escurecimento da cena e filtro opcional de TV de tubo.
shader_type canvas_item;

uniform vec2 source_size = vec2(320.0, 240.0);
uniform bool dither_enabled = true;
// 32 níveis por canal = 5 bits = cor de 15 bits.
uniform float color_levels = 32.0;
uniform float grain_amount = 0.035;
uniform float vignette_amount = 0.4;
// 0 = olhos abertos, 1 = fechados.
uniform float eyes_closed : hint_range(0.0, 1.0) = 0.0;
// Escurecimento do mundo (transições e o fim do Julgamento).
uniform float world_fade : hint_range(0.0, 1.0) = 0.0;
uniform bool crt_enabled = false;
uniform float crt_scanline = 0.3;

float bayer4(vec2 p) {
	// Matriz de Bayer 4x4, normalizada em [0, 1).
	mat4 m = mat4(
		vec4(0.0, 12.0, 3.0, 15.0),
		vec4(8.0, 4.0, 11.0, 7.0),
		vec4(2.0, 14.0, 1.0, 13.0),
		vec4(10.0, 6.0, 9.0, 5.0));
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return m[x][y] / 16.0;
}

void fragment() {
	vec2 px = floor(UV * source_size);
	vec2 uv = (px + 0.5) / source_size;
	vec3 col = texture(TEXTURE, uv).rgb;

	// Grão por pixel da imagem original, renovado a 24 quadros por segundo.
	float t = floor(TIME * 24.0);
	float n = fract(sin(dot(px + vec2(t * 17.0, t * 31.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += n * grain_amount;

	// Vinheta.
	vec2 c = uv - 0.5;
	col *= clamp(1.0 - dot(c, c) * vignette_amount * 2.0, 0.0, 1.0);

	// Olhos fechados: pálpebras descem e sobem, sobra um vermelho-escuro de sangue.
	if (eyes_closed > 0.0) {
		float open_h = 0.5 * (1.0 - eyes_closed);
		float lid = smoothstep(open_h - 0.06, open_h, abs(c.y));
		float luma = dot(col, vec3(0.3, 0.59, 0.11));
		vec3 through_lid = vec3(0.05, 0.005, 0.005) * (0.4 + luma);
		col = mix(col * (1.0 - eyes_closed * 0.7), through_lid, max(lid, eyes_closed * eyes_closed));
	}

	col *= 1.0 - world_fade;

	if (dither_enabled) {
		float levels = max(color_levels - 1.0, 1.0);
		float threshold = bayer4(px) - 0.5;
		col = floor(col * levels + 0.5 + threshold) / levels;
	}

	if (crt_enabled) {
		float row = fract(UV.y * source_size.y);
		col *= 1.0 - crt_scanline * pow(abs(row - 0.5) * 2.0, 2.0);
		float m = mod(FRAGCOORD.x, 3.0);
		vec3 mask = m < 1.0 ? vec3(1.0, 0.82, 0.82) : (m < 2.0 ? vec3(0.82, 1.0, 0.82) : vec3(0.82, 0.82, 1.0));
		col *= mask * 1.12;
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
