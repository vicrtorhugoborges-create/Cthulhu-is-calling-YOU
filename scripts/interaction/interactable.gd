class_name Interactable
extends Area3D
## Algo que o jogador pode usar olhando e apertando "interagir".
## O ponto de mira cresce um pouco quando há algo assim no centro da tela;
## não há outro HUD. Precisa de um CollisionShape3D filho.

signal interacted(by: Player)

## Desligado, some da mira (não bloqueia o que está atrás, como o conteúdo de uma caixa).
@export var enabled := true:
	set(value):
		enabled = value
		collision_layer = 4 if value else 0
## Dica de controle mostrada uma vez (ids em scripts/ui/hints.gd).
@export var hint_id := ""
## Fala de Thurston na primeira interação (id em NarrationLines).
@export var narration_once := ""
@export var one_shot := false


func _init() -> void:
	collision_layer = 4 if enabled else 0
	collision_mask = 0
	monitoring = false


func interact(by: Player) -> void:
	if not enabled:
		return
	if narration_once != "":
		Narration.say_once(narration_once)
	if one_shot:
		enabled = false
	interacted.emit(by)
	_on_interact(by)


## Para subclasses.
func _on_interact(_by: Player) -> void:
	pass
