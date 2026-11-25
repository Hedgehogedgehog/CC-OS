class_name PaletteDialog
extends AcceptDialog
## Popup for editing the 16 palette colors.

signal message(text: String)

var palette: CCPalette
## func() -> Image, the uploaded image (or null).
var getImage: Callable
var _pickers: Array[ColorPickerButton] = []


func _init(newPalette: CCPalette, imageGetter: Callable) -> void:
	palette = newPalette
	getImage = imageGetter
	title = "Custom palette"
	ok_button_text = "Done"
	_build()
	palette.changed.connect(_syncPickers)


func openDialog() -> void:
	_syncPickers()
	popup_centered()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	for i in 16:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s %s" % [CCPalette.HEX[i], CCPalette.NAMES[i]]
		label.custom_minimum_size.x = 140
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(56, 30)
		picker.edit_alpha = false
		picker.color_changed.connect(func(color: Color) -> void: palette.setColor(i, color))
		row.add_child(picker)
		_pickers.append(picker)
		grid.add_child(row)
	box.add_child(grid)
	var buttons := HBoxContainer.new()
	buttons.add_child(UiKit.button("Reset to CC default", palette.reset))
	buttons.add_child(UiKit.button("Generate from image", _generateFromImage))
	box.add_child(buttons)
	box.add_child(UiKit.note("When 'Use color' is off only 0 and f are used. Apply a custom palette in CC with term.setPaletteColor (the saved .palette file lists all 16)."))
	add_child(box)


func _generateFromImage() -> void:
	var image: Image = getImage.call()
	if image == null:
		message.emit("Upload an image first.")
		return
	palette.generateFromImage(image)


func _syncPickers() -> void:
	for i in _pickers.size():
		_pickers[i].color = palette.getColor(i)
