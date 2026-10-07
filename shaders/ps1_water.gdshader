// Mar parado, cinza-chumbo / verde-limo, com ondulação lenta por vértice.
shader_type spatial;
render_mode vertex_lighting, cull_back, diffuse_lambert, specular_disabled;

#include "res://shaders/ps1_common.gdshaderinc"

uniform vec4 water_color : source_color = vec4(0.05, 0.08, 0.07, 1.0);
uniform vec4 crest_color : source_color = vec4(0.12, 0.16, 0.13, 1.0);
uniform float wave_height = 0.15;
uniform float wave_scale = 0.12;

varying float v_fog;
varying float v_crest;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = floor(TIME * 12.0) / 12.0;
	float wave = sin(world_pos.x * wave_scale + t * 0.7) * cos(world_pos.z * wave_scale * 0.8 + t * 0.5);
	VERTEX.y += wave * wave_height;
	v_crest = wave * 0.5 + 0.5;
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION = ps1_snap(PROJECTION_MATRIX * view_pos);
	v_fog = ps1_fog_factor(length(view_pos.xyz));
}

void fragment() {
	vec3 col = mix(water_color.rgb, crest_color.rgb, v_crest);
	ALBEDO = col * (1.0 - v_fog);
	EMISSION = ps1_fog_color.rgb * v_fog;
}
