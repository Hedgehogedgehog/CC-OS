class_name CanvasDocument
extends RefCounted
## The canvas being worked on, plus its undo / redo history.

## The whole canvas was swapped (it may have a new size).
signal canvasReplaced
## Cells were edited in place.
signal contentChanged

const UNDO_LIMIT := 200

var canvas: CCCanvas
var _undoStack: Array[CCCanvas] = []
var _redoStack: Array[CCCanvas] = []


func _init(startCanvas: CCCanvas) -> void:
	canvas = startCanvas


## Call before changing cells so the change can be undone.
func pushUndo() -> void:
	_undoStack.append(canvas.copy())
	if _undoStack.size() > UNDO_LIMIT:
		_undoStack.pop_front()
	_redoStack.clear()


## Forget the last pushUndo (used when a stroke ended up changing nothing).
func dropLastUndo() -> void:
	if not _undoStack.is_empty():
		_undoStack.pop_back()


func replace(newCanvas: CCCanvas, recordUndo := true) -> void:
	if recordUndo:
		pushUndo()
	canvas = newCanvas
	canvasReplaced.emit()


func markChanged() -> void:
	contentChanged.emit()


func undo() -> bool:
	if _undoStack.is_empty():
		return false
	_redoStack.append(canvas.copy())
	canvas = _undoStack.pop_back()
	canvasReplaced.emit()
	return true


func redo() -> bool:
	if _redoStack.is_empty():
		return false
	_undoStack.append(canvas.copy())
	canvas = _redoStack.pop_back()
	canvasReplaced.emit()
	return true
