class_name CharGrid
extends Control
## Base class: all 256 CC characters in a 16 x 16 grid, with hover and tooltips.
## Subclasses decide how each cell looks (_cellColors) and what clicking does.

const CELL := Vector2(22, 26)

var hoverIndex := -1
var _dragging := false


func _ready() -> void:
	custom_minimum_size = CELL * 16
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = " "
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func charAt(pos: Vector2) -> int:
	if pos.x < 0 or pos.y < 0:
		return -1
	var column := int(pos.x / CELL.x)
	var row := int(pos.y / CELL.y)
	if column > 15 or row > 15:
		return -1
	return row * 16 + column


## Override: returns [background, foreground] for character c.
func _cellColors(_c: int) -> Array[Color]:
	return [Color(0.03, 0.03, 0.04), Color.WHITE]


## Override: the mouse was pressed on character c.
func _onCellPressed(_c: int) -> void:
	pass


## Override: the mouse was dragged onto character c.
func _onCellDragged(_c: int) -> void:
	pass


func _draw() -> void:
	var glyph := Vector2(CCFont.GLYPH_SIZE)
	for c in 256:
		var cellRect := Rect2(Vector2(c & 15, c >> 4) * CELL, CELL)
		var colors := _cellColors(c)
		draw_rect(cellRect.grow(-1), colors[0])
		var glyphRect := Rect2((cellRect.position + (CELL - glyph) / 2.0).floor(), glyph)
		draw_texture_rect_region(CCFont.atlas, glyphRect, CCFont.glyphRect(c), colors[1])
		if c == hoverIndex:
			draw_rect(cellRect.grow(-1), UiKit.LIGHT_BLUE, false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			var c := charAt(event.position)
			if c >= 0:
				_onCellPressed(c)
		accept_event()
	elif event is InputEventMouseMotion:
		var c := charAt(event.position)
		if c != hoverIndex:
			hoverIndex = c
			queue_redraw()
			if _dragging and c >= 0:
				_onCellDragged(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hoverIndex = -1
		queue_redraw()


func _get_tooltip(atPosition: Vector2) -> String:
	var c := charAt(atPosition)
	if c < 0:
		return ""
	return "Char %d  (0x%02X)" % [c, c]
