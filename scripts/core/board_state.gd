class_name BoardState
extends RefCounted
## Spielzustand eines Levels: welche Ranke liegt auf welchem Feld.
## Reine Logik ohne Darstellung, damit sie auch im Solver und in Tests läuft.

enum Step { NONE, GROW, RETRACT, BLOCKED_STONE, BLOCKED_VINE, BLOCKED_FINISHED }

var level: LevelData
var paths: Array = []  # pro Startknospe ein Array[Vector2i], beginnt mit dem Startfeld
var occupant := PackedInt32Array()  # pro Feld: Index der Ranke oder -1 (Ziel bleibt immer -1)


func _init(lv: LevelData) -> void:
	level = lv
	reset()


func reset() -> void:
	paths.clear()
	occupant.resize(level.width * level.height)
	occupant.fill(-1)
	for i in level.starts.size():
		var path: Array[Vector2i] = [level.starts[i]]
		paths.append(path)
		occupant[level.index(level.starts[i])] = i


func path_at(cell: Vector2i) -> int:
	return occupant[level.index(cell)] if level.in_bounds(cell) else -1


func tip(i: int) -> Vector2i:
	return paths[i][-1]


func is_finished(i: int) -> bool:
	return tip(i) == level.goal


## Kürzt Ranke i so, dass `cell` ihre Spitze ist.
func truncate(i: int, cell: Vector2i) -> int:
	var path: Array = paths[i]
	var k := path.find(cell)
	var removed := 0
	if k < 0:
		return 0
	while path.size() > k + 1:
		occupant[level.index(path.pop_back())] = -1
		removed += 1
	return removed


## Anzahl Ranken, die in der Ziel-Knospe enden.
func finished_count() -> int:
	var n := 0
	for i in paths.size():
		if is_finished(i):
			n += 1
	return n


## Versucht, Ranke i von ihrer Spitze auf das Nachbarfeld `target` zu bewegen.
## Die Ziel-Knospe gehört keiner Ranke allein: Jede Ranke kann von ihrer Seite
## hineinwachsen, endet dort aber.
func step(i: int, target: Vector2i) -> Step:
	var path: Array = paths[i]
	var t: Vector2i = path[-1]
	if absi(target.x - t.x) + absi(target.y - t.y) != 1:
		return Step.NONE
	if path.size() >= 2 and path[-2] == target:
		path.pop_back()
		occupant[level.index(t)] = -1
		return Step.RETRACT
	if t == level.goal:
		return Step.BLOCKED_FINISHED
	if not level.is_passable(target):
		return Step.BLOCKED_STONE
	if occupant[level.index(target)] != -1:
		return Step.BLOCKED_VINE
	path.append(target)
	if target != level.goal:
		occupant[level.index(target)] = i
	return Step.GROW


## Freie Felder ohne die Ziel-Knospe.
func free_cell_count() -> int:
	var n := 0
	for idx in occupant.size():
		if occupant[idx] == -1 and level.cells[idx] != LevelData.Cell.STONE:
			n += 1
	return n - 1


## Gewonnen: alle Felder bedeckt und jede Ranke endet in der Ziel-Knospe.
func is_won() -> bool:
	return finished_count() == paths.size() and free_cell_count() == 0


## Spielt eine Lösung (Array von Pfaden) nach. Leerer String = gültig.
func apply_solution(solution: Array) -> String:
	reset()
	for i in solution.size():
		var path: Array = solution[i]
		for k in range(1, path.size()):
			var r := step(i, path[k])
			if r != Step.GROW:
				return "Ranke %d: Schritt %d nach %s nicht möglich (%s)" % [i + 1, k, path[k], Step.keys()[r]]
	if not is_won():
		return "Lösung erfüllt die Gewinnbedingung nicht (freie Felder: %d)" % free_cell_count()
	return ""
