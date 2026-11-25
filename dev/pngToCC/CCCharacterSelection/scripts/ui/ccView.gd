class_name CCView
extends Control
## Shows a CCCanvas in the CC font, scaled to fit, and turns mouse input into
## drawing signals. Wheel = zoom, middle drag = pan.
##
## The cells are drawn by shaders/ccDisplay.gdshader in a single pass: the canvas
## bytes are uploaded as a texture. This node's own _draw only adds the overlays
## (border, grid, hover and text cursor). Call refreshCells() after editing cells.

signal strokeStarted(cell: Vector2i)
signal strokePainted(cell: Vector2i)
signal strokeFinished
signal pickRequested(cell: Vector2i)
signal hovered(cell: Vector2i)
signal viewChanged

const GLYPH := Vector2(12, 18)
const DISPLAY_SHADER := preload("res://shaders/ccDisplay.gdshader")

var canvas: CCCanvas: set = setCanvas
var palette: CCPalette: set = setPalette
var showGrid := false
var zoom := 1.0
var pan := Vector2.ZERO
var textCursor := Vector2i(-1, -1)
var hoverCell := Vector2i(-1, -1)
## func(event: InputEventKey) -> bool. Return true when the key was used.
var keyHandler: Callable

var _background: ColorRect
var _cellsRect: ColorRect
var _material: ShaderMaterial
var _cellTexture: ImageTexture
var _painting := false
var _panning := false
var _lastCell := Vector2i.ZERO


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_background = ColorRect.new()
	_background.color = Color(0.07, 0.07, 0.09)
	_background.show_behind_parent = true
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_material = ShaderMaterial.new()
	_material.shader = DISPLAY_SHADER
	_material.set_shader_parameter("font_atlas", CCFont.atlas)
	_cellsRect = ColorRect.new()
	_cellsRect.material = _material
	_cellsRect.show_behind_parent = true
	_cellsRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cellsRect)
	resized.connect(_layoutCells)


func setCanvas(newCanvas: CCCanvas) -> void:
	canvas = newCanvas
	refreshCells()


func setPalette(newPalette: CCPalette) -> void:
	if palette and palette.changed.is_connected(_uploadPalette):
		palette.changed.disconnect(_uploadPalette)
	palette = newPalette
	palette.changed.connect(_uploadPalette)
	_uploadPalette()


## Uploads the canvas cells to the GPU. Call after changing cells.
func refreshCells() -> void:
	if canvas == null:
		return
	var image := Image.create_from_data(canvas.width, canvas.height, false, Image.FORMAT_RGBA8, canvas.data)
	if _cellTexture and Vector2i(_cellTexture.get_size()) == Vector2i(canvas.width, canvas.height):
		_cellTexture.update(image)
	else:
		_cellTexture = ImageTexture.create_from_image(image)
		_material.set_shader_parameter("cells", _cellTexture)
		_material.set_shader_parameter("grid_size", Vector2i(canvas.width, canvas.height))
	_layoutCells()


func canvasPixels() -> Vector2:
	return Vector2(canvas.width, canvas.height) * GLYPH


func fitScale() -> float:
	if canvas == null or canvas.width == 0 or canvas.height == 0:
		return 1.0
	var pixels := canvasPixels()
	return maxf(0.02, minf((size.x - 16.0) / pixels.x, (size.y - 16.0) / pixels.y))


## Canvas scale in this control's units. Snapping is done in real screen pixels
## (the UI itself may be scaled): at 1x and above to whole font pixels so the
## glyphs keep their full detail, below that so every cell is a whole number of
## screen pixels.
func drawScale() -> float:
	var factor := uiScale()
	var screenScale := fitScale() * zoom * factor
	if screenScale >= 1.0:
		screenScale = floorf(screenScale)
	else:
		screenScale = maxf(1.0, floorf(screenScale * GLYPH.x)) / GLYPH.x
	return screenScale / factor


func origin() -> Vector2:
	var factor := uiScale()
	var centered := (size - canvasPixels() * drawScale()) / 2.0 + pan
	return (centered * factor).floor() / factor


## How many screen pixels one unit of this control is (the window's UI scale).
func uiScale() -> float:
	if not is_inside_tree():
		return 1.0
	return get_viewport().get_final_transform().get_scale().x


func cellAt(pos: Vector2) -> Vector2i:
	var cell := (pos - origin()) / (GLYPH * drawScale())
	return Vector2i(floori(cell.x), floori(cell.y))


