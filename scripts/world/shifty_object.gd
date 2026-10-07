class_name ShiftyObject
extends Node
## Faz um objeto mudar de pose ou de lugar quando o jogador não está olhando
## (quadros e esculturas mudam fora da vista a partir de Conhecimento 26).
## Nada se mexe enquanto os olhos estão fechados: fechar os olhos é refúgio.

signal shifted(count: int)
## O jogador olhou de novo para o objeto depois que ele mudou.
signal noticed

@export var target: Node3D
## Propriedade inteira a ciclar no alvo (ex.: Statue.pose). Vazio = não muda pose.
@export var pose_property := "pose"
@export var pose_count := 3
## Marcadores alternativos de posição (opcional): o alvo pula entre eles.
@export var positions: Array[Node3D] = []
## Faixa mínima de Conhecimento (1 = 26–50).
@export_range(0, 3) var min_tier := 1
@export var required_flag := ""
@export var unseen_seconds := 2.5
@export_range(0.0, 1.0) var chance := 0.6
## -1 = sem limite.
@export var max_shifts := -1
@export var notice_narration := ""
@export var notice_diary := ""
## Altura do ponto testado (centro visual do objeto).
@export var look_height := 0.9

var _unseen := 0.0
var _shifts := 0
var _awaiting_notice := false
var _check_timer := 0.0
var _position_index := 0


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	var step := 0.2 - _check_timer
	_check_timer = 0.2
	if target == null or not _active():
		_unseen = 0.0
		return
	var cam := Game.get_camera()
	if cam == null:
		return
	var seen := CameraUtil.is_seen(cam, target.global_position + Vector3.UP * look_height)
	if seen:
		_unseen = 0.0
		if _awaiting_notice:
			_awaiting_notice = false
			noticed.emit()
			if notice_narration != "":
				Narration.say_once(notice_narration)
			if notice_diary != "":
				GameState.add_diary_entry(notice_diary)
		return
	if GameState.eyes_closed:
		return
	_unseen += step
	if _unseen >= unseen_seconds:
		_unseen = 0.0
		if randf() < chance:
			shift()


func _active() -> bool:
	if max_shifts >= 0 and _shifts >= max_shifts:
		return false
	if required_flag != "" and not GameState.has_flag(required_flag):
		return false
	return GameState.get_tier() >= min_tier


func shift() -> void:
	if pose_property != "" and pose_property in target:
		var current: int = target.get(pose_property)
		target.set(pose_property, (current + 1 + randi() % maxi(pose_count - 1, 1)) % pose_count)
	if not positions.is_empty():
		_position_index = (_position_index + 1) % positions.size()
		target.global_transform = positions[_position_index].global_transform
	_shifts += 1
	_awaiting_notice = true
	shifted.emit(_shifts)
