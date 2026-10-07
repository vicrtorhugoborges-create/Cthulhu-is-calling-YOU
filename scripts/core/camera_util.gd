class_name CameraUtil
extends RefCounted
## Testes de visão usados pelas coisas que só se mexem quando ninguém olha.


## Ângulo (graus) entre o centro da tela e um ponto.
static func angle_to(camera: Camera3D, point: Vector3) -> float:
	var forward := -camera.global_basis.z
	var to_point := (point - camera.global_position).normalized()
	return rad_to_deg(forward.angle_to(to_point))


## Metade da diagonal do campo de visão (graus), com folga.
static func half_view_angle(camera: Camera3D, margin_deg := 8.0) -> float:
	var size := camera.get_viewport().get_visible_rect().size if camera.get_viewport() else Vector2(4, 3)
	var aspect := size.x / maxf(size.y, 1.0)
	var half_v := deg_to_rad(camera.fov * 0.5)
	var half_h := atan(tan(half_v) * aspect)
	var half_diag := atan(sqrt(tan(half_v) * tan(half_v) + tan(half_h) * tan(half_h)))
	return rad_to_deg(half_diag) + margin_deg


## O ponto está na tela (com folga) e não está escondido atrás de uma parede?
static func is_seen(camera: Camera3D, point: Vector3, margin_deg := 8.0, max_distance := 40.0, check_occlusion := true) -> bool:
	if camera == null or not camera.is_inside_tree():
		return false
	if camera.global_position.distance_to(point) > max_distance:
		return false
	if angle_to(camera, point) > half_view_angle(camera, margin_deg):
		return false
	if check_occlusion:
		var space := camera.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit["position"].distance_to(point) > 0.6:
			return false
	return true
