class_name CCPalette
extends RefCounted
## The 16 CC colors. Emits `changed` whenever any color changes.

signal changed

const HEX := "0123456789abcdef"
const NAMES: PackedStringArray = [
	"white", "orange", "magenta", "lightBlue", "yellow", "lime", "pink", "gray",
	"lightGray", "cyan", "purple", "blue", "brown", "green", "red", "black",
]
const DEFAULT_HEX: PackedStringArray = [
	"F0F0F0", "F2B233", "E57FD8", "99B2F2", "DEDE6C", "7FCC19", "F2B2CC", "4C4C4C",
	"999999", "4C99B2", "B266E5", "3366CC", "7F664C", "57A64E", "CC4C4C", "111111",
]

var colors: Array[Color] = []


func _init() -> void:
	colors = defaultColors()


static func defaultColors() -> Array[Color]:
	var out: Array[Color] = []
	for hex in DEFAULT_HEX:
		out.append(Color.html(hex))
	return out


func getColor(i: int) -> Color:
	return colors[i]


func setColor(i: int, color: Color) -> void:
	colors[i] = color
	changed.emit()


func setAll(newColors: Array[Color]) -> void:
	colors = newColors.duplicate()
	changed.emit()


func reset() -> void:
	setAll(defaultColors())


func isDefault() -> bool:
	for i in 16:
		if colors[i].to_html(false) != DEFAULT_HEX[i].to_lower():
			return false
	return true


## One line per color: "<hex digit> <rrggbb>". In CC:
##   term.setPaletteColor(2 ^ tonumber(d, 16), tonumber(rgb, 16))
func toText() -> String:
	var text := ""
	for i in 16:
		text += "%s %s\n" % [HEX[i], colors[i].to_html(false)]
	return text


## Reads text written by toText(). Returns false if nothing usable was found.
func loadText(text: String) -> bool:
	var newColors := defaultColors()
	var found := 0
	for line in text.split("\n", false):
		var parts := line.strip_edges().split(" ", false)
		if parts.size() < 2:
			continue
		var i := HEX.find(parts[0].to_lower())
		if i < 0 or not Color.html_is_valid(parts[1]):
			continue
		newColors[i] = Color.html(parts[1])
		found += 1
	if found == 0:
		return false
	setAll(newColors)
	return true


## Picks 16 colors that best represent the image (k-means), brightest first,
## so slot 0 stays the lightest and slot f the darkest.
func generateFromImage(source: Image) -> void:
	var sample := source.duplicate() as Image
	if sample.is_compressed():
		sample.decompress()
	sample.convert(Image.FORMAT_RGBA8)
	var biggest := maxi(sample.get_width(), sample.get_height())
	if biggest > 96:
		var scale := 96.0 / biggest
		sample.resize(maxi(1, int(sample.get_width() * scale)), maxi(1, int(sample.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
	var points: Array[Vector3] = []
	for y in sample.get_height():
		for x in sample.get_width():
			var pixel := sample.get_pixel(x, y)
			points.append(Vector3(pixel.r * pixel.a, pixel.g * pixel.a, pixel.b * pixel.a))

	var sorted := points.duplicate()
	sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _luminance(a) < _luminance(b))
	var centers: Array[Vector3] = []
	for i in 16:
		centers.append(sorted[int((i + 0.5) * sorted.size() / 16)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for _iteration in 12:
		var sums: Array[Vector3] = []
		sums.resize(16)
		sums.fill(Vector3.ZERO)
		var counts := PackedInt32Array()
		counts.resize(16)
		for point in points:
			var nearest := 0
			var nearestDistance := INF
			for k in 16:
				var distance := point.distance_squared_to(centers[k])
				if distance < nearestDistance:
					nearestDistance = distance
					nearest = k
			sums[nearest] += point
			counts[nearest] += 1
		for k in 16:
			if counts[k] > 0:
				centers[k] = sums[k] / counts[k]
			else:
				centers[k] = points[rng.randi_range(0, points.size() - 1)]
	centers.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _luminance(a) > _luminance(b))
	var newColors: Array[Color] = []
	for center in centers:
		newColors.append(Color(center.x, center.y, center.z))
	setAll(newColors)


static func _luminance(v: Vector3) -> float:
	return v.x * 0.299 + v.y * 0.587 + v.z * 0.114
