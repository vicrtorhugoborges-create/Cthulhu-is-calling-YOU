class_name Level
extends Node3D
## Base de todo nível: atmosfera (neblina por vértice, ambiência, canto),
## configurações do jogador e ganchos para o roteiro do nível.
## Subclasses sobrescrevem _level_ready() e _player_ready(), não _ready().

@export var level_id := ""
@export var chapter := ""
@export_group("Atmosfera")
@export var fog_color := Color(0.05, 0.06, 0.08)
@export var fog_near := 6.0
@export var fog_far := 20.0
@export var ambience := ""
@export var ambience_db := -6.0
@export var ambience_extra := ""
@export var ambience_extra_db := -12.0
@export var music := ""
@export var music_db := -10.0
@export var chant := true
@export var drips := false
## Soma-se à "geometria errada" do Conhecimento (R'lyeh é errada por natureza).
@export_range(0.0, 1.0) var extra_distortion := 0.0
@export_group("Jogador")
@export var lantern := false
@export var camera_far := 60.0
@export var roll_wobble_deg := 0.0
@export var min_knowledge := 0.0
@export var allow_close_eyes := true
@export var enter_narration := ""
## Salva ao entrar no nível (no ponto onde o jogador nasceu).
@export var checkpoint_on_enter := true
## Abaixo desta altura (caiu no mar), o jogador volta ao último ponto salvo.
@export var kill_height := -50.0

## Ligado pela cena principal. Fora dela (F6 no editor) o nível espera ser recarregado.
var hosted := false

## Neblina em vigor (ler parâmetros globais de shader só funciona no editor).
static var fog_now := {"color": Color(0.05, 0.06, 0.08), "near": 6.0, "far": 20.0}


func _ready() -> void:
	if not hosted:
		return
	if chapter != "":
		GameState.chapter = chapter
	GameState.ensure_knowledge_at_least(min_knowledge)
	GameState.set_eyes_close_allowed(allow_close_eyes)
	apply_atmosphere()
	if ambience != "":
		Audio.play_ambience("base", ambience, ambience_db, 2.0)
	else:
		Audio.stop_ambience("base", 1.0)
	if ambience_extra != "":
		Audio.play_ambience("extra", ambience_extra, ambience_extra_db, 2.0)
	else:
		Audio.stop_ambience("extra", 1.0)
	if music != "":
		Audio.play_music(music, music_db)
	else:
		Audio.stop_music(2.0)
	if chant:
		Audio.start_chant()
	else:
		Audio.stop_chant()
	Audio.set_drips(drips)
	_level_ready()


func apply_atmosphere() -> void:
	set_fog(fog_color, fog_near, fog_far)


static func set_fog(color: Color, near: float, far: float) -> void:
	fog_now = {"color": color, "near": near, "far": far}
	RenderingServer.global_shader_parameter_set(&"ps1_fog_color", color)
	RenderingServer.global_shader_parameter_set(&"ps1_fog_near", near)
	RenderingServer.global_shader_parameter_set(&"ps1_fog_far", far)


## Chamado pela cena principal depois de posicionar o jogador.
func on_player_spawned(player: Player, spawn: String) -> void:
	player.set_lantern(lantern)
	player.camera.far = camera_far
	player.roll_wobble_deg = roll_wobble_deg
	if checkpoint_on_enter:
		Game.checkpoint(spawn, level_id + ":" + spawn)
	if enter_narration != "":
		Narration.say_once(enter_narration)
	_player_ready(player, spawn)


func _physics_process(_delta: float) -> void:
	if hosted and is_instance_valid(Game.player) and Game.player.global_position.y < kill_height:
		Game.load_level(Game.current_level_path, Game.current_spawn, 0.6)


func _level_ready() -> void:
	pass


func _player_ready(_player: Player, _spawn: String) -> void:
	pass
