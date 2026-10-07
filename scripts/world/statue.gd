@tool
class_name Statue
extends StaticBody3D
## Escultura low-poly gerada por código (rascunho para o ateliê de Wilcox).
## `pose` muda braços, cabeça, torção do tronco e para onde ela está virada;
## o ShiftyObject troca a pose quando o jogador não está olhando.
## `morbid` acrescenta tentáculos pendendo do rosto (a "estátua mórbida").

const DEFAULT_MATERIAL := preload("res://materials/marble.tres")

@export var pose := 0:
	set(value):
		pose = value
		_rebuild()
@export var shape_seed := 1:
	set(value):
		shape_seed = value
		_rebuild()
@export var morbid := false:
	set(value):
		morbid = value
		_rebuild()
@export var with_pedestal := true:
	set(value):
		with_pedestal = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

var _root: Node3D
var _col: CollisionShape3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_meta(&"surface", "stone")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _root:
		_root.queue_free()
		remove_child(_root)
	_root = Node3D.new()
	_root.name = "_Figure"
	add_child(_root, false, Node.INTERNAL_MODE_FRONT)

	var mat: Material = material if material else DEFAULT_MATERIAL
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed * 7919 + pose * 104729
	var base_y := 0.0
	if with_pedestal:
		_box(Vector3(0.62, 0.9, 0.62), Vector3(0, 0.45, 0), Vector3.ZERO, mat)
		base_y = 0.9
		_add_collision(Vector3(0.62, 0.9, 0.62), Vector3(0, 0.45, 0))

	var figure := Node3D.new()
	figure.position = Vector3(0, base_y, 0)
	# Pose 0 é a pose "certa"; as outras viram o corpo para outro lado.
	figure.rotation.y = 0.0 if pose == 0 else deg_to_rad(rng.randf_range(-70.0, 70.0))
	_root.add_child(figure)

	var hunch := deg_to_rad(28.0 if morbid else rng.randf_range(-6.0, 10.0) * float(pose != 0))
	var torso_twist := deg_to_rad(rng.randf_range(-25.0, 25.0) * float(pose != 0))
	# Pernas.
	_box(Vector3(0.11, 0.62, 0.12), Vector3(-0.09, 0.31, 0), Vector3.ZERO, mat, figure)
	_box(Vector3(0.11, 0.62, 0.12), Vector3(0.09, 0.31, 0), Vector3.ZERO, mat, figure)
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.62, 0)
	torso.rotation = Vector3(hunch, torso_twist, 0)
	figure.add_child(torso)
	_box(Vector3(0.36, 0.5, 0.22), Vector3(0, 0.25, 0), Vector3.ZERO, mat, torso)
	# Braços: ângulos sorteados por pose.
	for side: float in [-1.0, 1.0]:
		var arm_angle := 0.0 if pose == 0 else rng.randf_range(-150.0, 35.0)
		var arm_spread := rng.randf_range(5.0, 35.0) * side
		var arm := Node3D.new()
		arm.position = Vector3(0.23 * side, 0.46, 0)
		arm.rotation = Vector3(deg_to_rad(arm_angle), 0, deg_to_rad(arm_spread))
		torso.add_child(arm)
		_box(Vector3(0.08, 0.48, 0.08), Vector3(0, -0.24, 0), Vector3.ZERO, mat, arm)
	# Cabeça.
	var head := Node3D.new()
	head.position = Vector3(0, 0.6, 0.02)
	head.rotation = Vector3(deg_to_rad(rng.randf_range(-25.0, 30.0) * float(pose != 0)), deg_to_rad(rng.randf_range(-50.0, 50.0) * float(pose != 0)), 0)
	torso.add_child(head)
	var sphere := SphereMesh.new()
	sphere.radius = 0.13 if not morbid else 0.17
	sphere.height = 0.28 if not morbid else 0.4
	sphere.radial_segments = 6
	sphere.rings = 4
	_mesh(sphere, Vector3(0, 0.08, 0), Vector3.ZERO, mat, head)
	if morbid:
		for i in 6:
			var a := TAU * float(i) / 6.0
			var tentacle := CylinderMesh.new()
			tentacle.top_radius = 0.03
			tentacle.bottom_radius = 0.008
			tentacle.height = rng.randf_range(0.3, 0.5)
			tentacle.radial_segments = 4
			tentacle.rings = 2
			var pos := Vector3(cos(a) * 0.07, -0.08 - tentacle.height * 0.5, 0.1 + sin(a) * 0.04)
			_mesh(tentacle, pos, Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)), mat, head)
		# Asas rudimentares nas costas.
		for side: float in [-1.0, 1.0]:
			_box(Vector3(0.02, 0.4, 0.3), Vector3(0.14 * side, 0.35, -0.16), Vector3(0.3, 0.0, 0.5 * side), mat, torso)


func _box(box_size: Vector3, pos: Vector3, rot: Vector3, mat: Material, parent: Node3D = null) -> void:
	var m := BoxMesh.new()
	m.size = box_size
	_mesh(m, pos, rot, mat, parent)


func _mesh(mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, parent: Node3D = null) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _root).add_child(mi)


func _add_collision(box_size: Vector3, pos: Vector3) -> void:
	if _col == null:
		_col = CollisionShape3D.new()
		_col.name = "_Shape"
		add_child(_col, false, Node.INTERNAL_MODE_FRONT)
	var shape := BoxShape3D.new()
	shape.size = box_size + Vector3(0, 1.2, 0)
	_col.shape = shape
	_col.position = pos + Vector3(0, 0.6, 0)
