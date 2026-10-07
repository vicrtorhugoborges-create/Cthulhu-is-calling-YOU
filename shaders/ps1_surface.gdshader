// Superfície opaca no estilo PlayStation 1:
// vértices presos à grade da tela, textura afim sem filtragem,
// iluminação por vértice e neblina por vértice.
shader_type spatial;
render_mode vertex_lighting, cull_back, diffuse_lambert, specular_disabled;

#include "res://shaders/ps1_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
// Repetições da textura por metro. 0 = usa a UV da malha.
uniform float world_uv_density = 0.0;
// Textura que pisca no lugar da normal quando o Conhecimento passa de 50 (tijolo vira escama).
uniform sampler2D corrupt_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform bool has_corrupt_texture = false;
// 0 = imune à "geometria errada"; 1 = resposta normal.
uniform float distortion_response = 1.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool fog_enabled = true;

varying vec3 v_affine_uv;
varying float v_fog;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);

	float d = world_distortion * distortion_response;
	if (d > 0.0) {
		vec3 offs = ps1_distortion_offset(world_pos, d, TIME);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * offs;
	}

	vec2 uv = UV;
	if (world_uv_density > 0.0) {
		uv = ps1_world_uv(world_pos, world_normal, world_uv_density);
	}
	uv = uv * uv_scale + uv_offset;
	UV = uv;

	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = ps1_snap(PROJECTION_MATRIX * view_pos);
	POSITION = clip;

	v_affine_uv = vec3(uv * clip.w, clip.w);
	v_fog = fog_enabled ? ps1_fog_factor(length(view_pos.xyz)) : 0.0;
}

void fragment() {
	vec2 affine_uv = v_affine_uv.xy / v_affine_uv.z;
	vec2 uv = mix(UV, affine_uv, ps1_affine);
	vec4 tex = texture(albedo_texture, uv);
	if (has_corrupt_texture && corruption_flash > 0.5) {
		tex = texture(corrupt_texture, uv);
	}
	ALBEDO = tex.rgb * albedo_color.rgb * (1.0 - v_fog);
	EMISSION = ps1_fog_color.rgb * v_fog + emission_color.rgb * (1.0 - v_fog);
}
