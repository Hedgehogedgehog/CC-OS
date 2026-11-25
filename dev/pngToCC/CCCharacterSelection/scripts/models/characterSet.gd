class_name CharacterSet
extends RefCounted
## Which of the 256 CC characters are enabled (used by the converter).
## A character list file is just the enabled bytes, like getChars.lua writes.

signal changed

var flags := PackedByteArray()


func _init() -> void:
	flags.resize(256)
	flags.fill(1)


func isEnabled(c: int) -> bool:
	return flags[c] == 1


func setEnabled(c: int, on: bool) -> void:
	var value := 1 if on else 0
	if flags[c] != value:
		flags[c] = value
		changed.emit()


func setRange(from: int, to: int, on: bool) -> void:
	for c in range(from, to + 1):
		flags[c] = 1 if on else 0
	changed.emit()


func setAll(on: bool) -> void:
	setRange(0, 255, on)


func invert() -> void:
	for c in 256:
		flags[c] = 1 - flags[c]
	changed.emit()


func count() -> int:
	return flags.count(1)


func copyFrom(other: CharacterSet) -> void:
	flags = other.flags.duplicate()
	changed.emit()


## Enables exactly the bytes found in `bytes`. An empty list enables everything.
func loadBytes(bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		flags.fill(1)
	else:
		flags.fill(0)
		for byte in bytes:
			flags[byte] = 1
	changed.emit()


func toBytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	for c in 256:
		if flags[c] == 1:
			bytes.append(c)
	return bytes


## Enabled characters, with space first so it wins ties for flat cells.
func enabledList() -> PackedInt32Array:
	var list := PackedInt32Array()
	if flags[32] == 1:
		list.append(32)
	for c in 256:
		if flags[c] == 1 and c != 32:
			list.append(c)
	if list.is_empty():
		list.append(32)
	return list
