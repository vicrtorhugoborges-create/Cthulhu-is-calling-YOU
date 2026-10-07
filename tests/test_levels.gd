extends TestCase
## Cada nível monta (blocos cinza, estátuas, criatura), tem pontos de entrada
## válidos e interagíveis bem configurados.


func _instantiate(path: String) -> Node:
	var level := (load(path) as PackedScene).instantiate()
	return level


func test_levels_build_and_have_spawns() -> void:
	for id in Game.LEVELS:
		var level := _instantiate(Game.LEVELS[id])
		check(level is Level, "%s não é um Level" % id)
		add_child(level)
		await get_tree().process_frame
		var spawns := _spawns(level)
		check(not spawns.is_empty(), "%s sem ponto de entrada (Marker3D no grupo spawn)" % id)
		check(spawns.has("start"), "%s sem ponto de entrada \"start\"" % id)
		var boxes := 0
		for n in _all(level):
			if n is GrayBox:
				boxes += 1
				check(n.get_child_count(true) >= 2, "%s: bloco %s sem malha/colisão" % [id, n.name])
		check(boxes > 0, "%s sem geometria" % id)
		level.queue_free()
		await get_tree().process_frame


func test_spawns_referenced_exist() -> void:
	var needed := [["rlyeh", "plateau"], ["atelie", "after_vision"], ["atelie", "start"]]
	for entry in Game.DEV_CHAPTERS:
		if entry[2] != "":
			needed.append([entry[1], entry[2]])
	for pair in needed:
		var level := _instantiate(Game.LEVELS[pair[0]])
		add_child(level)
		check(_spawns(level).has(pair[1]), "%s sem ponto de entrada \"%s\"" % pair)
		level.queue_free()
	await get_tree().process_frame


func test_interactables_are_configured() -> void:
	for id in Game.LEVELS:
		var level := _instantiate(Game.LEVELS[id])
		add_child(level)
		for n in _all(level):
			if n is Area3D:
				var has_shape := n.get_children().any(func(c: Node) -> bool: return c is CollisionShape3D)
				check(has_shape, "%s: %s sem CollisionShape3D" % [id, n.name])
			if n is ReadableDocument:
				check((n as ReadableDocument).document != null, "%s: %s sem documento" % [id, n.name])
			if n is ExaminableItem:
				check((n as ExaminableItem).visual != null, "%s: %s sem visual" % [id, n.name])
			if n is LevelExit:
				check(ResourceLoader.exists((n as LevelExit).target_level), "%s: saída %s aponta para nível inexistente" % [id, n.name])
			if n is ShiftyObject:
				check((n as ShiftyObject).target != null, "%s: %s sem alvo" % [id, n.name])
		level.queue_free()
	await get_tree().process_frame


func test_judgment_nodes_are_wired() -> void:
	var level := _instantiate(Game.LEVELS["rlyeh"])
	add_child(level)
	var j := level.get_node("Judgment") as JudgmentSequence
	check(j != null, "falta o nó Judgment")
	if j:
		for prop in ["door", "claw_left", "claw_right", "cthulhu", "sky", "darkness"]:
			check(j.get(prop) != null, "Judgment.%s não ligado" % prop)
		check(j.cthulhu.mesh != null, "a malha de Cthulhu deveria ser gerada")
		check(not j.cthulhu.visible, "Cthulhu não pode aparecer antes do Julgamento")
	level.queue_free()
	await get_tree().process_frame


func _spawns(level: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for n in _all(level):
		if n is Marker3D and n.is_in_group(&"spawn"):
			out.append(n.name)
	return out


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out
