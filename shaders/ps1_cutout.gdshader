// Variante recortada (alpha testado) da superfície PS1: símbolos riscados,
// bordas de pano, folhagem. Sem ordenação de transparência.
shader_type spatial;
render_mode vertex_lighting, cull_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/ps1_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float alpha_cut = 0.5;
uniform bool fog_enabled = true;

varying vec3 v_affine_uv;
varying float v_fog;

void vertex() {
	UV = UV * uv_scale;
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = ps1_snap(PROJECTION_MATRIX * view_pos);
	POSITION = clip;
	v_affine_uv = vec3(UV * clip.w, clip.w);
	v_fog = fog_enabled ? ps1_fog_factor(length(view_pos.xyz)) : 0.0;
}

void fragment() {
	vec2 uv = mix(UV, v_affine_uv.xy / v_affine_uv.z, ps1_affine);
	vec4 tex = texture(albedo_texture, uv) * albedo_color;
	ALBEDO = tex.rgb * (1.0 - v_fog);
	EMISSION = ps1_fog_color.rgb * v_fog;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
