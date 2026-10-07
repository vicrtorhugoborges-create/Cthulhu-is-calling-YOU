extends Level
## Visão de Wilcox: blocos titânicos de pedra verde escorrendo limo e uma voz
## que não é voz, repetindo "Cthulhu fhtagn". Termina num corte seco de volta
## ao ateliê, quando o jogador chega ao fim da passarela ou o tempo acaba.

const MAX_SECONDS := 55.0

@onready var end_trigger: StoryTrigger = $Triggers/End

var _elapsed := 0.0
var _voice_timer := 6.0
var _ending := false


func _level_ready() -> void:
	end_trigger.triggered.connect(_end_vision)


func _player_ready(_player: Player, _spawn: String) -> void:
	GameState.add_knowledge(12.0, "visao_wilcox")
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		Narration.say("visao_inicio")


func _process(delta: float) -> void:
	if _ending or not is_instance_valid(Game.player):
		return
	_elapsed += delta
	_voice_timer -= delta
	if _voice_timer <= 0.0:
		_voice_timer = randf_range(7.0, 10.0)
		Audio.play_sfx("vox_fhtagn", -3.0, &"Voice")
		Narration.say("visao_voz")
	if _elapsed > MAX_SECONDS:
		_end_vision()


func _end_vision() -> void:
	if _ending:
		return
	_ending = true
	# Corte seco: sem escurecer.
	Game.load_level("atelie", "after_vision", 0.0)
