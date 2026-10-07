class_name ImpossibleCorridor
extends Area3D
## "Corredores maiores por dentro do que por fora": ao entrar neste volume,
## o jogador é devolvido sem emenda `offset` metros para trás, `loops` vezes.
## Funciona se o corredor for feito de trechos idênticos e a neblina
## esconder o fim (veja finale_rlyeh.tscn).

signal looped(count: int)
signal released

@export var offset := Vector3(0, 0, 10)
@export var loops := 2
@export var narration_after_first := ""

var _count := 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player or _count >= loops:
		return
	_count += 1
	_teleport.call_deferred(body)


func _teleport(body: Player) -> void:
	body.global_position += offset
	looped.emit(_count)
	if _count == 1 and narration_after_first != "":
		Narration.say_once(narration_after_first)
	if _count >= loops:
		released.emit()
