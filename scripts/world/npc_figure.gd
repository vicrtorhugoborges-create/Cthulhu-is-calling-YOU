@tool
class_name NpcFigure
extends Node3D
## Personagem low-poly sentado (rascunho; o documento pede 300–600 polígonos).
## Anima a 12 quadros por segundo: respiração e cabeça que acompanha o jogador.

const CLOTH := preload("res://materials/cloth_dark.tres")
const SKIN := preload("res://materials/skin.tres")
const WOOD := preload("res://materials/wood_dark.tres")
const ANIM_FPS := 12.0

@export var seated := true:
	set(value):
		seated = value
		_rebuild()
@export var look_at_player := true
@export_range(0.0, 90.0) var max_head_turn_deg := 55.0

var _root: Node3D
var _torso: Node3D
var _head: Node3D
var _anim_timer := 0.0
var _time := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _root:
		_root.queue_free()
		remove_child(_root)
	_root = Node3D.new()
	add_child(_root, false, Node.INTERNAL_MODE_FRONT)
	var hip_y := 0.48 if seated else 0.9
	if seated:
		_box(_root, Vector3(0.48, 0.06, 0.46), Vector3(0, 0.44, 0), WOOD)
		_box(_root, Vector3(0.48, 0.6, 0.05), Vector3(0, 0.75, -0.22), WOOD)
		for x: float in [-0.2, 0.2]:
			for z: float in [-0.2, 0.2]:
				_box(_root, Vector3(0.05, 0.44, 0.05), Vector3(x, 0.22, z), WOOD)
		# Coxas para a frente, canelas para baixo.
		for x: float in [-0.1, 0.1]:
			_box(_root, Vector3(0.14, 0.13, 0.42), Vector3(x, hip_y + 0.02, 0.16), CLOTH)
			_box(_root, Vector3(0.12, 0.46, 0.13), Vector3(x, 0.24, 0.36), CLOTH)
			_box(_root, Vector3(0.12, 0.06, 0.22), Vector3(x, 0.03, 0.42), CLOTH)
	else:
		for x: float in [-0.1, 0.1]:
			_box(_root, Vector3(0.13, 0.9, 0.14), Vector3(x, 0.45, 0), CLOTH)
	_torso = Node3D.new()
	_torso.position = Vector3(0, hip_y, 0)
	_torso.rotation.x = deg_to_rad(12.0 if seated else 0.0)
	_root.add_child(_torso)
	_box(_torso, Vector3(0.38, 0.55, 0.22), Vector3(0, 0.28, 0), CLOTH)
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.24 * side, 0.52, 0)
		arm.rotation = Vector3(deg_to_rad(-35.0 if seated else 0.0), 0, deg_to_rad(6.0 * side))
		_torso.add_child(arm)
		_box(arm, Vector3(0.09, 0.5, 0.1), Vector3(0, -0.25, 0), CLOTH)
		_box(arm, Vector3(0.07, 0.09, 0.08), Vector3(0, -0.53, 0.01), SKIN)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0.01)
	_torso.add_child(_head)
	_box(_head, Vector3(0.08, 0.08, 0.08), Vector3(0, 0.02, 0), SKIN)
	var skull := SphereMesh.new()
	skull.radius = 0.11
	skull.height = 0.26
	skull.radial_segments = 8
	skull.rings = 5
	_mesh(_head, skull, Vector3(0, 0.15, 0.01), SKIN)
	var hair := SphereMesh.new()
	hair.radius = 0.115
	hair.height = 0.16
	hair.is_hemisphere = true
	hair.radial_segments = 8
	hair.rings = 3
	_mesh(_head, hair, Vector3(0, 0.19, -0.01), CLOTH)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _torso == null:
		return
	_time += delta
	_anim_timer -= delta
	if _anim_timer > 0.0:
		return
	_anim_timer = 1.0 / ANIM_FPS
	_torso.scale.y = 1.0 + sin(_time * 1.6) * 0.012
	if look_at_player:
		var cam := Game.get_camera()
		if cam:
			var local := _root.to_local(cam.global_position)
			var yaw := clampf(atan2(local.x, local.z), deg_to_rad(-max_head_turn_deg), deg_to_rad(max_head_turn_deg))
			_head.rotation.y = lerp_angle(_head.rotation.y, yaw, 0.25)


func _box(parent: Node3D, s: Vector3, pos: Vector3, mat: Material) -> void:
	var m := BoxMesh.new()
	m.size = s
	_mesh(parent, m, pos, mat)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
