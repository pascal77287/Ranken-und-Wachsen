class_name LevelData
extends RefCounted
## Unveränderliche Beschreibung eines Levels, geladen aus JSON.
##
## Rasterzeichen: "." leer, "X" Stein, "1".."6" Startknospen,
## "Z" Blüte (Ziel-Knospe, bis zu drei; jede Ranke darf in jeder Blüte enden),
## "a".."f" Kreuzungen, deren zwei Farben unter "crossings" stehen (z. B. {"a": "13"}).
## Die Lösung ist pro Startknospe eine Folge von Richtungen (U, D, L, R).

enum Cell { EMPTY, STONE, START, GOAL, CROSSING }

const DIRS := {
	"U": Vector2i(0, -1),
	"D": Vector2i(0, 1),
	"L": Vector2i(-1, 0),
	"R": Vector2i(1, 0),
}
const NEIGHBORS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const MAX_STARTS := 6
const MAX_GOALS := 3
const CROSSING_LETTERS := "abcdef"

var id := ""
var name := ""
var hint := ""
var width := 0
var height := 0
var cells := PackedInt32Array()
var starts: Array[Vector2i] = []  # Index i = Ranke Nummer i + 1
var goals: Array[Vector2i] = []
var crossings: Array[Vector2i] = []
var crossing_colors: Array = []  # pro Kreuzung ein Array[int] mit genau zwei Rankenindizes
var solution: Array = []  # pro Start ein Array[Vector2i] inkl. Startfeld
var errors := PackedStringArray()

var _crossing_index := {}  # Feldindex -> Index der Kreuzung


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
	var crossing_letters: Array[String] = []
	for y in lv.height:
		var row := str(rows[y])
		if row.length() != lv.width:
			lv.errors.append("Zeile %d hat Länge %d statt %d" % [y, row.length(), lv.width])
			continue
		for x in lv.width:
			var ch := row[x]
			var p := Vector2i(x, y)
			var cell := Cell.EMPTY
			if ch == "X":
				cell = Cell.STONE
			elif ch == "Z":
				cell = Cell.GOAL
				lv.goals.append(p)
			elif CROSSING_LETTERS.contains(ch):
				cell = Cell.CROSSING
				if ch in crossing_letters:
					lv.errors.append("Kreuzung %s doppelt" % ch)
				crossing_letters.append(ch)
				lv._crossing_index[y * lv.width + x] = lv.crossings.size()
				lv.crossings.append(p)
			elif ch.is_valid_int() and ch != "0":
				cell = Cell.START
				if start_map.has(ch.to_int()):
					lv.errors.append("Startknospe %s doppelt" % ch)
				start_map[ch.to_int()] = p
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
	if lv.starts.size() > MAX_STARTS:
		lv.errors.append("Höchstens %d Startknospen" % MAX_STARTS)
	if lv.goals.is_empty():
		lv.errors.append("Keine Ziel-Knospe")
	if lv.goals.size() > MAX_GOALS:
		lv.errors.append("Höchstens %d Blüten" % MAX_GOALS)
	if lv.starts.size() < lv.goals.size():
		lv.errors.append("Weniger Ranken als Blüten (jede Blüte muss erblühen)")
	if lv.starts.size() > 4 * lv.goals.size():
		lv.errors.append("Zu viele Startknospen (jede Ranke braucht eine Seite einer Blüte)")

	var crossing_spec: Dictionary = d.get("crossings", {})
	for letter in crossing_letters:
		var colors := lv._parse_colors(str(crossing_spec.get(letter, "")), "Kreuzung " + letter)
		if colors.size() != 2:
			lv.errors.append("Kreuzung %s braucht genau zwei verschiedene Farben" % letter)
		lv.crossing_colors.append(colors)

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


## "13" -> [0, 2]; meldet Ranken, die es nicht gibt.
func _parse_colors(spec: String, what: String) -> Array[int]:
	var result: Array[int] = []
	for ch in spec:
		var n := ch.to_int() if ch.is_valid_int() else 0
		if n < 1 or n > starts.size():
			errors.append("%s: Ranke '%s' gibt es nicht" % [what, ch])
		elif not (n - 1) in result:
			result.append(n - 1)
	return result


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func index(p: Vector2i) -> int:
	return p.y * width + p.x


func cell_at(p: Vector2i) -> int:
	return cells[index(p)] if in_bounds(p) else Cell.STONE


func is_passable(p: Vector2i) -> bool:
	return in_bounds(p) and cells[index(p)] != Cell.STONE


func is_goal(p: Vector2i) -> bool:
	return cell_at(p) == Cell.GOAL


## Index der Kreuzung auf Feld p oder -1.
func crossing_at(p: Vector2i) -> int:
	return _crossing_index.get(index(p), -1) if in_bounds(p) else -1
