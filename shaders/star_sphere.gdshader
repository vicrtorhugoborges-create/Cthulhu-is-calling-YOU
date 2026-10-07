// Céu noturno numa esfera vista por dentro. Em R'lyeh as estrelas
// estão "fora do lugar": vagueiam devagar e trocam de brilho.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

uniform vec4 sky_color : source_color = vec4(0.01, 0.015, 0.02, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.04, 0.07, 0.05, 1.0);
uniform vec4 star_color : source_color = vec4(0.85, 0.95, 0.8, 1.0);
uniform float star_density : hint_range(0.0, 1.0) = 0.08;
uniform float wander = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;
uniform float grid = 180.0;
// Contraluz verde-doente atrás de Cthulhu (direção a partir do centro da esfera).
uniform vec3 glow_dir = vec3(0.0, 0.84, -0.54);
uniform vec4 glow_color : source_color = vec4(0.3, 0.55, 0.22, 1.0);
uniform float glow_power = 3.0;
uniform float glow_intensity = 0.0;

varying vec3 v_dir;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float elev = d.y;
	vec3 col = mix(horizon_color.rgb, sky_color.rgb, smoothstep(-0.05, 0.35, elev));
	float az = atan(d.z, d.x) / 6.28318 + 0.5;
	float t = floor(TIME * 2.0) / 2.0;
	vec2 cell_uv = vec2(az * grid * 2.0, elev * grid);
	vec2 cell = floor(cell_uv);
	float h = hash(cell);
	if (h < star_density && elev > -0.02) {
		vec2 jitter = vec2(hash(cell + 3.1), hash(cell + 7.7));
		jitter += wander * 0.35 * vec2(sin(t * 0.3 + h * 40.0), cos(t * 0.23 + h * 31.0));
		vec2 local = fract(cell_uv) - jitter;
		float s = step(length(local), 0.22);
		float twinkle = 0.6 + 0.4 * sin(t * (1.0 + h * 3.0) + h * 90.0);
		col += star_color.rgb * s * twinkle * (1.0 - dim);
	}
	col *= 1.0 - dim * 0.85;
	float g = pow(max(dot(d, normalize(glow_dir)), 0.0), glow_power);
	col += glow_color.rgb * g * glow_intensity;
	ALBEDO = col;
}
