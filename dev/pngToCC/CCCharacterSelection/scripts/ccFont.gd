extends Node
## Autoload "CCFont": the CC: Tweaked terminal font.
##
## The atlas is CraftOS-PC's hdfont.bmp, which is CC's term_font.png at 2x:
## 16 x 16 glyphs, each 12 x 18 px, inside 16 x 22 px cells starting at (2, 2).
## Glyph index == character byte (0-255), exactly like CC.

const ATLAS_PATH := "res://assets/cc_font.png"
const GLYPH_SIZE := Vector2i(12, 18)
const CELL_STRIDE := Vector2i(16, 22)
const ATLAS_ORIGIN := Vector2i(2, 2)
## Real CC resolution of one character cell (every 2x2 atlas pixels = one CC pixel).
const PIXELS_W := 6
const PIXELS_H := 9
const ASCENT := 14

var atlas: Texture2D
## Font for the UI, so every label and button is drawn in the CC font.
var font: FontFile
## For each char 0-255: indices (y * PIXELS_W + x) of its lit pixels at CC resolution.
var masks: Array[PackedInt32Array] = []
## The same masks as a 54 x 256 texture for the conversion shader.
var maskTexture: ImageTexture


func _init() -> void:
	atlas = load(ATLAS_PATH)
	var atlasImage := atlas.get_image()
	if atlasImage.is_compressed():
		atlasImage.decompress()
	atlasImage.convert(Image.FORMAT_RGBA8)
	_buildMasks(atlasImage)
	maskTexture = _buildMaskTexture()
	font = _buildFont(atlasImage)


## Source rectangle of character `c` inside the atlas texture.
func glyphRect(c: int) -> Rect2:
	var pos := ATLAS_ORIGIN + Vector2i(c & 15, c >> 4) * CELL_STRIDE
	return Rect2(Vector2(pos), Vector2(GLYPH_SIZE))


func isBlank(c: int) -> bool:
	return masks[c].is_empty()


func _buildMasks(atlasImage: Image) -> void:
	masks.clear()
	for c in 256:
		var origin := ATLAS_ORIGIN + Vector2i(c & 15, c >> 4) * CELL_STRIDE
		var lit := PackedInt32Array()
		for y in PIXELS_H:
			for x in PIXELS_W:
				var alpha := 0.0
				for dy in 2:
					for dx in 2:
						alpha += atlasImage.get_pixel(origin.x + x * 2 + dx, origin.y + y * 2 + dy).a
				if alpha >= 2.0:
					lit.append(y * PIXELS_W + x)
		masks.append(lit)


func _buildMaskTexture() -> ImageTexture:
	var pixelCount := PIXELS_W * PIXELS_H
	var bytes := PackedByteArray()
	bytes.resize(pixelCount * 256)
	bytes.fill(0)
	for c in 256:
		for p in masks[c]:
			bytes[c * pixelCount + p] = 255
	return ImageTexture.create_from_image(Image.create_from_data(pixelCount, 256, false, Image.FORMAT_R8, bytes))


func _buildFont(atlasImage: Image) -> FontFile:
	var newFont := FontFile.new()
	newFont.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	newFont.generate_mipmaps = false
	newFont.fixed_size = GLYPH_SIZE.y
	newFont.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	newFont.fallbacks = [ThemeDB.fallback_font]
	var cacheSize := Vector2i(GLYPH_SIZE.y, 0)
	newFont.set_texture_image(0, cacheSize, 0, atlasImage)
	newFont.set_cache_ascent(0, GLYPH_SIZE.y, ASCENT)
	newFont.set_cache_descent(0, GLYPH_SIZE.y, GLYPH_SIZE.y - ASCENT)
	for c in range(32, 256):
		newFont.set_glyph_advance(0, GLYPH_SIZE.y, c, Vector2(GLYPH_SIZE.x, 0))
		newFont.set_glyph_offset(0, cacheSize, c, Vector2(0, -ASCENT))
		newFont.set_glyph_size(0, cacheSize, c, Vector2(GLYPH_SIZE))
		newFont.set_glyph_uv_rect(0, cacheSize, c, glyphRect(c))
		newFont.set_glyph_texture_idx(0, cacheSize, c, 0)
	return newFont
