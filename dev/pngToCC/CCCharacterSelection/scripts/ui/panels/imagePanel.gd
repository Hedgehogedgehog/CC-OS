class_name ImagePanel
extends SidebarPanel
## "Image" tab: upload, size sliders, color options and conversion controls.

signal imageLoaded(image: Image)
## Size or color option changed.
signal settingsChanged
signal convertPressed
signal paletteButtonPressed
signal liveEnabled

const MAX_SIZE := 400
const PRESETS := [["Computer", 51, 19], ["Pocket", 26, 20], ["Turtle", 39, 13], ["Monitor 8x6", 164, 81]]

var sourceImage: Image

var _uploadDialog: FileDialog
var _thumbnail: TextureRect
var _imageInfo: Label
var _widthSlider: HSlider
var _widthSpin: SpinBox
var _heightSlider: HSlider
var _heightSpin: SpinBox
var _keepAspect: CheckBox
var _useColor: CheckButton
var _live: CheckBox
var _convertInfo: Label
var _syncing := false


func _init() -> void:
	super("Image")
	_uploadDialog = addFileDialog(FileDialog.FILE_MODE_OPEN_FILE,
		["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga, *.svg ; Images"], _onImageSelected)
	_build()


func openUploadDialog() -> void:
	_uploadDialog.popup_centered_ratio(0.6)


func getCanvasSize() -> Vector2i:
	return Vector2i(int(_widthSlider.value), int(_heightSlider.value))


## Updates the sliders without emitting settingsChanged.
func setCanvasSize(newSize: Vector2i) -> void:
	_syncing = true
	_widthSlider.value = newSize.x
	_widthSpin.value = newSize.x
	_heightSlider.value = newSize.y
	_heightSpin.value = newSize.y
	_syncing = false


func useColor() -> bool:
	return _useColor.button_pressed


func isLive() -> bool:
	return _live.button_pressed


## Turns live update off (without converting) and says why.
func pauseLive(reason: String) -> void:
	if _live.button_pressed:
		_live.set_pressed_no_signal(false)
		_convertInfo.text = reason


func setConvertInfo(text: String) -> void:
	_convertInfo.text = text


func _build() -> void:
	addControl(UiKit.button("Upload image...", openUploadDialog))
	_thumbnail = TextureRect.new()
	_thumbnail.custom_minimum_size = Vector2(0, 150)
	_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	addControl(_thumbnail)
	_imageInfo = addControl(UiKit.note("No image loaded. You can still draw on the canvas."))

	addControl(UiKit.heading("Size (in characters)"))
	var widthRow := _addSizeRow("Width", true)
	_widthSlider = widthRow[0]
	_widthSpin = widthRow[1]
	var heightRow := _addSizeRow("Height", false)
	_heightSlider = heightRow[0]
	_heightSpin = heightRow[1]
	_keepAspect = addControl(UiKit.checkBox("Keep image aspect ratio", true, _onKeepAspectToggled))
	var presetRow := HFlowContainer.new()
	for preset in PRESETS:
		presetRow.add_child(UiKit.button("%s %dx%d" % preset, _applyPreset.bind(preset[1], preset[2])))
	addControl(presetRow)

	addControl(UiKit.heading("Color"))
	_useColor = CheckButton.new()
	_useColor.text = "Use color"
	_useColor.button_pressed = true
	_useColor.tooltip_text = "Off: only palette 0 (white) and f (black) are used."
	_useColor.toggled.connect(func(_on: bool) -> void: settingsChanged.emit())
	addControl(_useColor)
	addControl(UiKit.button("Custom palette...", func() -> void: paletteButtonPressed.emit()))

	addControl(UiKit.heading("Conversion"))
	_live = UiKit.checkBox("Live update", true, func(on: bool) -> void:
		if on:
			liveEnabled.emit())
	_live.tooltip_text = "Re-convert the image whenever a setting changes.\nTurns itself off when you draw, so your edits aren't lost."
	addControl(_live)
	addControl(UiKit.button("Convert now", func() -> void: convertPressed.emit()))
	_convertInfo = addControl(UiKit.note(""))


func _addSizeRow(labelText: String, isWidth: bool) -> Array:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = labelText
	label.custom_minimum_size.x = 84
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = MAX_SIZE
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = MAX_SIZE
	spin.step = 1
	row.add_child(spin)
	slider.value_changed.connect(_onSizeInput.bind(isWidth, spin))
	spin.value_changed.connect(_onSizeInput.bind(isWidth, slider))
	addControl(row)
	return [slider, spin]


func _onSizeInput(value: float, isWidth: bool, twin: Range) -> void:
	if _syncing:
		return
	_syncing = true
	twin.value = value
	if _keepAspect.button_pressed and sourceImage:
		if isWidth:
			var newHeight := _aspectHeight(int(value))
			_heightSlider.value = newHeight
			_heightSpin.value = newHeight
		else:
			var newWidth := _aspectWidth(int(value))
			_widthSlider.value = newWidth
			_widthSpin.value = newWidth
	_syncing = false
	settingsChanged.emit()


func _onKeepAspectToggled(on: bool) -> void:
	if on and sourceImage:
		var width := int(_widthSlider.value)
		setCanvasSize(Vector2i(width, _aspectHeight(width)))
		settingsChanged.emit()


## Height (in chars) that keeps the image's shape. A CC cell is 6 x 9 pixels.
func _aspectHeight(width: int) -> int:
	return clampi(roundi(width * 6.0 * sourceImage.get_height() / (sourceImage.get_width() * 9.0)), 1, MAX_SIZE)


func _aspectWidth(height: int) -> int:
	return clampi(roundi(height * 9.0 * sourceImage.get_width() / (sourceImage.get_height() * 6.0)), 1, MAX_SIZE)


## Fits the image inside a screen size (or uses the exact size when not keeping aspect).
func _applyPreset(presetWidth: int, presetHeight: int) -> void:
	var newSize := Vector2i(presetWidth, presetHeight)
	if sourceImage and _keepAspect.button_pressed:
		newSize.y = _aspectHeight(presetWidth)
		if newSize.y > presetHeight:
			newSize = Vector2i(mini(_aspectWidth(presetHeight), presetWidth), presetHeight)
	setCanvasSize(newSize)
	settingsChanged.emit()


func _onImageSelected(path: String) -> void:
	var loaded := Image.load_from_file(path)
	if loaded == null or loaded.is_empty():
		message.emit("Couldn't load image: " + path)
		return
	sourceImage = loaded
	ImageManager.sourceImage = loaded
	ImageManager.image = ImageTexture.create_from_image(loaded)
	_thumbnail.texture = ImageManager.image
	_imageInfo.text = "%s  (%d x %d px)" % [path.get_file(), loaded.get_width(), loaded.get_height()]
	if _keepAspect.button_pressed:
		var width := int(_widthSlider.value)
		setCanvasSize(Vector2i(width, _aspectHeight(width)))
	_live.set_pressed_no_signal(true)
	imageLoaded.emit(loaded)
