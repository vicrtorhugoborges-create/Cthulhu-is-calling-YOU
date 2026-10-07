extends TestCase
## O Julgamento segue o roteiro do documento de design, momento a momento,
## e a silhueta de Cthulhu nunca cabe inteira na tela.

const J := preload("res://scripts/judgment/judgment_sequence.gd")
const VIEW := Vector2i(320, 240)


func test_timeline_matches_design() -> void:
	check_eq(J.DOOR_OPEN, Vector2(0, 12), "a porta se abre:")
	check_eq(J.STEPS_SLOW.x, 6.0, "os passos começam a pesar:")
	check_eq(J.DARKNESS, Vector2(12, 22), "a escuridão escoa:")
	check_eq(J.PLAYER_STOPS, 20.0, "o jogador para:")
	check_eq(J.EMERGE, Vector2(22, 30), "ele emerge:")
	check_eq(J.GAZE, Vector2(30, 42), "o olhar:")
	check_near(J.GAZE.y - J.GAZE.x, 12.0, 0.0001, "janela do olhar (12 s):")
	check_eq(J.HEART_STOPS, 40.0, "o coração para:")
	check_eq(J.FADE, Vector2(42, 46), "a imagem escurece em 4 s:")
	check_eq(J.EVIL_SOUND, Vector2(42, 50), "som maléfico:")
	check_eq(J.SILENCE_FROM, 50.0, "silêncio total:")
	check_eq(J.END, 56.0, "duração total:")
	check(J.SILENCE_BEFORE >= 2.0 and J.SILENCE_BEFORE <= 3.0, "silêncio de 2 a 3 s antes do momento-chave")
	check_eq(J.GIANT_FPS, 12.0, "coisas gigantes a 12 quadros por segundo:")


func test_heart_slows_and_stops_at_40() -> void:
	check_eq(J.heart_bpm_at(10.0), 0.0, "sem coração antes de ele emergir:")
	check(J.heart_bpm_at(25.0) > 90.0, "coração acelerado quando ele emerge")
	check(J.heart_bpm_at(33.0) > J.heart_bpm_at(38.0), "o coração desacelera durante o olhar")
	check_eq(J.heart_bpm_at(40.0), 0.0, "o coração para aos 40 s:")
	check_eq(J.heart_bpm_at(45.0), 0.0)


func test_giant_time_is_quantized_to_12_fps() -> void:
	check_near(J.giant_time(1.0 / 24.0), 0.0)
	check_near(J.giant_time(0.09), 1.0 / 12.0)


func test_audio_lengths_match_timeline() -> void:
	var evil := Audio.get_stream("sfx_evil")
	check(evil != null, "falta sfx_evil")
	if evil:
		check_near(evil.get_length(), J.EVIL_SOUND.y - J.EVIL_SOUND.x, 0.05, "som maléfico (42–50 s):")
	var door := Audio.get_stream("sfx_door_grind")
	check(door != null, "falta sfx_door_grind")
	if door:
		check_near(door.get_length(), J.DOOR_OPEN.y - J.DOOR_OPEN.x, 0.05, "porta (0–12 s):")


func test_cthulhu_triangle_budget() -> void:
	var body := CthulhuBuilder.build_body()
	var claw := CthulhuBuilder.build_claw()
	var total := CthulhuBuilder.triangle_count(body) + 2 * CthulhuBuilder.triangle_count(claw)
	check(total <= CthulhuBuilder.MAX_TRIANGLES, "Cthulhu com %d triângulos (máximo %d)" % [total, CthulhuBuilder.MAX_TRIANGLES])
	check(total > 500, "silhueta pobre demais (%d triângulos)" % total)


func test_silhouette_never_fits_on_screen() -> void:
	# Posição da criatura lida da própria cena; jogador no platô entre z -70 e -115
	# (o gatilho fica em z -75 e ele ainda anda devagar até parar aos 20 s).
	var level := (load(Game.LEVELS["rlyeh"]) as PackedScene).instantiate()
	var creature_pos: Vector3 = (level.get_node("Creature/Cthulhu") as Node3D).position
	level.free()
	var vp := SubViewport.new()
	vp.size = VIEW
	add_child(vp)
	var cam := Camera3D.new()
	cam.far = 3000.0
	vp.add_child(cam)
	cam.make_current()
	var verts := _world_vertices(CthulhuBuilder.build_body(), Transform3D(Basis(), creature_pos))
	var head := creature_pos + CthulhuBuilder.HEAD_CENTER
	for z in [-70.0, -95.0, -115.0]:
		for fov in [60.0, 70.0, 100.0]:
			cam.fov = fov
			var eye := Vector3(0, 6.2, z)
			cam.global_position = eye
			var d := head - eye
			var yaw := atan2(-d.x, -d.z)
			var pitch := atan2(d.y, Vector2(d.x, d.z).length())
			var yaw_ext := deg_to_rad(J.gaze_yaw_extent_deg(cam, creature_pos, CthulhuBuilder.WING_HALF_SPAN))
			var pitch_ext := deg_to_rad(J.CONE_PITCH_DEG)
			for sy in [-1.0, 1.0]:
				for sp in [-1.0, 1.0]:
					cam.global_rotation = Vector3(pitch + sp * pitch_ext, yaw + sy * yaw_ext, 0)
					var r := _screen_extent(cam, verts)
					var where := "z=%.0f fov=%.0f cone(%+.0f,%+.0f)" % [z, fov, sy, sp]
					check(r.position.x < 0.0 and r.end.x > VIEW.x, "a silhueta coube na largura da tela em %s" % where)
					check(r.end.y > VIEW.y, "a base deveria sair por baixo da tela em %s" % where)
	vp.queue_free()


func _world_vertices(mesh: ArrayMesh, xf: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arr: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in arr:
			out.append(xf * v)
	return out


## Retângulo (em pixels) coberto pelos vértices à frente da câmera.
func _screen_extent(cam: Camera3D, verts: PackedVector3Array) -> Rect2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for v in verts:
		if cam.is_position_behind(v):
			continue
		var p := cam.unproject_position(v)
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return Rect2(min_p, max_p - min_p)
