extends Node
## Fachada do jogo: troca de níveis, documentos, exame de objetos e fluxo
## (título, novo jogo, continuar). Quem faz o trabalho é a cena principal
## (scenes/main/main.tscn), que se registra aqui ao iniciar.
##
## Rodar um nível direto pelo editor (F6) também funciona: o nível é
## recarregado dentro da cena principal, com jogador, UI e pós-processo.

signal level_loaded(level: Node)

const MAIN_SCENE := "res://scenes/main/main.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"

const LEVELS := {
	"teste": "res://scenes/levels/ps1_test_room.tscn",
	"prologo": "res://scenes/levels/prologue_thurston_room.tscn",
	"atelie": "res://scenes/levels/ch1_wilcox_atelier.tscn",
	"visao_wilcox": "res://scenes/levels/vision_wilcox.tscn",
	"rlyeh": "res://scenes/levels/finale_rlyeh.tscn",
}

## [rótulo, nível, ponto de entrada] — menu de capítulos (só em builds de desenvolvimento).
const DEV_CHAPTERS := [
	["Sala de teste PS1", "teste", ""],
	["Prólogo — Os Papéis", "prologo", ""],
	["I — O ateliê de Wilcox", "atelie", ""],
	["I — Visão de Wilcox", "visao_wilcox", ""],
	["Ato final — R'lyeh", "rlyeh", ""],
	["O Julgamento (no platô)", "rlyeh", "plateau"],
]

var main: Node
var player: Player
var level: Node
var current_level_path := ""
var current_spawn := ""
## Nível pedido antes da cena principal existir (F6 no editor, testes).
var pending_level := ""
var pending_spawn := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bootstrap.call_deferred()


func _bootstrap() -> void:
	var scene := get_tree().current_scene
	if scene is Level and main == null:
		pending_level = scene.scene_file_path
		get_tree().change_scene_to_file(MAIN_SCENE)


func register_main(node: Node) -> void:
	main = node


static func resolve_level(id_or_path: String) -> String:
	return LEVELS.get(id_or_path, id_or_path)


func load_level(id_or_path: String, spawn := "", fade := 1.0) -> void:
	if main == null:
		push_error("Cena principal ausente; não dá para carregar %s." % id_or_path)
		return
	await main.load_level(resolve_level(id_or_path), spawn, fade)


func on_level_loaded(new_level: Node, new_player: Player, path: String, spawn: String) -> void:
	level = new_level
	player = new_player
	current_level_path = path
	current_spawn = spawn
	level_loaded.emit(new_level)


func new_game() -> void:
	GameState.reset()
	SaveSystem.clear_save()
	await main.start_new_game()


func continue_game() -> bool:
	var data := SaveSystem.read_save()
	if data.is_empty():
		return false
	GameState.from_dict(data["state"])
	await load_level(data["level"], data.get("spawn", ""), 1.5)
	return true


func return_to_title() -> void:
	await main.return_to_title()


## Salvamento automático. `spawn` é o marcador onde o jogador reaparece.
func checkpoint(spawn: String, checkpoint_id := "") -> void:
	current_spawn = spawn
	SaveSystem.checkpoint(current_level_path, spawn, checkpoint_id)


func get_camera() -> Camera3D:
	return player.camera if is_instance_valid(player) else null


func open_document(doc: DocumentData, on_closed := Callable()) -> void:
	main.ui.open_document(doc, on_closed)


func show_hint(hint_id: String) -> void:
	if main:
		main.ui.show_hint(hint_id)


## Escurece só o mundo 3D, com o pontilhado do PS1 (legendas continuam visíveis).
func fade_world(target: float, time: float) -> void:
	if main:
		await main.fade_world(target, time)


## Escurece a tela inteira, por cima de tudo.
func fade_screen(target: float, time: float) -> void:
	if main:
		await main.fade_screen(target, time)


## Texto centralizado sobre tela preta (primeira fala, avisos, linha final).
## A tela fica preta por baixo do texto, então pode ser chamado depois de fade_screen(1).
func show_card(text: String, hold := 4.0, fade := 1.0) -> void:
	if main == null:
		return
	main.ui.cover_black()
	await main.fade_screen(0.0, 0.01)
	await main.ui.show_card(text, hold, fade)
