extends Level
## Prólogo — Os Papéis. Aposentos de Thurston em Boston, inverno de 1926–27,
## noite, chuva. Tutorial embutido: pegar, girar, ler e anotar no diário.
## A caixa trancada só abre com a chave do chaveiro que o tio levava no bolso.
## Pico de terror: o baixo-relevo está em outro lugar da mesa quando Thurston volta.

const RELIEF_UNSEEN_SECONDS := 3.0
const RELIEF_MIN_DISTANCE := 1.2

@onready var locked_box: UseTarget = $Interactables/LockedBox
@onready var lid: Node3D = $Props/LockedBoxLid
@onready var relief: ExaminableItem = $Interactables/BasRelief
@onready var manuscript: ReadableDocument = $Interactables/Manuscript
@onready var spot_a: Marker3D = $Markers/ReliefSpotA
@onready var spot_b: Marker3D = $Markers/ReliefSpotB

var _unseen := 0.0
var _awaiting_notice := false
var _creak_timer := 14.0


func _level_ready() -> void:
	locked_box.used.connect(_on_box_used)
	relief.examine_finished.connect(_on_relief_examined)
	if GameState.has_flag("box_open"):
		_set_box_open(true)
	else:
		relief.enabled = false
		manuscript.enabled = false
	if GameState.has_flag("relief_moved"):
		relief.global_transform = spot_b.global_transform
		_awaiting_notice = not GameState.has_flag("prologo_done")
	elif GameState.has_flag("examined_relief"):
		relief.global_transform = spot_a.global_transform


func _player_ready(_player: Player, _spawn: String) -> void:
	if GameState.has_flag("said:prologo_inicio"):
		return
	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree():
		return
	Narration.say_once("prologo_inicio")
	GameState.add_diary_entry("d_organizar")
	await get_tree().create_timer(7.0).timeout
	if is_inside_tree():
		Game.show_hint("diary")


func _on_box_used() -> void:
	GameState.set_flag("box_open")
	Audio.play_sfx("sfx_box_open", -2.0)
	_set_box_open(false)
	Narration.say("prologo_caixa_aberta", true)
	GameState.complete_diary_entry("d_caixa")
	Game.checkpoint("start", "prologo:caixa")


func _set_box_open(instant: bool) -> void:
	locked_box.enabled = false
	relief.enabled = true
	manuscript.enabled = true
	var target := deg_to_rad(-105.0)
	if instant:
		lid.rotation.x = target
	else:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5)
		tw.tween_property(lid, "rotation:x", target, 1.2)


func _on_relief_examined() -> void:
	# Depois do primeiro exame, o baixo-relevo fica em pé ao lado da caixa.
	if not GameState.has_flag("relief_moved"):
		relief.global_transform = spot_a.global_transform


func _process(delta: float) -> void:
	_update_creaks(delta)
	_update_relief(delta)


func _update_relief(delta: float) -> void:
	if GameState.has_flag("prologo_done") or not is_instance_valid(Game.player):
		return
	var cam := Game.get_camera()
	var point := relief.global_position + Vector3.UP * 0.06
	if _awaiting_notice:
		if CameraUtil.is_seen(cam, point, -14.0, 5.0):
			_awaiting_notice = false
			_on_relief_noticed()
		return
	if not (GameState.has_flag("examined_relief") and GameState.has_flag("read_cthulhu_cult")):
		return
	if Game.player.state == Player.State.EXAMINE:
		return
	if CameraUtil.is_seen(cam, point, 10.0) or cam.global_position.distance_to(point) < RELIEF_MIN_DISTANCE:
		_unseen = 0.0
		return
	_unseen += delta
	if _unseen >= RELIEF_UNSEEN_SECONDS:
		relief.global_transform = spot_b.global_transform
		GameState.set_flag("relief_moved")
		_awaiting_notice = true


func _on_relief_noticed() -> void:
	await Audio.cut_to_silence(2.0)
	if not is_inside_tree():
		return
	Narration.say("prologo_relevo_mudou", true)
	Audio.set_heartbeat(100.0, -5.0)
	GameState.add_diary_entry("d_relevo_mexeu")
	GameState.add_knowledge(3.0, "prologo:relevo_mudou")
	await get_tree().create_timer(4.5).timeout
	if not is_inside_tree():
		return
	Audio.set_heartbeat(72.0, -9.0)
	Game.show_hint("close_eyes")
	await get_tree().create_timer(4.0).timeout
	if not is_inside_tree():
		return
	Audio.set_heartbeat(0.0)
	# Virada de capítulo: acorde dissonante.
	Audio.play_sfx("mus_sting", -8.0, &"Music")
	Narration.say("prologo_fim")
	GameState.complete_diary_entry("d_organizar")
	GameState.set_flag("prologo_done")
	Game.checkpoint("start", "prologo:fim")


func _update_creaks(delta: float) -> void:
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(15.0, 35.0)
		var pos := Vector3(randf_range(-2.8, 2.8), randf_range(0.2, 2.8), randf_range(-2.3, 2.3))
		Audio.play_sfx_3d("amb_creak", to_global(pos), -10.0, 12.0)
