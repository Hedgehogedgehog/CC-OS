class_name CharacterPicker
extends CharGrid
## Click a character to put it on the brush.

var brush: Brush


func _init(newBrush: Brush) -> void:
	brush = newBrush
	brush.changed.connect(queue_redraw)


func _cellColors(c: int) -> Array[Color]:
	if c == brush.character:
		return [UiKit.YELLOW, Color.BLACK]
	return [Color(0.03, 0.03, 0.04), Color.WHITE]


func _onCellPressed(c: int) -> void:
	brush.setCharacter(c)


func _onCellDragged(c: int) -> void:
	brush.setCharacter(c)
