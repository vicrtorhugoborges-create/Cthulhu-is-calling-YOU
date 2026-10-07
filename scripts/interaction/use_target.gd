class_name UseTarget
extends Interactable
## Algo que precisa de uma condição (flag) para funcionar: caixa trancada, porta.

signal used
signal refused

@export var required_flag := ""
@export var locked_narration := ""
@export var success_sound := ""


func _on_interact(_by: Player) -> void:
	if required_flag != "" and not GameState.has_flag(required_flag):
		if locked_narration != "":
			Narration.say(locked_narration, true)
		refused.emit()
		return
	if success_sound != "":
		Audio.play_sfx(success_sound)
	used.emit()
