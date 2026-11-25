class_name SidebarPanel
extends ScrollContainer
## Base class for a sidebar tab: a scrolling column of controls.
## The node name becomes the tab title.

## A short message to show the user. Emitted by the subclasses.
@warning_ignore("unused_signal")
signal message(text: String)

var content: VBoxContainer


func _init(title: String) -> void:
	name = title
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	var padding := UiKit.margin(content, 8)
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(padding)


func addControl(control: Control) -> Control:
	content.add_child(control)
	return control


func addFileDialog(mode: FileDialog.FileMode, filters: PackedStringArray, onSelected: Callable) -> FileDialog:
	var dialog := UiKit.fileDialog(mode, filters, onSelected)
	add_child(dialog)
	return dialog
