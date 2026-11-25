class_name Brush
extends RefCounted
## The cell you draw with, plus which parts of it get painted.

signal changed

var character := 32
var color := 0
var highlight := 11
var paintCharacter := true
var paintColor := true
var paintHighlight := true


func setCharacter(c: int) -> void:
	character = c
	changed.emit()


func setColor(i: int) -> void:
	color = i
	changed.emit()


func setHighlight(i: int) -> void:
	highlight = i
	changed.emit()


## Takes char, color and highlight from a Vector3i cell (like CCCanvas.getCell).
func setFromCell(cell: Vector3i) -> void:
	character = cell.x
	color = cell.y
	highlight = cell.z
	changed.emit()


func asCell() -> Vector3i:
	return Vector3i(character, color, highlight)


## What a cell becomes after painting over `cell` (respecting the paint toggles).
func paintedCell(cell: Vector3i) -> Vector3i:
	return Vector3i(
		character if paintCharacter else cell.x,
		color if paintColor else cell.y,
		highlight if paintHighlight else cell.z)


func applyTo(canvas: CCCanvas, x: int, y: int) -> void:
	canvas.setCell(x, y,
		character if paintCharacter else -1,
		color if paintColor else -1,
		highlight if paintHighlight else -1)


## Writes a specific character (typing) using the brush colors.
func applyCharacter(canvas: CCCanvas, x: int, y: int, c: int) -> void:
	canvas.setCell(x, y, c,
		color if paintColor else -1,
		highlight if paintHighlight else -1)
