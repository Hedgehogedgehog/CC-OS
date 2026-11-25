extends Button

@onready var fileDialog : FileDialog = $FileDialog
@onready var image := $"../../../TextureRect"

func _on_pressed() -> void:
	fileDialog.popup_centered(Vector2i(800, 500))

func _on_file_dialog_file_selected(path: String) -> void:
	ImageManager.image = loadExternalImage(path)
	image.texture = ImageManager.image

func loadExternalImage(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null:
		push_error("Couldn't load image: " + path)
		return null
	return ImageTexture.create_from_image(img)
