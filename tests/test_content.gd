extends TestCase
## Integridade do conteúdo: falas, diário, dicas, documentos e sons citados
## nas cenas e nos scripts precisam existir; falas respeitam as duas frases.

const NARRATION_PROPS := ["narration", "narration_once", "narration_after", "refused_narration", "locked_narration",
	"notice_narration", "detail_narration", "enter_narration", "narration_after_first", "repeat_line"]
const DIARY_PROPS := ["diary_id", "pickup_diary", "detail_diary", "notice_diary", "complete_diary_id"]


func _all_text_files() -> Dictionary:
	var out := {}
	for ext in [".gd", ".tscn", ".tres"]:
		for path in files_in("res://", ext):
			if path.begins_with("res://tests/") or path.begins_with("res://addons/"):
				continue
			out[path] = FileAccess.get_file_as_string(path)
	return out


func _matches(pattern: String, text: String, group := 1) -> PackedStringArray:
	var re := RegEx.new()
	re.compile(pattern)
	var out: PackedStringArray = []
	for m in re.search_all(text):
		out.append(m.get_string(group))
	return out


func test_count_sentences_helper() -> void:
	check_eq(NarrationLines.count_sentences("Uma frase."), 1)
	check_eq(NarrationLines.count_sentences("Uma. Duas!"), 2)
	check_eq(NarrationLines.count_sentences("Riscado: \"H. A. Wilcox, 1º de março\"."), 1)
	check_eq(NarrationLines.count_sentences("…Cthulhu fhtagn…"), 1)
	check_eq(NarrationLines.count_sentences("Sem ponto final"), 1)


func test_lines_have_at_most_two_sentences() -> void:
	for id in NarrationLines.LINES:
		var line: Dictionary = NarrationLines.LINES[id]
		for variant in ["calm", "uneasy", "shaken"]:
			if line.has(variant):
				var text: String = line[variant]
				check(not text.strip_edges().is_empty(), "%s/%s vazia" % [id, variant])
				var n := NarrationLines.count_sentences(text)
				check(n <= 2, "%s/%s tem %d frases (máximo 2)" % [id, variant, n])


func test_referenced_narration_exists() -> void:
	var files := _all_text_files()
	for path in files:
		var text: String = files[path]
		var ids: PackedStringArray = []
		for prop in NARRATION_PROPS:
			ids.append_array(_matches("(?m)^%s = \"([^\"]+)\"" % prop, text))
		ids.append_array(_matches("Narration\\.say(?:_once)?\\(\"([^\"]+)\"", text))
		for block in _matches("(?m)^blocks = PackedStringArray\\((.*)\\)$", text):
			for item in _matches("\"([^\"]+)\"", block):
				for id in item.split(",", false):
					ids.append(id.strip_edges())
		for id in ids:
			check(NarrationLines.has_line(id), "fala inexistente \"%s\" em %s" % [id, path])


func test_referenced_diary_entries_exist() -> void:
	var files := _all_text_files()
	for path in files:
		var text: String = files[path]
		var ids: PackedStringArray = []
		for prop in DIARY_PROPS:
			ids.append_array(_matches("(?m)^%s = \"([^\"]+)\"" % prop, text))
		ids.append_array(_matches("(?:add|complete)_diary_entry\\(\"([^\"]+)\"", text))
		for id in ids:
			check(DiaryEntries.TEXT.has(id), "entrada de diário inexistente \"%s\" em %s" % [id, path])


func test_referenced_hints_exist() -> void:
	var files := _all_text_files()
	for path in files:
		var text: String = files[path]
		var ids := _matches("(?m)^hint_id = \"([^\"]+)\"", text)
		ids.append_array(_matches("show_hint\\(\"([^\"]+)\"", text))
		ids.append_array(_matches("hint_id = \"([^\"]+)\"", text))
		for id in ids:
			check(Hints.TEXT.has(id), "dica inexistente \"%s\" em %s" % [id, path])


func test_referenced_sounds_exist() -> void:
	var files := _all_text_files()
	for path in files:
		var text: String = files[path]
		var names: PackedStringArray = []
		# Só nomes completos (ignora "sfx_step_" + superfície).
		names.append_array(_matches("play_sfx(?:_3d|_delayed)?\\(\"([^\"]+)\"\\s*[,)]", text))
		names.append_array(_matches("play_ui\\(\"([^\"]+)\"", text))
		names.append_array(_matches("play_music\\(\"([^\"]+)\"", text))
		names.append_array(_matches("play_ambience\\(\"[^\"]+\", \"([^\"]+)\"", text))
		for prop in ["ambience", "ambience_extra", "music", "success_sound"]:
			names.append_array(_matches("(?m)^%s = \"([^\"]+)\"" % prop, text))
		for sound in names:
			check(Audio.has_stream(sound), "som inexistente \"%s\" em %s" % [sound, path])
	check(Audio.has_stream(Audio.CHANT_STREAM), "falta o canto do culto")


func test_documents_are_complete_and_unique() -> void:
	var ids := {}
	for path in files_in("res://data/documents", ".tres"):
		var doc := load(path) as DocumentData
		check(doc != null, "não é DocumentData: %s" % path)
		if doc == null:
			continue
		check(doc.id != "" and doc.title != "", "documento sem id/título: %s" % path)
		check(doc.pages.size() > 0, "documento sem páginas: %s" % path)
		check(not ids.has(doc.id), "id de documento repetido: %s" % doc.id)
		ids[doc.id] = true
		check(doc.id == path.get_file().get_basename(), "o arquivo deveria ter o nome do id: %s" % path)
		if doc.diary_id != "":
			check(DiaryEntries.TEXT.has(doc.diary_id), "diário inexistente em %s" % path)
		if doc.narration_after != "":
			check(NarrationLines.has_line(doc.narration_after), "fala inexistente em %s" % path)


func test_no_racial_descriptors_in_text() -> void:
	# Documento de design: o culto é internacional e definido pelo que faz, nunca pela etnia.
	var banned := ["negro", "mestiço", "mulato", "esquimó", "raça", "selvagem"]
	var texts: PackedStringArray = []
	for id in NarrationLines.LINES:
		for v in NarrationLines.LINES[id].values():
			texts.append(str(v).to_lower())
	for path in files_in("res://data/documents", ".tres"):
		texts.append(FileAccess.get_file_as_string(path).to_lower())
	for t in texts:
		for word in banned:
			check(not t.contains(word), "termo a evitar \"%s\" no texto" % word)
