extends Node
## Salvamento automático em pontos fixos, sem save manual (para manter a tensão).

signal saved(checkpoint_id: String)

const PATH := "user://autosave.json"
const VERSION := 1

## Caminho atual (os testes trocam para não apagar o save do jogador).
var path := PATH


func checkpoint(level_path: String, spawn: String, checkpoint_id := "") -> void:
	var data := {
		"version": VERSION,
		"level": level_path,
		"spawn": spawn,
		"checkpoint": checkpoint_id,
		"state": GameState.to_dict(),
		"time": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar (%s)." % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	saved.emit(checkpoint_id)


func has_save() -> bool:
	return not read_save().is_empty()


func read_save() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != VERSION:
		return {}
	if not ResourceLoader.exists(str(data.get("level", ""))):
		return {}
	return data


func clear_save() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
