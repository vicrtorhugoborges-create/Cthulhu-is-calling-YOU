class_name CameraTiltZone
extends Area3D
## "Rampas que parecem subir mas descem": enquanto o jogador está dentro,
## a câmera inclina como se subisse, e o horizonte não fica reto.

@export var pitch_offset_deg := 9.0
@export var roll_deg := 4.0
@export var blend_time := 2.0
@export var narration_once := ""

var _tween: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body is Player:
		_blend(body, pitch_offset_deg, roll_deg)
		if narration_once != "":
			Narration.say_once(narration_once)


func _on_exit(body: Node3D) -> void:
	if body is Player:
		_blend(body, 0.0, 0.0)


func _blend(player: Player, pitch: float, roll: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(player, "pitch_offset_deg", pitch, blend_time)
	_tween.tween_property(player, "_extra_roll_deg", roll, blend_time)
