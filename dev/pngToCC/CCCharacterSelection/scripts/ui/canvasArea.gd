class_name CanvasArea
extends VBoxContainer
## Right-hand side: toolbar, the CC preview / drawing canvas, and a status line.

var document: CanvasDocument
var view: CCView
var _message: Label
var _status: Label
var _messageTimer: Timer


func _init(newDocument: CanvasDocument, palette: CCPalette) -> void:
	document = newDocument
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	add_child(UiKit.margin(toolbar, 6))
	toolbar.add_child(UiKit.button("Fit to screen", func() -> void: view.resetView()))
	toolbar.add_child(UiKit.checkBox("Grid", false, func(on: bool) -> void:
		view.showGrid = on
		view.queue_redraw()))
	_message = Label.new()
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.add_theme_color_override("font_color", UiKit.YELLOW)
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(_message)

	view = CCView.new()
	view.palette = palette
	view.canvas = document.canvas
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.mouse_default_cursor_shape = Control.CURSOR_CROSS
	add_child(view)
	view.hovered.connect(func(_cell: Vector2i) -> void: updateStatus())
	view.viewChanged.connect(updateStatus)

	_status = Label.new()
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(UiKit.margin(_status, 6))

	_messageTimer = Timer.new()
	_messageTimer.one_shot = true
	_messageTimer.wait_time = 6.0
	_messageTimer.timeout.connect(func() -> void: _message.text = "")
	add_child(_messageTimer)

	document.canvasReplaced.connect(_onCanvasReplaced)
	document.contentChanged.connect(_onContentChanged)


## Shows a short message in the toolbar.
func flash(text: String) -> void:
	_message.text = text
	_messageTimer.start()


func updateStatus() -> void:
	var canvas := document.canvas
	var text := "%d x %d chars" % [canvas.width, canvas.height]
	var hover := view.hoverCell
	if canvas.inBounds(hover.x, hover.y):
		var cell := canvas.getCell(hover.x, hover.y)
		text += "    x %d  y %d    char %d    color %s    highlight %s" % [
			hover.x + 1, hover.y + 1, cell.x, CCPalette.HEX[cell.y], CCPalette.HEX[cell.z]]
	text += "    scale %.2fx" % (view.drawScale() * view.uiScale())
	_status.text = text


func _onCanvasReplaced() -> void:
	view.canvas = document.canvas
	if not document.canvas.inBounds(view.textCursor.x, view.textCursor.y):
		view.textCursor = Vector2i(-1, -1)
	view.queue_redraw()
	updateStatus()


func _onContentChanged() -> void:
	view.refreshCells()
	updateStatus()
