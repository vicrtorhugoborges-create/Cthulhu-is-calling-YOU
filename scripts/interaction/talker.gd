class_name Talker
extends Interactable
## Personagem que fala: cada interação toca o próximo bloco de falas.

signal conversation_finished

## Cada item é uma lista de ids separados por vírgula (um bloco por interação).
@export var blocks: PackedStringArray = []
## Fala repetida depois que os blocos acabam.
@export var repeat_line := ""

var _index := 0


func _ready() -> void:
	if hint_id == "":
		hint_id = "talk"


func _on_interact(_by: Player) -> void:
	if Narration.is_speaking() and _index > 0:
		return
	if _index < blocks.size():
		for id in blocks[_index].split(",", false):
			Narration.say(id.strip_edges())
		_index += 1
		if _index == blocks.size():
			conversation_finished.emit()
	elif repeat_line != "":
		Narration.say(repeat_line)


func has_finished() -> bool:
	return _index >= blocks.size()
