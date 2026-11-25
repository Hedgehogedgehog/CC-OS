class_name UiKit
extends RefCounted
## Small helpers for building the UI in the CC style.

const YELLOW := Color(0.871, 0.871, 0.424)
const LIGHT_BLUE := Color(0.6, 0.698, 0.949)
const NOTE_GRAY := Color(0.6, 0.6, 0.6)
const CYAN := Color(0.298, 0.6, 0.698)


## Theme that draws every control in the CC font.
static func makeTheme() -> Theme:
	var theme := Theme.new()
	theme.default_font = CCFont.font
	theme.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.1, 0.12)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme


static func button(text: String, onPressed: Callable) -> Button:
	var newButton := Button.new()
	newButton.text = text
	newButton.pressed.connect(onPressed)
	return newButton


static func checkBox(text: String, on: bool, onToggled: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = on
	box.toggled.connect(onToggled)
	return box


static func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", LIGHT_BLUE)
	return label


static func note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 360
	label.add_theme_color_override("font_color", NOTE_GRAY)
	return label


static func margin(child: Control, pixels: int) -> MarginContainer:
	var container := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		container.add_theme_constant_override("margin_" + side, pixels)
	container.add_child(child)
	return container


static func fileDialog(mode: FileDialog.FileMode, filters: PackedStringArray, onSelected: Callable) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = filters
	dialog.use_native_dialog = true
	dialog.file_selected.connect(onSelected)
	return dialog


static func writeFile(path: String, bytes: PackedByteArray) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Couldn't write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	file.store_buffer(bytes)
	file.close()
	return ""
