extends Node
## Executor de testes sem dependências externas.
##
## Rodar (na pasta do projeto):
##   godot --headless --path . res://tests/test_runner.tscn
## Sai com código 0 se tudo passou e 1 se algo falhou.
## Cada arquivo tests/test_*.gd estende TestCase e define funções test_*().

const TEST_DIR := "res://tests/"

var _failures := 0
var _passes := 0


func _ready() -> void:
	# Espera os autoloads e a árvore assentarem.
	await get_tree().process_frame
	# Nunca mexer no save de verdade do jogador.
	SaveSystem.path = "user://test_autosave.json"
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file in files:
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_runner.gd" and file != "test_case.gd":
			await _run_file(TEST_DIR + file)
	print("")
	print("==== %d testes passaram, %d falharam ====" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _run_file(path: String) -> void:
	var script := load(path) as GDScript
	if script == null:
		_fail(path, "não carregou (erro de sintaxe?)")
		return
	var case: TestCase = script.new()
	add_child(case)
	print("-- %s" % path.get_file())
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		case.errors.clear()
		await case.call(method_name)
		if case.errors.is_empty():
			_passes += 1
			print("   ok    %s" % method_name)
		else:
			for e in case.errors:
				_fail("%s::%s" % [path.get_file(), method_name], e)
	case.queue_free()


func _fail(where: String, message: String) -> void:
	_failures += 1
	printerr("   FALHOU %s — %s" % [where, message])
