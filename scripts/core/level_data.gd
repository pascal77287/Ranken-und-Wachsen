class_name LevelData
extends RefCounted
## Unveränderliche Beschreibung eines Levels, geladen aus JSON.
##
## Rasterzeichen: "." leer, "X" Stein, "Z" Ziel-Knospe, "1".."9" Startknospen.
## Die Lösung ist pro Startknospe eine Folge von Richtungen (U, D, L, R).

enum Cell { EMPTY, STONE, START, GOAL }

const DIRS := {
	"U": Vector2i(0, -1),
	"D": Vector2i(0, 1),
	"L": Vector2i(-1, 0),
	"R": Vector2i(1, 0),
}
const NEIGHBORS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var id := ""
var name := ""
var hint := ""
var width := 0
var height := 0
var cells := PackedInt32Array()
var starts: Array[Vector2i] = []  # Index i = Ranke Nummer i + 1
var goal := Vector2i(-1, -1)
var solution: Array = []  # pro Start ein Array[Vector2i] inkl. Startfeld
var errors := PackedStringArray()


static func from_dict(d: Dictionary) -> LevelData:
	var lv := LevelData.new()
	lv.id = str(d.get("id", ""))
	lv.name = str(d.get("name", ""))
	lv.hint = str(d.get("hint", ""))
	var rows: Array = d.get("grid", [])
	lv.height = rows.size()
	lv.width = 0 if rows.is_empty() else str(rows[0]).length()
	lv.cells.resize(lv.width * lv.height)

	var start_map := {}
	for y in lv.height:
		var row := str(rows[y])
		if row.length() != lv.width:
			lv.errors.append("Zeile %d hat Länge %d statt %d" % [y, row.length(), lv.width])
			continue
		for x in lv.width:
			var ch := row[x]
			var cell := Cell.EMPTY
			if ch == "X":
				cell = Cell.STONE
			elif ch == "Z":
				cell = Cell.GOAL
				if lv.goal != Vector2i(-1, -1):
					lv.errors.append("Mehr als eine Ziel-Knospe")
				lv.goal = Vector2i(x, y)
			elif ch.is_valid_int() and ch != "0":
				cell = Cell.START
				if start_map.has(ch.to_int()):
					lv.errors.append("Startknospe %s doppelt" % ch)
				start_map[ch.to_int()] = Vector2i(x, y)
			elif ch != ".":
				lv.errors.append("Unbekanntes Zeichen '%s' bei (%d,%d)" % [ch, x, y])
			lv.cells[y * lv.width + x] = cell

	for n in range(1, start_map.size() + 1):
		if start_map.has(n):
			lv.starts.append(start_map[n])
		else:
			lv.errors.append("Startknospen müssen lückenlos ab 1 nummeriert sein")
	if lv.starts.is_empty():
		lv.errors.append("Keine Startknospe")
	if lv.goal == Vector2i(-1, -1):
		lv.errors.append("Keine Ziel-Knospe")

	var sol: Dictionary = d.get("solution", {})
	for i in lv.starts.size():
		var path: Array[Vector2i] = [lv.starts[i]]
		for m in str(sol.get(str(i + 1), "")):
			if not DIRS.has(m):
				lv.errors.append("Ungültige Richtung '%s' in Lösung %d" % [m, i + 1])
				break
			path.append(path[-1] + DIRS[m])
		lv.solution.append(path)
	return lv


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func index(p: Vector2i) -> int:
	return p.y * width + p.x


func cell_at(p: Vector2i) -> int:
	return cells[index(p)] if in_bounds(p) else Cell.STONE


func is_passable(p: Vector2i) -> bool:
	return in_bounds(p) and cells[index(p)] != Cell.STONE
