class_name DrawPanel
extends SidebarPanel
## "Draw" tab: tools, paint toggles, brush colors and brush character.

const TOOL_NAMES := ["Pencil", "Fill", "Picker", "Text"]

var editor: CanvasEditor
var brush: Brush
var palette: CCPalette

var _brushPreview: CCView
var _brushInfo: Label


func _init(newEditor: CanvasEditor, newPalette: CCPalette) -> void:
	super("Draw")
	editor = newEditor
	brush = editor.brush
	palette = newPalette
	_build()
	brush.changed.connect(_refreshBrush)
	_refreshBrush()


func _build() -> void:
	addControl(UiKit.heading("Tool"))
	var tools := HFlowContainer.new()
	var group := ButtonGroup.new()
	for i in TOOL_NAMES.size():
		var toolButton := Button.new()
		toolButton.text = TOOL_NAMES[i]
		toolButton.toggle_mode = true
		toolButton.button_group = group
		toolButton.button_pressed = i == editor.tool
		toolButton.toggled.connect(func(on: bool) -> void:
			if on:
				editor.setTool(i as CanvasEditor.Tool))
		tools.add_child(toolButton)
	addControl(tools)

	addControl(UiKit.heading("Paint"))
	var channels := HFlowContainer.new()
	channels.add_child(UiKit.checkBox("Char", brush.paintCharacter, func(on: bool) -> void: brush.paintCharacter = on))
	channels.add_child(UiKit.checkBox("Color", brush.paintColor, func(on: bool) -> void: brush.paintColor = on))
	channels.add_child(UiKit.checkBox("Highlight", brush.paintHighlight, func(on: bool) -> void: brush.paintHighlight = on))
	addControl(channels)

	addControl(UiKit.heading("Brush"))
	var brushRow := HBoxContainer.new()
	brushRow.add_theme_constant_override("separation", 12)
	_brushPreview = CCView.new()
	_brushPreview.canvas = CCCanvas.create(1, 1)
	_brushPreview.palette = palette
	_brushPreview.custom_minimum_size = Vector2(44, 62)
	_brushPreview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brushPreview.focus_mode = Control.FOCUS_NONE
	brushRow.add_child(_brushPreview)
	_brushInfo = Label.new()
	brushRow.add_child(_brushInfo)
	addControl(brushRow)
	addControl(PaletteBar.new(palette, brush))
	addControl(UiKit.note("Left click = color, right click = highlight"))
	addControl(CharacterPicker.new(brush))

	var editRow := HFlowContainer.new()
	editRow.add_child(UiKit.button("Undo", editor.undo))
	editRow.add_child(UiKit.button("Redo", editor.redo))
	editRow.add_child(UiKit.button("Clear canvas", editor.clearCanvas))
	addControl(editRow)
	addControl(UiKit.note("On the canvas: left = use tool, right = copy a cell onto the brush, wheel = zoom, middle drag = pan. Ctrl+Z / Ctrl+Y = undo / redo. Text tool: click a cell, then type."))


func _refreshBrush() -> void:
	_brushPreview.canvas.setCell(0, 0, brush.character, brush.color, brush.highlight)
	_brushPreview.refreshCells()
	_brushInfo.text = "Char %d (0x%02X)\nColor %s  %s\nHighlight %s  %s" % [
		brush.character, brush.character,
		CCPalette.HEX[brush.color], CCPalette.NAMES[brush.color],
		CCPalette.HEX[brush.highlight], CCPalette.NAMES[brush.highlight]]
