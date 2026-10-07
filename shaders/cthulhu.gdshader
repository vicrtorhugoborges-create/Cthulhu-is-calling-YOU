// Silhueta de Cthulhu no Julgamento. Regras do documento de design:
// base nítida, tronco leitoso, cabeça entre nuvens (perspectiva atmosférica),
// brilho úmido verde só nas partes mais próximas, movimento a 12 quadros por segundo.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://shaders/ps1_common.gdshaderinc"

uniform vec4 body_color : source_color = vec4(0.015, 0.03, 0.02, 1.0);
uniform vec4 haze_color : source_color = vec4(0.07, 0.1, 0.08, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.2, 0.42, 0.16, 1.0);
// Olhos (canal azul da cor do vértice): dois pontos pálidos que encaram Thurston.
uniform vec4 eye_color : source_color = vec4(0.7, 0.8, 0.42, 1.0);
// Alturas (em metros, no espaço do mundo) onde a névoa começa e onde cobre quase tudo.
uniform float haze_start = 40.0;
uniform float haze_full = 420.0;
uniform float haze_max : hint_range(0.0, 1.0) = 0.45;
// Distância até onde o brilho úmido aparece.
uniform float sheen_distance = 180.0;
// Tentáculos balançando (peso no canal vermelho da cor do vértice).
uniform float sway_amount = 6.0;
// Gesto lento de um tentáculo (peso no canal verde), 0..1, controlado pelo roteiro.
uniform float gesture = 0.0;
uniform vec3 gesture_offset = vec3(0.0, 60.0, 45.0);
// Escurece a criatura junto com a cena final.
uniform float darkness : hint_range(0.0, 1.0) = 0.0;

varying float v_height;
varying float v_dist;
varying vec3 v_normal_view;
varying vec3 v_view_dir;

void vertex() {
	float t = floor(TIME * 12.0) / 12.0;
	float w = COLOR.r;
	VERTEX.x += sin(t * 0.35 + VERTEX.y * 0.02 + VERTEX.z * 0.01) * sway_amount * w;
	VERTEX.z += cos(t * 0.27 + VERTEX.y * 0.015) * sway_amount * 0.6 * w;
	VERTEX += gesture_offset * gesture * COLOR.g;

	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_height = world_pos.y;
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_dist = length(view_pos.xyz);
	v_normal_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_view_dir = normalize(-view_pos.xyz);
	POSITION = ps1_snap(PROJECTION_MATRIX * view_pos);
}

void fragment() {
	float haze = smoothstep(haze_start, haze_full, v_height) * haze_max;
	vec3 col = mix(body_color.rgb, haze_color.rgb, haze);
	float near = 1.0 - smoothstep(sheen_distance * 0.4, sheen_distance, v_dist);
	float rim = pow(1.0 - abs(dot(normalize(v_normal_view), normalize(v_view_dir))), 2.0);
	col += sheen_color.rgb * near * (0.25 + rim * 0.75) * 0.6;
	col = mix(col, eye_color.rgb, COLOR.b);
	ALBEDO = col * (1.0 - darkness);
}
