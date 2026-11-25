class_name UiKit
extends RefCounted
## Small helpers for building the UI in the CC style.
##
## Normal text uses a smooth system font so it stays sharp at any size.
## The CC font is used where it matters: titles, headings and anything that
## shows CC characters (see ccFontLabel and CCFont.font).

const YELLOW := Color(0.871, 0.871, 0.424)
const LIGHT_BLUE := Color(0.6, 0.698, 0.949)
const NOTE_GRAY := Color(0.6, 0.6, 0.6)
const CYAN := Color(0.298, 0.6, 0.698)
const TEXT_SIZE := 16
## CC font sizes must be whole multiples of 18 to keep its pixels even.
const CC_TEXT_SIZE := 18


static func makeTheme() -> Theme:
	var theme := Theme.new()
	var textFont := SystemFont.new()
	textFont.font_names = PackedStringArray(["Segoe UI", "Inter", "Arial", "sans-serif"])
	textFont.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	textFont.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	theme.default_font = textFont
	theme.default_font_size = TEXT_SIZE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.1, 0.12)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme


## A label drawn in the CC font. `sizeSteps` multiplies the font's native 18 px.
static func ccFontLabel(text: String, color: Color, sizeSteps := 1) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CCFont.font)
	label.add_theme_font_size_override("font_size", CC_TEXT_SIZE * sizeSteps)
	label.add_theme_color_override("font_color", color)
	return label


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
	return ccFontLabel(text, LIGHT_BLUE)


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
