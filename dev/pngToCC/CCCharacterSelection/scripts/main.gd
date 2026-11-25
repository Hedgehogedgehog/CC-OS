extends Control
## Entry point: creates the models and the UI and wires them together.
##
## Models:  CCCanvas, CCPalette, CharacterSet, Brush, CanvasDocument (undo / redo)
## Logic:   CCConverter (image -> cells), CanvasEditor (drawing tools)
## UI:      CanvasArea (preview + drawing), sidebar panels, PaletteDialog

const DEFAULT_CHARS_PATH := "res://assets/default_chars.txt"
const START_SIZE := Vector2i(51, 19)

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


func _ready() -> void:
	theme = UiKit.makeTheme()
	defaultCharacterSet.loadBytes(FileAccess.get_file_as_bytes(DEFAULT_CHARS_PATH))
	characterSet.copyFrom(defaultCharacterSet)
	_buildLayout()
	_connectSignals()
	imagePanel.setCanvasSize(START_SIZE)
	canvasArea.updateStatus()


func _buildLayout() -> void:
	var split := HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(split)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 440
	split.add_child(sidebar)
	var sidebarColumn := VBoxContainer.new()
	sidebar.add_child(UiKit.margin(sidebarColumn, 10))
	var title := Label.new()
	title.text = "PNG > CC"
	title.add_theme_color_override("font_color", UiKit.YELLOW)
	title.add_theme_font_size_override("font_size", 36)
	sidebarColumn.add_child(title)
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


## Runs shortly after any setting changes: re-convert, or just resize the canvas.
func _applySettings() -> void:
	var wanted := imagePanel.getCanvasSize()
	if imagePanel.sourceImage and imagePanel.isLive():
		convertImage()
	elif wanted != Vector2i(document.canvas.width, document.canvas.height):
		document.replace(document.canvas.resized(wanted.x, wanted.y))


func convertImage() -> void:
	if imagePanel.sourceImage == null:
		imagePanel.setConvertInfo("Upload an image first.")
		return
	updateTimer.stop()
	var wanted := imagePanel.getCanvasSize()
	var started := Time.get_ticks_msec()
	converter.useColor = imagePanel.useColor()
	document.replace(converter.convertImage(imagePanel.sourceImage, wanted.x, wanted.y))
	imagePanel.setConvertInfo("Converted to %d x %d in %d ms" % [wanted.x, wanted.y, Time.get_ticks_msec() - started])


func _onImageLoaded(_image: Image) -> void:
	convertImage()
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
