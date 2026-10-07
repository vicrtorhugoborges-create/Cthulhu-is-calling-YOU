class_name ExaminableItem
extends Interactable
## Objeto que gira em 3D na mão. Inscrições e datas escondidas só aparecem girando:
## defina `detail_direction` (no espaço local do visual) apontando para o lado
## que tem o detalhe; quando esse lado encara a câmera, o detalhe é "achado".

signal examine_started
signal examine_finished
signal detail_found

## Nó com a parte visível do objeto (é ele que vai para a mão).
@export var visual: Node3D
## Some depois de examinado e vira uma flag (chaves, por exemplo).
@export var pickup := false
@export var pickup_flag := ""
@export var pickup_diary := ""
## Posição/rotação/escala do visual diante da câmera.
@export var examine_offset := Vector3(0.0, 0.0, -0.45)
@export var examine_rotation := Vector3.ZERO
@export var examine_scale := 1.0
@export_group("Detalhe escondido")
@export var detail_direction := Vector3.ZERO
@export_range(5.0, 60.0) var detail_angle_deg := 28.0
@export var detail_narration := ""
@export var detail_diary := ""
@export var detail_flag := ""
@export var detail_knowledge := 2.0
@export_group("")
## Flag ligada ao terminar o primeiro exame.
@export var examined_flag := ""

var _detail_done := false
## Se definido, o objeto volta para cá (em vez da posição original) ao ser largado.
var rest_override: Variant = null


func _ready() -> void:
	if hint_id == "":
		hint_id = "examine"
	if visual == null and get_child_count() > 0:
		for child in get_children():
			if child is Node3D and not child is CollisionShape3D:
				visual = child
				break


func get_visual() -> Node3D:
	return visual


func _on_interact(by: Player) -> void:
	by.begin_examine(self)


func on_examine_started(_by: Player) -> void:
	examine_started.emit()


func on_examine_finished(_by: Player) -> void:
	if examined_flag != "":
		GameState.set_flag(examined_flag)
	if pickup:
		if pickup_flag != "":
			GameState.set_flag(pickup_flag)
		if pickup_diary != "":
			GameState.add_diary_entry(pickup_diary)
		enabled = false
		visual = null
	examine_finished.emit()


func rest_transform_for(original: Transform3D) -> Transform3D:
	if rest_override is Transform3D:
		return rest_override
	return original


func check_detail(node: Node3D, camera: Camera3D) -> void:
	if _detail_done or detail_direction == Vector3.ZERO:
		return
	var world_dir := (node.global_basis * detail_direction).normalized()
	var to_cam := (camera.global_position - node.global_position).normalized()
	if world_dir.dot(to_cam) >= cos(deg_to_rad(detail_angle_deg)):
		_detail_done = true
		if detail_narration != "":
			Narration.say(detail_narration, true)
		if detail_diary != "":
			GameState.add_diary_entry(detail_diary)
		if detail_flag != "":
			GameState.set_flag(detail_flag)
		GameState.add_knowledge(detail_knowledge, "detail:" + str(get_path()))
		detail_found.emit()
