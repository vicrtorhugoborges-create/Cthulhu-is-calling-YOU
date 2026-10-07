class_name FogZone
extends Area3D
## Muda a neblina enquanto o jogador está dentro (corredores, interiores, platôs).
## Zonas podem se encostar: vale a última em que o jogador entrou; ao sair de
## todas, volta a neblina do nível.

@export var fog_color := Color(0.02, 0.04, 0.03)
@export var fog_near := 2.0
@export var fog_far := 10.0
@export var blend_time := 1.5

static var _active: Array[FogZone] = []
static var _tween: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	tree_exiting.connect(func() -> void: _active.erase(self))


func _on_enter(body: Node3D) -> void:
	if not body is Player:
		return
	_active.erase(self)
	_active.append(self)
	_blend(fog_color, fog_near, fog_far, blend_time)


func _on_exit(body: Node3D) -> void:
	if not body is Player:
		return
	_active.erase(self)
	if not _active.is_empty():
		var top: FogZone = _active[-1]
		_blend(top.fog_color, top.fog_near, top.fog_far, top.blend_time)
	elif Game.level is Level:
		var lvl: Level = Game.level
		_blend(lvl.fog_color, lvl.fog_near, lvl.fog_far, blend_time)


func _blend(color: Color, near: float, far: float, time: float) -> void:
	var from_color: Color = Level.fog_now["color"]
	var from_near: float = Level.fog_now["near"]
	var from_far: float = Level.fog_now["far"]
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = Game.create_tween()
	_tween.tween_method(func(t: float) -> void:
		Level.set_fog(from_color.lerp(color, t), lerpf(from_near, near, t), lerpf(from_far, far, t)), 0.0, 1.0, time)
