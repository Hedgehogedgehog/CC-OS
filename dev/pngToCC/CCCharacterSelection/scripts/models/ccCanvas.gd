class_name CCCanvas
extends RefCounted
## A grid of CC cells. Each cell is (char byte, color 0-15, highlight 0-15).
##
## "abc" file format: one line per row, 3 bytes per cell:
##   a = the character byte, b = color as a hex digit 0-f, c = highlight as a hex digit 0-f
## Rows end with "\n". Read it in CC with fs.open(path, "rb").

const HEX := "0123456789abcdef"

var width := 0
var height := 0
var chars := PackedByteArray()
var colors := PackedByteArray()
var highlights := PackedByteArray()


static func create(newWidth: int, newHeight: int, character := 32, color := 0, highlight := 15) -> CCCanvas:
	var canvas := CCCanvas.new()
	canvas.width = newWidth
	canvas.height = newHeight
	var count := newWidth * newHeight
	canvas.chars.resize(count)
	canvas.chars.fill(character)
	canvas.colors.resize(count)
	canvas.colors.fill(color)
	canvas.highlights.resize(count)
	canvas.highlights.fill(highlight)
	return canvas


func inBounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## Returns Vector3i(char, color, highlight).
func getCell(x: int, y: int) -> Vector3i:
	var i := y * width + x
	return Vector3i(chars[i], colors[i], highlights[i])


## Pass -1 for a channel to leave it unchanged.
func setCell(x: int, y: int, character: int, color: int, highlight: int) -> void:
	var i := y * width + x
	if character >= 0:
		chars[i] = character
	if color >= 0:
		colors[i] = color
	if highlight >= 0:
		highlights[i] = highlight


func fillAll(character: int, color: int, highlight: int) -> void:
	chars.fill(character)
	colors.fill(color)
	highlights.fill(highlight)


func copy() -> CCCanvas:
	var canvas := CCCanvas.new()
	canvas.width = width
	canvas.height = height
	canvas.chars = chars.duplicate()
	canvas.colors = colors.duplicate()
	canvas.highlights = highlights.duplicate()
	return canvas


## New canvas of the given size, keeping the overlapping top-left content.
func resized(newWidth: int, newHeight: int) -> CCCanvas:
	var canvas := CCCanvas.create(newWidth, newHeight)
	for y in mini(newHeight, height):
		for x in mini(newWidth, width):
			var cell := getCell(x, y)
			canvas.setCell(x, y, cell.x, cell.y, cell.z)
	return canvas


func toAbc() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(height * (width * 3 + 1))
	var o := 0
	for y in height:
		for x in width:
			var i := y * width + x
			out[o] = chars[i]
			out[o + 1] = HEX.unicode_at(colors[i])
			out[o + 2] = HEX.unicode_at(highlights[i])
			o += 3
		out[o] = 10
		o += 1
	return out


## term.blit style: for every row, a text line, a color line and a highlight line.
func toBlit() -> PackedByteArray:
	var out := PackedByteArray()
	for y in height:
		var start := y * width
		out.append_array(chars.slice(start, start + width))
		out.append(10)
		for x in width:
			out.append(HEX.unicode_at(colors[start + x]))
		out.append(10)
		for x in width:
			out.append(HEX.unicode_at(highlights[start + x]))
		out.append(10)
	return out


static func hexValue(byte: int) -> int:
	if byte >= 48 and byte <= 57:
		return byte - 48
	if byte >= 97 and byte <= 102:
		return byte - 87
	if byte >= 65 and byte <= 70:
		return byte - 55
	return -1


## Parses the abc format. Every row must be the same width. The width is found by
## checking where the "\n" row ends line up, so char 10 inside a row is still fine.
static func fromAbc(data: PackedByteArray) -> CCCanvas:
	if data.is_empty():
		return null
	var bytes := data
	if bytes[bytes.size() - 1] != 10:
		bytes = data.duplicate()
		bytes.append(10)
	var total := bytes.size()
	for rowWidth in range(1, total):
		var rowBytes := rowWidth * 3 + 1
		if rowBytes > total:
			break
		if total % rowBytes != 0:
			continue
		var rowCount := total / rowBytes
		if not _abcLayoutFits(bytes, rowWidth, rowCount):
			continue
		var canvas := CCCanvas.create(rowWidth, rowCount)
		for y in rowCount:
			for x in rowWidth:
				var o := y * rowBytes + x * 3
				canvas.setCell(x, y, bytes[o], hexValue(bytes[o + 1]), hexValue(bytes[o + 2]))
		return canvas
	return null


static func _abcLayoutFits(bytes: PackedByteArray, rowWidth: int, rowCount: int) -> bool:
	var rowBytes := rowWidth * 3 + 1
	for y in rowCount:
		var base := y * rowBytes
		if bytes[base + rowBytes - 1] != 10:
			return false
		for x in rowWidth:
			if hexValue(bytes[base + x * 3 + 1]) < 0 or hexValue(bytes[base + x * 3 + 2]) < 0:
				return false
	return true


static func fromBlit(data: PackedByteArray) -> CCCanvas:
	var lines: Array[PackedByteArray] = []
	var current := PackedByteArray()
	for byte in data:
		if byte == 10:
			lines.append(current)
			current = PackedByteArray()
		else:
			current.append(byte)
	if not current.is_empty():
		lines.append(current)
	for i in lines.size():
		if not lines[i].is_empty() and lines[i][lines[i].size() - 1] == 13:
			lines[i] = lines[i].slice(0, lines[i].size() - 1)
	if lines.is_empty() or lines.size() % 3 != 0:
		return null
	var rowCount := lines.size() / 3
	var rowWidth := 0
	for y in rowCount:
		var text := lines[y * 3]
		if lines[y * 3 + 1].size() != text.size() or lines[y * 3 + 2].size() != text.size():
			return null
		rowWidth = maxi(rowWidth, text.size())
	if rowWidth == 0:
		return null
	var canvas := CCCanvas.create(rowWidth, rowCount)
	for y in rowCount:
		var text := lines[y * 3]
		for x in text.size():
			var color := hexValue(lines[y * 3 + 1][x])
			var highlight := hexValue(lines[y * 3 + 2][x])
			if color < 0 or highlight < 0:
				return null
			canvas.setCell(x, y, text[x], color, highlight)
	return canvas
