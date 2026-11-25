class_name FilePanel
extends SidebarPanel
## "File" tab: save to file, open a saved CC image, start a blank canvas.

signal newCanvasRequested
signal fileOpened

enum Format { ABC, BLIT }

var document: CanvasDocument
var palette: CCPalette

var _format: OptionButton
var _savePalette: CheckBox
var _saveDialog: FileDialog
var _openDialog: FileDialog


func _init(newDocument: CanvasDocument, newPalette: CCPalette) -> void:
	super("File")
	document = newDocument
	palette = newPalette
	_saveDialog = addFileDialog(FileDialog.FILE_MODE_SAVE_FILE, ["*.txt ; CC image", "* ; Any file"], _onSaveSelected)
	_saveDialog.current_file = "image.txt"
	_openDialog = addFileDialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.txt ; CC image", "* ; Any file"], _onOpenSelected)
	_build()


func openSaveDialog() -> void:
	_saveDialog.popup_centered_ratio(0.6)


func _build() -> void:
	addControl(UiKit.heading("Output"))
	_format = OptionButton.new()
	_format.add_item("abc  (char, color, highlight)", Format.ABC)
	_format.add_item("blit (text / color / highlight lines)", Format.BLIT)
	addControl(_format)
	_savePalette = addControl(UiKit.checkBox("Also save a .palette file when the palette is custom", true, func(_on: bool) -> void: pass))
	addControl(UiKit.button("Save to file...  (Ctrl+S)", openSaveDialog))
	addControl(UiKit.note("abc: one line per row, 3 bytes per cell: the character byte, then its color and highlight as hex digits 0-f. Open it in CC with fs.open(path, \"rb\")."))

	addControl(UiKit.heading("Open / new"))
	addControl(UiKit.button("Open CC file...", func() -> void: _openDialog.popup_centered_ratio(0.6)))
	addControl(UiKit.button("New blank canvas", func() -> void: newCanvasRequested.emit()))
	addControl(UiKit.note("A new canvas uses the Width / Height from the Image tab and the brush colors."))


func _onSaveSelected(path: String) -> void:
	var canvas := document.canvas
	var bytes := canvas.toAbc() if _format.get_selected_id() == Format.ABC else canvas.toBlit()
	var error := UiKit.writeFile(path, bytes)
	if error:
		message.emit(error)
		return
	var text := "Saved " + path
	if _savePalette.button_pressed and not palette.isDefault():
		var palettePath := path.get_basename() + ".palette"
		error = UiKit.writeFile(palettePath, palette.toText().to_ascii_buffer())
		text += (" (palette failed: %s)" % error) if error else " and " + palettePath.get_file()
	message.emit(text)


func _onOpenSelected(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var canvas := CCCanvas.fromAbc(bytes)
	if canvas == null:
		canvas = CCCanvas.fromBlit(bytes)
	if canvas == null:
		message.emit("Couldn't read %s as an abc or blit image." % path.get_file())
		return
	var palettePath := path.get_basename() + ".palette"
	if FileAccess.file_exists(palettePath):
		palette.loadText(FileAccess.get_file_as_string(palettePath))
	document.replace(canvas)
	fileOpened.emit()
	message.emit("Opened " + path.get_file())
