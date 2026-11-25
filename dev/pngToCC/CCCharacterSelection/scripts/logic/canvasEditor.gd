class_name CanvasEditor
extends RefCounted
## The drawing tools. Listens to a CCView and edits a CanvasDocument with a Brush.

## The user changed the canvas by hand (drawing, typing, undo...).
signal edited
signal toolChanged(tool: Tool)

enum Tool { PENCIL, FILL, PICKER, TEXT }

var document: CanvasDocument
var brush: Brush
var view: CCView
var tool := Tool.PENCIL

var _strokeDirty := false
var _textOriginX := 0


func _init(newDocument: CanvasDocument, newBrush: Brush, newView: CCView) -> void:
	document = newDocument
	brush = newBrush
	view = newView
	view.strokeStarted.connect(_onStrokeStarted)
	view.strokePainted.connect(_onStrokePainted)
	view.strokeFinished.connect(_onStrokeFinished)
	view.pickRequested.connect(pick)
	view.keyHandler = _handleKey


func setTool(newTool: Tool) -> void:
	tool = newTool
	if tool != Tool.TEXT:
		view.textCursor = Vector2i(-1, -1)
	view.mouse_default_cursor_shape = Control.CURSOR_IBEAM if tool == Tool.TEXT else Control.CURSOR_CROSS
	view.queue_redraw()
	toolChanged.emit(tool)


func undo() -> void:
	if document.undo():
		edited.emit()


func redo() -> void:
	if document.redo():
		edited.emit()


func clearCanvas() -> void:
	document.pushUndo()
	document.canvas.fillAll(32, brush.color, brush.highlight)
	_changed()


func pick(cell: Vector2i) -> void:
	if document.canvas.inBounds(cell.x, cell.y):
		brush.setFromCell(document.canvas.getCell(cell.x, cell.y))


func paint(cell: Vector2i) -> void:
	if not document.canvas.inBounds(cell.x, cell.y):
		return
	brush.applyTo(document.canvas, cell.x, cell.y)
	_strokeDirty = true
	_changed()


func floodFill(cell: Vector2i) -> void:
	var canvas := document.canvas
	if not canvas.inBounds(cell.x, cell.y):
		return
	var target := canvas.getCell(cell.x, cell.y)
	var replacement := brush.paintedCell(target)
	if replacement == target:
		return
	document.pushUndo()
	var stack: Array[Vector2i] = [cell]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if not canvas.inBounds(p.x, p.y) or canvas.getCell(p.x, p.y) != target:
			continue
		canvas.setCell(p.x, p.y, replacement.x, replacement.y, replacement.z)
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)
	_changed()


func _onStrokeStarted(cell: Vector2i) -> void:
	match tool:
		Tool.PENCIL:
			document.pushUndo()
			_strokeDirty = false
			paint(cell)
		Tool.FILL:
			floodFill(cell)
		Tool.PICKER:
			pick(cell)
		Tool.TEXT:
			if document.canvas.inBounds(cell.x, cell.y):
				view.textCursor = cell
				_textOriginX = cell.x
				view.queue_redraw()


func _onStrokePainted(cell: Vector2i) -> void:
	if tool == Tool.PENCIL:
		paint(cell)
	elif tool == Tool.PICKER:
		pick(cell)


func _onStrokeFinished() -> void:
	if tool == Tool.PENCIL and not _strokeDirty:
		document.dropLastUndo()


## Typing with the Text tool. Returns true when the key was used.
func _handleKey(event: InputEventKey) -> bool:
	var canvas := document.canvas
	var cursor := view.textCursor
	if tool != Tool.TEXT or not canvas.inBounds(cursor.x, cursor.y):
		return false
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return false
	match event.keycode:
		KEY_LEFT:
			cursor.x -= 1
		KEY_RIGHT:
			cursor.x += 1
		KEY_UP:
			cursor.y -= 1
		KEY_DOWN:
			cursor.y += 1
		KEY_ENTER, KEY_KP_ENTER:
			cursor = Vector2i(_textOriginX, cursor.y + 1)
		KEY_ESCAPE:
			view.textCursor = Vector2i(-1, -1)
			view.queue_redraw()
			return true
		KEY_BACKSPACE:
			cursor.x -= 1
			if canvas.inBounds(cursor.x, cursor.y):
				document.pushUndo()
				brush.applyCharacter(canvas, cursor.x, cursor.y, 32)
				_changed()
		_:
			var typed := event.unicode
			if typed < 32 or typed > 255:
				return false
			document.pushUndo()
			brush.applyCharacter(canvas, cursor.x, cursor.y, typed)
			_changed()
			cursor.x += 1
			if cursor.x >= canvas.width:
				cursor = Vector2i(_textOriginX, cursor.y + 1)
	cursor.x = clampi(cursor.x, 0, canvas.width - 1)
	cursor.y = clampi(cursor.y, 0, canvas.height - 1)
	view.textCursor = cursor
	view.queue_redraw()
	return true


func _changed() -> void:
	document.markChanged()
	edited.emit()
