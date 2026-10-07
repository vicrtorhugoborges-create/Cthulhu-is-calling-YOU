extends TestCase
## Todo script, cena e recurso do projeto carrega sem erro.


func test_all_scripts_load() -> void:
	for path in files_in("res://", ".gd"):
		if path.begins_with("res://addons/"):
			continue
		var res := load(path)
		check(res != null and (res as GDScript).can_instantiate(), "script não compila: %s" % path)


func test_all_scenes_load() -> void:
	for path in files_in("res://scenes", ".tscn"):
		var packed := load(path) as PackedScene
		check(packed != null and packed.can_instantiate(), "cena não carrega: %s" % path)


func test_all_resources_load() -> void:
	for dir in ["res://materials", "res://data"]:
		for path in files_in(dir, ".tres"):
			check(load(path) != null, "recurso não carrega: %s" % path)


func test_level_registry_points_to_real_scenes() -> void:
	for id in Game.LEVELS:
		check(ResourceLoader.exists(Game.LEVELS[id]), "nível %s aponta para arquivo inexistente" % id)
	for entry in Game.DEV_CHAPTERS:
		check(Game.LEVELS.has(entry[1]), "capítulo de desenvolvimento usa nível desconhecido: %s" % entry[1])
