class_name CharsPanel
extends SidebarPanel
## "Chars" tab: choose which characters the converter may use.

var characterSet: CharacterSet
var defaultSet: CharacterSet

var _countLabel: Label
var _loadDialog: FileDialog
var _saveDialog: FileDialog


func _init(newCharacterSet: CharacterSet, newDefaultSet: CharacterSet) -> void:
	super("Chars")
	characterSet = newCharacterSet
	defaultSet = newDefaultSet
	_loadDialog = addFileDialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.txt ; Character list", "* ; Any file"], _onLoadSelected)
	_saveDialog = addFileDialog(FileDialog.FILE_MODE_SAVE_FILE, ["*.txt ; Character list"], _onSaveSelected)
	_saveDialog.current_file = "chars.txt"
	_build()
	characterSet.changed.connect(_updateCount)
	_updateCount()


func _build() -> void:
	addControl(UiKit.note("Characters the converter may use. Click or drag to toggle."))
	var presets := HFlowContainer.new()
	presets.add_child(UiKit.button("All", func() -> void: characterSet.setAll(true)))
	presets.add_child(UiKit.button("None", func() -> void: characterSet.setAll(false)))
	presets.add_child(UiKit.button("Invert", characterSet.invert))
	presets.add_child(UiKit.button("Text", _onlyText))
	presets.add_child(UiKit.button("Blocks", _onlyBlocks))
	presets.add_child(UiKit.button("Default", func() -> void: characterSet.copyFrom(defaultSet)))
	addControl(presets)
	var files := HFlowContainer.new()
	files.add_child(UiKit.button("Load list...", func() -> void: _loadDialog.popup_centered_ratio(0.6)))
	files.add_child(UiKit.button("Save list...", func() -> void: _saveDialog.popup_centered_ratio(0.6)))
	addControl(files)
	addControl(CharacterSetGrid.new(characterSet))
	_countLabel = addControl(UiKit.note(""))


func _onlyText() -> void:
	characterSet.loadBytes(PackedByteArray(range(32, 127)))


## The 2x3 "teletext" block characters, plus space.
func _onlyBlocks() -> void:
	var bytes := PackedByteArray(range(128, 160))
	bytes.append(32)
	characterSet.loadBytes(bytes)


func _updateCount() -> void:
	_countLabel.text = "%d / 256 characters enabled" % characterSet.count()


func _onLoadSelected(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		message.emit("That file is empty or couldn't be read.")
		return
	characterSet.loadBytes(bytes)
	message.emit("Loaded character list from " + path.get_file())


func _onSaveSelected(path: String) -> void:
	var error := UiKit.writeFile(path, characterSet.toBytes())
	message.emit(error if error else "Saved character list to " + path)
