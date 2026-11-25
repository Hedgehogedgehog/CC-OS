extends Control
## Entry point: creates the models and the UI and wires them together.
##
## Models:  CCCanvas, CCPalette, CharacterSet, Brush, CanvasDocument (undo / redo)
## Logic:   CCConverter (image -> cells), CanvasEditor (drawing tools)
## UI:      CanvasArea (preview + drawing), sidebar panels, PaletteDialog

const DEFAULT_CHARS_PATH := "res://assets/default_chars.txt"
const START_SIZE := Vector2i(51, 19)
## Window size the UI is designed for at 1x. Bigger windows scale the UI up.
const UI_BASE_SIZE := Vector2(1280, 720)

var palette := CCPalette.new()
var characterSet := CharacterSet.new()
var defaultCharacterSet := CharacterSet.new()
var brush := Brush.new()
var document := CanvasDocument.new(CCCanvas.create(START_SIZE.x, START_SIZE.y))
var converter := CCConverter.new(palette, characterSet)
var editor: CanvasEditor

var canvasArea: CanvasArea
var imagePanel: ImagePanel
var charsPanel: CharsPanel
var drawPanel: DrawPanel
var filePanel: FilePanel
var paletteDialog: PaletteDialog
var updateTimer: Timer
var _converting := false
var _convertAgain := false


func _ready() -> void:
	theme = UiKit.makeTheme()
	get_window().size_changed.connect(_updateUiScale)
	_updateUiScale()
	defaultCharacterSet.loadBytes(FileAccess.get_file_as_bytes(DEFAULT_CHARS_PATH))
	characterSet.copyFrom(defaultCharacterSet)
	_buildLayout()
	_connectSignals()
	imagePanel.setCanvasSize(START_SIZE)
	canvasArea.updateStatus()


func _buildLayout() -> void:
	add_child(converter)
	var split := HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(split)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 440
	split.add_child(sidebar)
	var sidebarColumn := VBoxContainer.new()
	sidebar.add_child(UiKit.margin(sidebarColumn, 10))
	sidebarColumn.add_child(UiKit.ccFontLabel("PNG > CC", UiKit.YELLOW, 2))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebarColumn.add_child(tabs)

	canvasArea = CanvasArea.new(document, palette)
	editor = CanvasEditor.new(document, brush, canvasArea.view)

	imagePanel = ImagePanel.new()
	charsPanel = CharsPanel.new(characterSet, defaultCharacterSet)
	drawPanel = DrawPanel.new(editor, palette)
	filePanel = FilePanel.new(document, palette)
	for panel in [imagePanel, charsPanel, drawPanel, filePanel]:
		tabs.add_child(panel)
	split.add_child(canvasArea)

	paletteDialog = PaletteDialog.new(palette, func() -> Image: return imagePanel.sourceImage)
	paletteDialog.theme = theme
	add_child(paletteDialog)

	updateTimer = Timer.new()
	updateTimer.one_shot = true
	updateTimer.wait_time = 0.2
	add_child(updateTimer)


func _connectSignals() -> void:
	updateTimer.timeout.connect(_applySettings)
	imagePanel.settingsChanged.connect(updateTimer.start)
	imagePanel.imageLoaded.connect(_onImageLoaded)
	imagePanel.convertPressed.connect(convertImage)
	imagePanel.liveEnabled.connect(convertImage)
	imagePanel.paletteButtonPressed.connect(paletteDialog.openDialog)
	characterSet.changed.connect(updateTimer.start)
	palette.changed.connect(updateTimer.start)
	editor.edited.connect(_onUserEdited)
	document.canvasReplaced.connect(func() -> void:
		imagePanel.setCanvasSize(Vector2i(document.canvas.width, document.canvas.height)))
	filePanel.newCanvasRequested.connect(_newCanvas)
	filePanel.fileOpened.connect(_onFileOpened)
	for panel: SidebarPanel in [imagePanel, charsPanel, drawPanel, filePanel]:
		panel.message.connect(canvasArea.flash)
	paletteDialog.message.connect(canvasArea.flash)


## Scales the whole UI to the window size in whole steps (1x, 2x, 3x...).
## Whole steps keep every font pixel a whole number of screen pixels, so the
## text is drawn at the font's full detail instead of being smeared.
func _updateUiScale() -> void:
	var window := get_window()
	var windowSize := Vector2(window.size)
	var fit := minf(windowSize.x / UI_BASE_SIZE.x, windowSize.y / UI_BASE_SIZE.y)
	var uiScale := maxf(1.0, floorf(fit))
	var logicalSize := Vector2i((windowSize / uiScale).ceil())
	if window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and window.content_scale_size == logicalSize:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = logicalSize


## Runs shortly after any setting changes: re-convert, or just resize the canvas.
func _applySettings() -> void:
	var wanted := imagePanel.getCanvasSize()
	if imagePanel.sourceImage and imagePanel.isLive():
		convertImage()
	elif wanted != Vector2i(document.canvas.width, document.canvas.height):
		document.replace(document.canvas.resized(wanted.x, wanted.y))


## Converts on the GPU (takes a frame). If asked again while busy, runs once more after.
func convertImage() -> void:
	if imagePanel.sourceImage == null:
		imagePanel.setConvertInfo("Upload an image first.")
		return
	updateTimer.stop()
	if _converting:
		_convertAgain = true
		return
	_converting = true
	_convertAgain = true
	while _convertAgain:
		_convertAgain = false
		var wanted := imagePanel.getCanvasSize()
		var started := Time.get_ticks_msec()
		converter.useColor = imagePanel.useColor()
		var result: CCCanvas = await converter.convertImage(imagePanel.sourceImage, wanted.x, wanted.y)
		document.replace(result)
		imagePanel.setConvertInfo("Converted to %d x %d in %d ms" % [wanted.x, wanted.y, Time.get_ticks_msec() - started])
	_converting = false


func _onImageLoaded(_image: Image) -> void:
	await convertImage()
	canvasArea.view.resetView()


func _onUserEdited() -> void:
	imagePanel.pauseLive("Live update paused so your drawing isn't overwritten.")


func _onFileOpened() -> void:
	imagePanel.pauseLive("Live update paused: editing an opened file.")
	canvasArea.view.resetView()


func _newCanvas() -> void:
	imagePanel.pauseLive("Live update paused: drawing on a blank canvas.")
	var wanted := imagePanel.getCanvasSize()
	document.replace(CCCanvas.create(wanted.x, wanted.y, 32, brush.color, brush.highlight))
	canvasArea.view.resetView()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or not key.ctrl_pressed:
		return
	match key.keycode:
		KEY_Z:
			if key.shift_pressed:
				editor.redo()
			else:
				editor.undo()
		KEY_Y:
			editor.redo()
		KEY_S:
			filePanel.openSaveDialog()
		KEY_O:
			imagePanel.openUploadDialog()
		_:
			return
	get_viewport().set_input_as_handled()
