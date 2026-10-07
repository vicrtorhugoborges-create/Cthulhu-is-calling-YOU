// Funções e uniforms compartilhados pelos shaders de superfície no estilo PS1.
// Os valores globais ficam em project.godot ([shader_globals]) e são ajustados
// em tempo de execução por Settings (conforto) e pelo CorruptionDirector (Conhecimento).

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter;
global uniform float ps1_affine;
global uniform vec4 ps1_fog_color;
global uniform float ps1_fog_near;
global uniform float ps1_fog_far;
global uniform float world_distortion;
global uniform float corruption_flash;

// Arredonda a posição do vértice à grade da tela (tremor típico do PS1).
vec4 ps1_snap(vec4 clip) {
	if (ps1_jitter <= 0.0 || clip.w <= 0.0) {
		return clip;
	}
	vec2 grid = ps1_snap_resolution * 0.5;
	vec2 ndc = clip.xy / clip.w;
	vec2 snapped = floor(ndc * grid + 0.5) / grid;
	clip.xy = mix(ndc, snapped, clamp(ps1_jitter, 0.0, 1.0)) * clip.w;
	return clip;
}

// Neblina por vértice, como no hardware original.
float ps1_fog_factor(float view_distance) {
	return clamp((view_distance - ps1_fog_near) / max(ps1_fog_far - ps1_fog_near, 0.001), 0.0, 1.0);
}

// "Geometria errada": deslocamento lento, a 12 quadros por segundo.
vec3 ps1_distortion_offset(vec3 world_pos, float amount, float time) {
	float t = floor(time * 12.0) / 12.0;
	return vec3(
		sin(world_pos.y * 1.7 + world_pos.z * 0.3 + t * 0.9),
		sin(world_pos.x * 1.3 + world_pos.z * 0.7 + t * 0.6) * 0.5,
		cos(world_pos.y * 1.1 + world_pos.x * 0.4 + t * 0.8)
	) * 0.08 * amount;
}

// UV projetada pelo mundo (o eixo dominante da normal escolhe o plano).
vec2 ps1_world_uv(vec3 world_pos, vec3 world_normal, float density) {
	vec3 n = abs(world_normal);
	vec2 p;
	if (n.y >= n.x && n.y >= n.z) {
		p = world_pos.xz;
	} else if (n.x >= n.z) {
		p = vec2(world_pos.z, -world_pos.y);
	} else {
		p = vec2(world_pos.x, -world_pos.y);
	}
	return p * density;
}
