class_name PaletteBar
extends Control
## The 16 palette swatches. Left click = brush color, right click = brush highlight.

const SWATCH := Vector2(46, 34)

var palette: CCPalette
var brush: Brush


func _init(newPalette: CCPalette, newBrush: Brush) -> void:
	palette = newPalette
	brush = newBrush
	palette.changed.connect(queue_redraw)
	brush.changed.connect(queue_redraw)


func _ready() -> void:
	custom_minimum_size = Vector2(SWATCH.x * 8, SWATCH.y * 2)
	tooltip_text = " "


func indexAt(pos: Vector2) -> int:
	if pos.x < 0 or pos.y < 0:
		return -1
	var column := int(pos.x / SWATCH.x)
	var row := int(pos.y / SWATCH.y)
	if column > 7 or row > 1:
		return -1
	return row * 8 + column


func _draw() -> void:
	var font := CCFont.font
	for i in 16:
		var swatch := Rect2(Vector2(i % 8, i >> 3) * SWATCH, SWATCH).grow(-3)
		var color := palette.getColor(i)
		draw_rect(swatch, color)
		var ink := Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE
		draw_string(font, swatch.position + Vector2(4, 16), CCPalette.HEX[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		if i == brush.color:
			draw_rect(swatch.grow(2), Color.WHITE, false, 2.0)
			draw_string(font, swatch.position + Vector2(swatch.size.x - 14, 16), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		if i == brush.highlight:
			draw_rect(swatch.grow(2), UiKit.YELLOW, false, 2.0)
			draw_string(font, swatch.position + Vector2(swatch.size.x - 14, swatch.size.y - 2), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var i := indexAt(event.position)
		if i < 0:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			brush.setColor(i)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			brush.setHighlight(i)
		accept_event()


func _get_tooltip(atPosition: Vector2) -> String:
	var i := indexAt(atPosition)
	if i < 0:
		return ""
	return "%s  %s  #%s" % [CCPalette.HEX[i], CCPalette.NAMES[i], palette.getColor(i).to_html(false)]
