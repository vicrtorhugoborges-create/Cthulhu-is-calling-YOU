extends Level
## Capítulo I — O Horror em Argila: o ateliê de Wilcox no Edifício Fleur-de-Lys,
## Thomas Street, Providence. Wilcox mostra uma estátua mórbida e diz que a geometria
## do lugar sonhado está "toda errada". Esculturas mudam de pose quando o jogador
## não olha. Tocar a peça leva à Visão de Wilcox (primeira olhada na cidade ciclópica).
##
## Rascunho: a ladeira do porto e o mural de recortes ficam para a fatia vertical.

const END_CARD := "Fim da fatia vertical.\n\nCapítulo II — O Relato do Inspetor Legrasse\nainda será construído."

@onready var wilcox_talk: Talker = $Interactables/WilcoxTalk
@onready var morbid_piece: UseTarget = $Interactables/MorbidPiece
@onready var exit_door: UseTarget = $Interactables/ExitDoor
@onready var shifty_root: Node = $Shifty

var _creak_timer := 10.0


func _level_ready() -> void:
	wilcox_talk.interacted.connect(_on_talk)
	wilcox_talk.conversation_finished.connect(_on_conversation_finished)
	morbid_piece.used.connect(_on_piece_used)
	exit_door.used.connect(_on_exit_used)
	for child in shifty_root.get_children():
		if child is ShiftyObject:
			(child as ShiftyObject).noticed.connect(_on_statue_noticed)
	morbid_piece.enabled = GameState.has_flag("wilcox_talked") and not GameState.has_flag("vision_done")
	if GameState.has_flag("wilcox_talked"):
		wilcox_talk.blocks = PackedStringArray()
	if GameState.has_flag("vision_done"):
		wilcox_talk.repeat_line = "wilcox_depois_visao"


func _player_ready(player: Player, spawn: String) -> void:
	if spawn == "after_vision":
		_wake_up(player)
	else:
		GameState.complete_diary_entry("d_culto")
		GameState.add_diary_entry("d_wilcox_falar")


func _on_talk(_by: Player) -> void:
	GameState.complete_diary_entry("d_wilcox_falar")


func _on_conversation_finished() -> void:
	GameState.set_flag("wilcox_talked")
	GameState.add_diary_entry("d_wilcox_peca")
	GameState.add_knowledge(4.0, "atelie:conversa")
	morbid_piece.enabled = true
	Game.checkpoint("start", "atelie:conversa")


func _on_statue_noticed() -> void:
	GameState.add_knowledge(2.0, "atelie:estatua")


func _on_piece_used() -> void:
	morbid_piece.enabled = false
	Narration.say("atelie_peca", true)
	Game.player.set_control(Player.ControlMode.NONE)
	Audio.set_heartbeat(92.0, -6.0)
	await get_tree().create_timer(3.2).timeout
	if not is_inside_tree():
		return
	Audio.set_heartbeat(0.0)
	await Audio.cut_to_silence(2.5)
	if is_inside_tree():
		Game.load_level("visao_wilcox", "", 0.0)


func _wake_up(player: Player) -> void:
	morbid_piece.enabled = false
	player.set_control(Player.ControlMode.NONE)
	player.set_view(player.get_yaw(), deg_to_rad(-60.0))
	player.crouching = true
	Audio.set_heartbeat(124.0, -3.0)
	if not GameState.has_flag("vision_done"):
		GameState.set_flag("vision_done")
		GameState.add_diary_entry("d_visao")
		GameState.complete_diary_entry("d_wilcox_peca")
		GameState.add_diary_entry("d_legrasse")
	wilcox_talk.blocks = PackedStringArray()
	wilcox_talk.repeat_line = "wilcox_depois_visao"
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	Narration.say("visao_despertar")
	Audio.play_sfx("mus_sting", -6.0, &"Music")
	var tw := create_tween()
	tw.tween_method(func(p: float) -> void: player.set_view(player.get_yaw(), p), deg_to_rad(-60.0), 0.0, 3.0)
	await tw.finished
	if not is_inside_tree():
		return
	player.set_control(Player.ControlMode.FULL)
	Audio.set_heartbeat(80.0, -8.0)
	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return
	Audio.set_heartbeat(0.0)
	Narration.say("wilcox_depois_visao")
	Game.checkpoint("after_vision", "atelie:visao")


func _on_exit_used() -> void:
	exit_door.enabled = false
	Game.player.set_control(Player.ControlMode.NONE)
	Narration.say("atelie_fim", true)
	await Narration.queue_emptied
	if not is_inside_tree():
		return
	await Game.fade_screen(1.0, 1.5)
	await Game.show_card(END_CARD, 4.0, 1.0)
	Game.return_to_title()


func _process(delta: float) -> void:
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(12.0, 30.0)
		var pos := Vector3(randf_range(-4.0, 4.0), randf_range(0.5, 3.5), randf_range(-3.5, 3.5))
		Audio.play_sfx_3d("amb_creak", to_global(pos), -12.0, 14.0)
