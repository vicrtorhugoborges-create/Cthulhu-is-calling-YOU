class_name TentacleShadowSpot
extends Node3D
## Sombra com formato de tentáculo (Conhecimento 51 ou mais). Só aparece na visão
## periférica: some quando o jogador olha direto para ela ou fecha os olhos.

const SHADER := preload("res://shaders/ps1_billboard.gdshader")
const TEXTURE_PATH := "res://assets/textures/draft/tentacle_shadow.png"

@export var height := 2.2
@export_range(0, 3) var min_tier := 2
@export var max_opacity := 0.55
@export var max_distance := 12.0
## Abaixo deste ângulo do centro da tela, a sombra some.
@export var direct_look_deg := 16.0
@export var cooldown := 8.0

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _opacity := 0.0
var _cooldown_left := 0.0


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	if ResourceLoader.exists(TEXTURE_PATH):
		_material.set_shader_parameter(&"albedo_texture", load(TEXTURE_PATH))
	_material.set_shader_parameter(&"albedo_color", Color(0, 0, 0, 1))
	_material.set_shader_parameter(&"lock_y", true)
	_material.set_shader_parameter(&"opacity", 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(height * 0.75, height)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = quad
	_mesh.material_override = _material
	_mesh.position.y = height * 0.5
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var target := 0.0
	var cam := Game.get_camera()
	if cam and GameState.get_tier() >= min_tier and not GameState.eyes_closed and _cooldown_left <= 0.0:
		var point := global_position + Vector3.UP * height * 0.5
		if cam.global_position.distance_to(point) < max_distance:
			var angle := CameraUtil.angle_to(cam, point)
			if angle < direct_look_deg:
				if _opacity > 0.05:
					_cooldown_left = cooldown
			elif angle < CameraUtil.half_view_angle(cam, 0.0):
				target = max_opacity
	var speed := 0.4 if target > _opacity else 3.0
	_opacity = move_toward(_opacity, target, speed * delta)
	_material.set_shader_parameter(&"opacity", _opacity)
	_mesh.visible = _opacity > 0.01