func resetView() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_layoutCells()
	viewChanged.emit()


func _uploadPalette() -> void:
	_material.set_shader_parameter("palette", PackedColorArray(palette.colors))


func _layoutCells() -> void:
	if canvas == null:
		return
	_cellsRect.position = origin()
	_cellsRect.size = canvasPixels() * drawScale()
	queue_redraw()


func _draw() -> void:
	if canvas == null:
		return
	var viewScale := drawScale()
	var cellSize := GLYPH * viewScale
	var start := origin()
	draw_rect(Rect2(start - Vector2.ONE, canvasPixels() * viewScale + Vector2(2, 2)), Color(0.35, 0.35, 0.42), false, 1.0)
	if showGrid and cellSize.x >= 6.0:
		_drawGrid(start, cellSize)
	if canvas.inBounds(textCursor.x, textCursor.y):
		var cursorRect := Rect2(start + Vector2(textCursor) * cellSize, cellSize)
		draw_rect(cursorRect, UiKit.CYAN, false, 2.0)
		draw_rect(Rect2(cursorRect.position + Vector2(0, cursorRect.size.y - 3), Vector2(cursorRect.size.x, 3)), UiKit.CYAN)
	if canvas.inBounds(hoverCell.x, hoverCell.y):
		draw_rect(Rect2(start + Vector2(hoverCell) * cellSize, cellSize), UiKit.YELLOW, false, 2.0)


func _drawGrid(start: Vector2, cellSize: Vector2) -> void:
	var lineColor := Color(1, 1, 1, 0.12)
	var full := canvasPixels() * drawScale()
	var from := Vector2i(clampi(floori(-start.x / cellSize.x), 0, canvas.width), clampi(floori(-start.y / cellSize.y), 0, canvas.height))
	var to := Vector2i(clampi(ceili((size.x - start.x) / cellSize.x), 0, canvas.width), clampi(ceili((size.y - start.y) / cellSize.y), 0, canvas.height))
	for gx in range(from.x, to.x + 1):
		draw_line(start + Vector2(gx * cellSize.x, 0), start + Vector2(gx * cellSize.x, full.y), lineColor)
	for gy in range(from.y, to.y + 1):
		draw_line(start + Vector2(0, gy * cellSize.y), start + Vector2(full.x, gy * cellSize.y), lineColor)


func _gui_input(event: InputEvent) -> void:
	if canvas == null:
		return
	if event is InputEventMouseButton:
		_onMouseButton(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_onMouseMotion(event as InputEventMouseMotion)
	elif event is InputEventKey and event.pressed:
		if keyHandler.is_valid() and keyHandler.call(event):
			accept_event()


func _onMouseButton(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoomAt(event.position, 1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8)
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				_painting = true
				_lastCell = cellAt(event.position)
				strokeStarted.emit(_lastCell)
			elif _painting:
				_painting = false
				strokeFinished.emit()
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				pickRequested.emit(cellAt(event.position))
		_:
			return
	accept_event()


func _onMouseMotion(event: InputEventMouseMotion) -> void:
	if _panning:
		pan += event.relative
		_layoutCells()
		viewChanged.emit()
	var cell := cellAt(event.position)
	if cell != hoverCell:
		hoverCell = cell
		hovered.emit(cell)
		queue_redraw()
	if _painting and cell != _lastCell:
		for p in _lineCells(_lastCell, cell):
			strokePainted.emit(p)
		_lastCell = cell


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hoverCell = Vector2i(-1, -1)
		hovered.emit(hoverCell)
		queue_redraw()


func _zoomAt(pos: Vector2, factor: float) -> void:
	var oldScale := drawScale()
	var canvasPoint := (pos - origin()) / oldScale
	zoom = clampf(zoom * factor, 0.1, 60.0)
	var newScale := drawScale()
	pan = pos - canvasPoint * newScale - (size - canvasPixels() * newScale) / 2.0
	_layoutCells()
	viewChanged.emit()


## Cells on the line from a to b (Bresenham), not including a.
func _lineCells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var stepX := 1 if a.x < b.x else -1
	var stepY := 1 if a.y < b.y else -1
	var error := dx + dy
	var p := a
	while p != b:
		var doubled := 2 * error
		if doubled >= dy:
			error += dy
			p.x += stepX
		if doubled <= dx:
			error += dx
			p.y += stepY
		cells.append(p)
	return cells
