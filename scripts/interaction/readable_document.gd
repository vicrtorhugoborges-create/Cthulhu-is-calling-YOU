class_name ReadableDocument
extends Interactable
## Documento em tela cheia: papel amarelado e fonte de máquina de escrever.
## Ao fechar, registra a leitura (Conhecimento, diário, flag) e Thurston comenta.

signal read_finished(first_time: bool)

@export var document: DocumentData


func _ready() -> void:
	if hint_id == "":
		hint_id = "read"


func _on_interact(by: Player) -> void:
	if document == null:
		push_warning("%s sem DocumentData." % name)
		return
	by.set_state(Player.State.READING)
	Audio.play_sfx("sfx_paper", -6.0)
	Game.open_document(document, _on_closed.bind(by))


func _on_closed(by: Player) -> void:
	if is_instance_valid(by):
		by.set_state(Player.State.NORMAL)
	var first_time := GameState.register_document(document)
	if first_time and document.narration_after != "":
		Narration.say(document.narration_after)
	read_finished.emit(first_time)
