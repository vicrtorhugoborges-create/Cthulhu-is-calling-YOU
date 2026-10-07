class_name TestCase
extends Node
## Base dos testes: asserts simples que acumulam mensagens de erro.

var errors: PackedStringArray = []


func check(condition: bool, message := "condição falsa") -> void:
	if not condition:
		errors.append(message)


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		errors.append("%s esperado %s, veio %s" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance := 0.001, message := "") -> void:
	if absf(actual - expected) > tolerance:
		errors.append("%s esperado %.4f ± %.4f, veio %.4f" % [message, expected, tolerance, actual])


## Todos os arquivos com extensão `ext` dentro de `dir` (recursivo).
static func files_in(dir: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(files_in(dir.path_join(sub), ext))
	return out
