class_name LevelExit
extends Interactable
## Porta ou passagem para outro nível. Pode exigir uma flag.

@export_file("*.tscn") var target_level := ""
@export var target_spawn := ""
@export var required_flag := ""
@export var refused_narration := ""
@export var fade_time := 1.5


func _ready() -> void:
	if hint_id == "":
		hint_id = "door"


func _on_interact(_by: Player) -> void:
	if required_flag != "" and not GameState.has_flag(required_flag):
		if refused_narration != "":
			Narration.say(refused_narration, true)
		return
	enabled = false
	Game.load_level(target_level, target_spawn, fade_time)
