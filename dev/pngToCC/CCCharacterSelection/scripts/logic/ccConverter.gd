class_name CCConverter
extends RefCounted
## Turns an image into CC cells.
##
## The image is resized so every cell covers 6 x 9 pixels (CC's real glyph size).
## For each cell we pick the best two palette colors, then try every enabled
## character (both ways round) and keep the one whose shape matches best.

const PIXELS_W := 6
const PIXELS_H := 9
const PIXEL_COUNT := PIXELS_W * PIXELS_H

var palette: CCPalette
var characterSet: CharacterSet
## Off = only palette slots 0 (white) and f (black) are used.
var useColor := true


func _init(newPalette: CCPalette, newCharacterSet: CharacterSet) -> void:
	palette = newPalette
	characterSet = newCharacterSet


func convertImage(source: Image, width: int, height: int) -> CCCanvas:
	var scaled := source.duplicate() as Image
	if scaled.is_compressed():
		scaled.decompress()
	scaled.convert(Image.FORMAT_RGBA8)
	var shrinking := scaled.get_width() > width * PIXELS_W
	scaled.resize(width * PIXELS_W, height * PIXELS_H,
		Image.INTERPOLATE_LANCZOS if shrinking else Image.INTERPOLATE_BILINEAR)

	var job := RowJob.new()
	job.pixels = scaled.get_data()
	job.pixelWidth = width * PIXELS_W
	job.width = width
	job.candidates = PackedInt32Array(range(16)) if useColor else PackedInt32Array([0, 15])
	for color in palette.colors:
		job.red.append(color.r8)
		job.green.append(color.g8)
		job.blue.append(color.b8)
	job.characters = characterSet.enabledList()
	job.masks = CCFont.masks
	job.outChars.resize(height)
	job.outColors.resize(height)
	job.outHighlights.resize(height)

	var taskId := WorkerThreadPool.add_group_task(job.run, height, -1, true, "CC convert")
	WorkerThreadPool.wait_for_group_task_completion(taskId)

	var canvas := CCCanvas.new()
	canvas.width = width
	canvas.height = height
	for y in height:
		canvas.chars.append_array(job.outChars[y])
		canvas.colors.append_array(job.outColors[y])
		canvas.highlights.append_array(job.outHighlights[y])
	return canvas


## Converts one row of cells. Rows run in parallel on the worker thread pool.
class RowJob:
	var pixels: PackedByteArray
	var pixelWidth := 0
	var width := 0
	var candidates := PackedInt32Array()
	var red := PackedFloat32Array()
	var green := PackedFloat32Array()
	var blue := PackedFloat32Array()
	var characters := PackedInt32Array()
	var masks: Array[PackedInt32Array]
	var outChars: Array = []
	var outColors: Array = []
	var outHighlights: Array = []

	func run(y: int) -> void:
		var rowChars := PackedByteArray()
		rowChars.resize(width)
		var rowColors := PackedByteArray()
		rowColors.resize(width)
		var rowHighlights := PackedByteArray()
		rowHighlights.resize(width)
		# distance[pixel * 16 + color] = how far that pixel is from that palette color
		var distance := PackedFloat32Array()
		distance.resize(PIXEL_COUNT * 16)
		var difference := PackedFloat32Array()
		difference.resize(PIXEL_COUNT)

		for x in width:
			_measureCell(x, y, distance)

			# Best single color for the whole cell.
			var first := candidates[0]
			var firstCost := INF
			for k in candidates:
				var cost := 0.0
				for p in PIXEL_COUNT:
					cost += distance[p * 16 + k]
				if cost < firstCost:
					firstCost = cost
					first = k
			# Best second color to go with it.
			var second := first
			var secondCost := firstCost
			var bestPairCost := INF
			for k in candidates:
				if k == first:
					continue
				var pairCost := 0.0
				var ownCost := 0.0
				for p in PIXEL_COUNT:
					var a := distance[p * 16 + first]
					var b := distance[p * 16 + k]
					pairCost += minf(a, b)
					ownCost += b
				if pairCost < bestPairCost:
					bestPairCost = pairCost
					second = k
					secondCost = ownCost

			# cost(char, color=first, highlight=second) = secondCost + sum of difference over lit pixels
			for p in PIXEL_COUNT:
				difference[p] = distance[p * 16 + first] - distance[p * 16 + second]
			var bestCost := INF
			var bestChar := characters[0]
			var bestColor := first
			var bestHighlight := second
			for c in characters:
				var litSum := 0.0
				for p in masks[c]:
					litSum += difference[p]
				var costA := secondCost + litSum
				if costA < bestCost:
					bestCost = costA
					bestChar = c
					bestColor = first
					bestHighlight = second
				var costB := firstCost - litSum
				if costB < bestCost:
					bestCost = costB
					bestChar = c
					bestColor = second
					bestHighlight = first
			rowChars[x] = bestChar
			rowColors[x] = bestColor
			rowHighlights[x] = bestHighlight
		outChars[y] = rowChars
		outColors[y] = rowColors
		outHighlights[y] = rowHighlights

	func _measureCell(x: int, y: int, distance: PackedFloat32Array) -> void:
		var p := 0
		for py in PIXELS_H:
			var i := ((y * PIXELS_H + py) * pixelWidth + x * PIXELS_W) * 4
			for _px in PIXELS_W:
				var alpha := pixels[i + 3] / 255.0
				var r := pixels[i] * alpha
				var g := pixels[i + 1] * alpha
				var b := pixels[i + 2] * alpha
				var o := p * 16
				for k in candidates:
					var dr := r - red[k]
					var dg := g - green[k]
					var db := b - blue[k]
					distance[o + k] = 2.0 * dr * dr + 4.0 * dg * dg + 3.0 * db * db
				i += 4
				p += 1
