extends Node
## Lädt alle Kapitel und Level aus res://levels/.

const INDEX_PATH := "res://levels/index.json"

## Jedes Kapitel: {id, name, color: Color, levels: Array[LevelData]}
var chapters: Array[Dictionary] = []


func _ready() -> void:
	var index: Dictionary = _load_json(INDEX_PATH)
	for path in index.get("chapters", []):
		var data: Dictionary = _load_json(path)
		var levels: Array[LevelData] = []
		for entry in data.get("levels", []):
			levels.append(LevelData.from_dict(entry))
		chapters.append({
			"id": str(data.get("id", "")),
			"name": str(data.get("name", "")),
			"color": Color.html(str(data.get("color", "#7dba5a"))),
			"levels": levels,
		})


func level(chapter: int, index: int) -> LevelData:
	return chapters[chapter].levels[index]


## Nächstes Level nach (chapter, index), über Kapitelgrenzen hinweg.
## Liefert Vector2i(-1, -1), wenn es kein weiteres gibt.
func next_of(chapter: int, index: int) -> Vector2i:
	if index + 1 < chapters[chapter].levels.size():
		return Vector2i(chapter, index + 1)
	if chapter + 1 < chapters.size():
		return Vector2i(chapter + 1, 0)
	return Vector2i(-1, -1)


func is_chapter_complete(chapter: int) -> bool:
	for lv: LevelData in chapters[chapter].levels:
		if not Progress.is_solved(lv.id):
			return false
	return true


## Erstes ungelöstes Level (für die Startposition im Lebensbaum).
func first_unsolved() -> Vector2i:
	for c in chapters.size():
		for i in chapters[c].levels.size():
			if not Progress.is_solved(chapters[c].levels[i].id):
				return Vector2i(c, i)
	return Vector2i(-1, -1)


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Konnte %s nicht lesen" % path)
	return {}
