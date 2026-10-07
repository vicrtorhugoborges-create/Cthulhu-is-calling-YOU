class_name LogoLabel
extends Control
## Logo "CtHlUhU iS cAlLiNg YoU": as letras trocam de caixa e tremem,
## como texto corrompido. O tremor anda a 12 quadros por segundo.

@export var text := "CtHlUhU iS cAlLiNg YoU"
@export var font_size := 34
@export var color := Color(0.78, 0.86, 0.7)
@export var tremble_px := 1.5

var _chars: PackedStringArray = []
var _offsets: Array[Vector2] = []
var _swap_timers: Array[float] = []
var _frame_timer := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UIStyle.serif()
	for i in text.length():
		_chars.append(text[i])
		_offsets.append(Vector2.ZERO)
		_swap_timers.append(randf_range(0.2, 2.5))
	custom_minimum_size = Vector2(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 20, font_size * 1.6)


func _process(delta: float) -> void:
	for i in _chars.size():
		_swap_timers[i] -= delta
		if _swap_timers[i] <= 0.0:
			_swap_timers[i] = randf_range(0.15, 2.8)
			var ch := _chars[i]
			_chars[i] = ch.to_lower() if ch == ch.to_upper() else ch.to_upper()
	_frame_timer -= delta
	if _frame_timer <= 0.0:
		_frame_timer = 1.0 / 12.0
		for i in _offsets.size():
			var strong := randf() < 0.04
			var amp := tremble_px * (4.0 if strong else 1.0)
			_offsets[i] = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		queue_redraw()


func _draw() -> void:
	var full := "".join(_chars)
	var width := _font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := (size.x - width) * 0.5
	var baseline := size.y * 0.5 + font_size * 0.35
	for i in _chars.size():
		var ch := _chars[i]
		var pos := Vector2(x, baseline) + _offsets[i]
		# Sombra esverdeada deslocada, como sinal de TV ruim.
		draw_string(_font, pos + Vector2(2, 1), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.15, 0.3, 0.12, 0.6))
		draw_string(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
