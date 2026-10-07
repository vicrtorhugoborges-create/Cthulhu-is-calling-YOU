extends Level
## Sala de teste do visual PS1 e dos sistemas (passo "testar o shader PS1 numa sala
## de teste" do documento). Use F1/F2 para subir/descer o Conhecimento e ver as
## faixas de corrupção; F3 mostra os valores.

@onready var spinner: Node3D = $Props/Spinner


func _player_ready(_player: Player, _spawn: String) -> void:
	GameState.add_diary_entry("d_teste")
	Narration.say_once("teste_inicio")


func _process(delta: float) -> void:
	spinner.rotate_y(delta * 0.6)
	spinner.rotate_x(delta * 0.23)
