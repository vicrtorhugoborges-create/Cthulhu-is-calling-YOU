// Quadro sempre virado para a câmera, transparente e sem luz:
// sombras de tentáculo, nuvens, fumaça e brilhos. Opacidade controlada por script.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

#include "res://shaders/ps1_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// 0 = gira em todos os eixos; 1 = só no eixo Y (fica "em pé").
uniform bool lock_y = false;
uniform bool use_fog = true;

varying float v_fog;

void vertex() {
	mat4 mv;
	if (lock_y) {
		vec3 up = MODEL_MATRIX[1].xyz;
		vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
		vec3 right = normalize(cross(normalize(up), to_cam)) * length(MODEL_MATRIX[0].xyz);
		vec3 fwd = normalize(cross(right, up)) * length(MODEL_MATRIX[2].xyz);
		mv = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	} else {
		mv = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]);
	}
	vec4 view_pos = mv * vec4(VERTEX, 1.0);
	POSITION = ps1_snap(PROJECTION_MATRIX * view_pos);
	v_fog = use_fog ? ps1_fog_factor(length(view_pos.xyz)) : 0.0;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = mix(tex.rgb, ps1_fog_color.rgb, v_fog);
	ALPHA = tex.a * opacity * (1.0 - v_fog * 0.6);
}
