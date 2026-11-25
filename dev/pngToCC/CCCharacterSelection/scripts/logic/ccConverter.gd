class_name CCConverter
extends Node
## Turns an image into CC cells on the GPU.
##
## The image is resized so every cell covers 6 x 9 pixels (CC's real glyph size),
## then shaders/ccConvert.gdshader runs once per cell in an off-screen viewport
## and the result is read back as a CCCanvas. Must be in the scene tree.

const PIXELS_W := 6
const PIXELS_H := 9
const CONVERT_SHADER := preload("res://shaders/ccConvert.gdshader")

var palette: CCPalette
var characterSet: CharacterSet
## Off = only palette slots 0 (white) and f (black) are used.
var useColor := true

var _viewport: SubViewport
var _material: ShaderMaterial


func _init(newPalette: CCPalette, newCharacterSet: CharacterSet) -> void:
	palette = newPalette
	characterSet = newCharacterSet
	_material = ShaderMaterial.new()
	_material.shader = CONVERT_SHADER
	_material.set_shader_parameter("masks", CCFont.maskTexture)

	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var rect := ColorRect.new()
	rect.material = _material
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(rect)
	add_child(_viewport)


## Async: use `await converter.convertImage(...)`.
func convertImage(source: Image, width: int, height: int) -> CCCanvas:
	var scaled := source.duplicate() as Image
	if scaled.is_compressed():
		scaled.decompress()
	scaled.convert(Image.FORMAT_RGBA8)
	var shrinking := scaled.get_width() > width * PIXELS_W
	scaled.resize(width * PIXELS_W, height * PIXELS_H,
		Image.INTERPOLATE_LANCZOS if shrinking else Image.INTERPOLATE_BILINEAR)

	_material.set_shader_parameter("source", ImageTexture.create_from_image(scaled))
	_material.set_shader_parameter("allowed", _allowedTexture())
	_material.set_shader_parameter("palette", PackedColorArray(palette.colors))
	_material.set_shader_parameter("use_color", useColor)
	_material.set_shader_parameter("grid_size", Vector2i(width, height))
	_viewport.size = Vector2i(width, height)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var result := _viewport.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return CCCanvas.fromData(width, height, result.get_data())


func _allowedTexture() -> ImageTexture:
	var bytes := PackedByteArray()
	bytes.resize(256)
	for c in 256:
		bytes[c] = 255 if characterSet.isEnabled(c) else 0
	return ImageTexture.create_from_image(Image.create_from_data(256, 1, false, Image.FORMAT_R8, bytes))
