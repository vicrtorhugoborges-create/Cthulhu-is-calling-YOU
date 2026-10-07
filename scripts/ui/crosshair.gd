class_name Crosshair
extends Control
## Ponto de mira discreto, a única coisa permanente na tela.
## Cresce um pouco quando há algo para usar no centro.

var focused := false:
	set(value):
		focused = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var c := size * 0.5
	var col := Color(UIStyle.TEXT, 0.55)
	if focused:
		draw_arc(c, 4.0, 0.0, TAU, 12, Color(UIStyle.TEXT, 0.7), 1.0)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(UIStyle.TEXT, 0.9))
	else:
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), col)
