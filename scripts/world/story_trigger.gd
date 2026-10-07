class_name StoryTrigger
extends Area3D
## Volume que dispara um momento da história quando o jogador entra:
## silêncio antes, fala, diário, flag, Conhecimento e/ou salvamento automático.

signal triggered

@export var once := true
@export var required_flag := ""
## Não dispara se esta flag já estiver ligada.
@export var blocked_by_flag := ""
@export_range(0.0, 3.0, 0.1) var silence_before := 0.0
@export var narration := ""
@export var diary_id := ""
@export var complete_diary_id := ""
@export var sets_flag := ""
@export_range(0.0, 20.0, 0.5) var knowledge := 0.0
## Ponto de reaparecimento salvo ao disparar (vazio = não salva).
@export var checkpoint_spawn := ""

var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	if (once and _fired) or not can_fire():
		return
	fire()


func can_fire() -> bool:
	if required_flag != "" and not GameState.has_flag(required_flag):
		return false
	if blocked_by_flag != "" and GameState.has_flag(blocked_by_flag):
		return false
	return true


func fire() -> void:
	_fired = true
	if silence_before > 0.0:
		await Audio.cut_to_silence(silence_before)
	if narration != "":
		Narration.say(narration)
	if diary_id != "":
		GameState.add_diary_entry(diary_id)
	if complete_diary_id != "":
		GameState.complete_diary_entry(complete_diary_id)
	if sets_flag != "":
		GameState.set_flag(sets_flag)
	if knowledge > 0.0:
		GameState.add_knowledge(knowledge, "trigger:" + str(get_path()))
	if checkpoint_spawn != "":
		Game.checkpoint(checkpoint_spawn, name)
	triggered.emit()
