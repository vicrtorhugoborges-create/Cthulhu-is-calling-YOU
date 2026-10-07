@tool
class_name GrayBox
extends StaticBody3D
## Bloco de cenário cinza (greybox). Gera malha subdividida e colisão a partir de
## `size`: mude o tamanho no Inspetor e o bloco se refaz no próprio editor.
## A malha é subdividida porque iluminação por vértice e textura afim precisam
## de vértices (no PS1, chão sem subdivisão deformava demais).

enum Shape { BOX, CYLINDER, RAMP }

const DEFAULT_MATERIAL := preload("res://materials/ps1_gray.tres")

@export var size := Vector3.ONE:
	set(value):
		size = value
		_rebuild()
@export var shape := Shape.BOX:
	set(value):
		shape = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()
@export var has_collision := true:
	set(value):
		has_collision = value
		_rebuild()
## Som dos passos em cima deste bloco.
@export_enum("wood", "stone") var surface := "wood":
	set(value):
		surface = value
		set_meta(&"surface", surface)
## Subdivisões por metro (rampa: a subida é no sentido +X).
@export_range(0.0, 4.0, 0.25) var subdivisions_per_meter := 1.0:
	set(value):
		subdivisions_per_meter = value
		_rebuild()
@export var cast_shadow := false

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_meta(&"surface", surface)
	_rebuild()


func _subdiv(length: float) -> int:
	return clampi(int(length * subdivisions_per_meter) - 1, 0, 48)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "_Mesh"
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "_Shape"
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)

	var mesh: PrimitiveMesh
	var col_shape: Shape3D
	match shape:
		Shape.CYLINDER:
			var cyl := CylinderMesh.new()
			cyl.top_radius = size.x * 0.5
			cyl.bottom_radius = size.x * 0.5
			cyl.height = size.y
			cyl.radial_segments = 8
			cyl.rings = _subdiv(size.y)
			mesh = cyl
			var cs := CylinderShape3D.new()
			cs.radius = size.x * 0.5
			cs.height = size.y
			col_shape = cs
		Shape.RAMP:
			var prism := PrismMesh.new()
			prism.size = size
			prism.left_to_right = 1.0
			prism.subdivide_width = _subdiv(size.x)
			prism.subdivide_depth = _subdiv(size.z)
			mesh = prism
			col_shape = prism.create_convex_shape()
		_:
			var box := BoxMesh.new()
			box.size = size
			box.subdivide_width = _subdiv(size.x)
			box.subdivide_height = _subdiv(size.y)
			box.subdivide_depth = _subdiv(size.z)
			mesh = box
			var bs := BoxShape3D.new()
			bs.size = size
			col_shape = bs

	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material if material else DEFAULT_MATERIAL
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collision.shape = col_shape
	_collision.disabled = not has_collision
