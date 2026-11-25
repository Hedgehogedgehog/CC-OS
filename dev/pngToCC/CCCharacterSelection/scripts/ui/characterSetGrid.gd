class_name CharacterSetGrid
extends CharGrid
## Click or drag to turn characters on / off in a CharacterSet.

var characterSet: CharacterSet
var _dragValue := true


func _init(newCharacterSet: CharacterSet) -> void:
	characterSet = newCharacterSet
	characterSet.changed.connect(queue_redraw)


func _cellColors(c: int) -> Array[Color]:
	if characterSet.isEnabled(c):
		return [Color(0.03, 0.03, 0.04), Color.WHITE]
	return [Color(0.2, 0.2, 0.23), Color(0.4, 0.4, 0.44)]


func _onCellPressed(c: int) -> void:
	_dragValue = not characterSet.isEnabled(c)
	characterSet.setEnabled(c, _dragValue)


func _onCellDragged(c: int) -> void:
	characterSet.setEnabled(c, _dragValue)
