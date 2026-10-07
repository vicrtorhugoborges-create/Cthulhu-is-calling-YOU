extends Level
## Ato final — O Chamado. Thurston adormece e está num barco parado nas coordenadas
## do manuscrito de Johansen, 47°9' S e 126°43' O, e R'lyeh sobe do mar.
## A subida usa espaços impossíveis (rampa que engana, corredor maior por dentro,
## horizonte que não fica reto). No topo, a porta: daí em diante, o Julgamento.

const CREDITS := "CtHlUhU iS cAlLiNg YoU\n\nbaseado em \"The Call of Cthulhu\" (1928), de H. P. Lovecraft,\nem domínio público\n\nrascunho de pré-produção"

@onready var judgment: JudgmentSequence = $Judgment
@onready var judgment_trigger: StoryTrigger = $Triggers/JudgmentTrigger


func _level_ready() -> void:
	judgment_trigger.triggered.connect(judgment.start)
	judgment.finished.connect(_on_judgment_finished)


func _player_ready(_player: Player, spawn: String) -> void:
	GameState.add_diary_entry("d_coordenadas")
	if spawn == "start":
		await get_tree().create_timer(6.0).timeout
		if is_inside_tree():
			Narration.say_once("rlyeh_coordenadas")


func _on_judgment_finished() -> void:
	SaveSystem.clear_save()
	await Game.fade_screen(1.0, 0.01)
	if Settings.end_line:
		await Game.show_card(NarrationLines.END_LINE, 4.0, 1.5)
	await Game.show_card(CREDITS, 4.0, 1.0)
	Game.return_to_title()
