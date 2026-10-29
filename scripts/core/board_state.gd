class_name BoardState
extends RefCounted
## Spielzustand eines Levels: welche Ranke liegt auf welchem Feld.
## Reine Logik ohne Darstellung, damit sie auch im Solver und in Tests läuft.

enum Step { NONE, GROW, RETRACT, BLOCKED_STONE, BLOCKED_VINE, BLOCKED_FINISHED, BLOCKED_COLOR, BLOCKED_STRAIGHT }

var level: LevelData
var paths: Array = []  # pro Startknospe ein Array[Vector2i], beginnt mit dem Startfeld
var occupant := PackedInt32Array()  # pro Feld: Index der Ranke oder -1 (Blüten und Kreuzungen bleiben -1)
var crossing_use: Array = []  # pro Kreuzung [waagrechte Ranke, senkrechte Ranke], -1 = frei


func _init(lv: LevelData) -> void:
	level = lv
	reset()


func reset() -> void:
	paths.clear()
	occupant.resize(level.width * level.height)
	occupant.fill(-1)
	crossing_use.clear()
	for k in level.crossings.size():
		crossing_use.append([-1, -1])
	for i in level.starts.size():
		var path: Array[Vector2i] = [level.starts[i]]
		paths.append(path)
		occupant[level.index(level.starts[i])] = i


## Ranke auf dem Feld oder -1. Auf einer Kreuzung zählt zuerst die Ranke,
## deren Spitze dort liegt.
func path_at(cell: Vector2i) -> int:
	var k := level.crossing_at(cell)
	if k < 0:
		return occupant[level.index(cell)] if level.in_bounds(cell) else -1
	for i in crossing_use[k]:
		if i >= 0 and tip(i) == cell:
			return i
	return crossing_use[k][0] if crossing_use[k][0] >= 0 else crossing_use[k][1]


func tip(i: int) -> Vector2i:
	return paths[i][-1]


func is_finished(i: int) -> bool:
	return level.is_goal(tip(i))


## Kürzt Ranke i so, dass `cell` ihre Spitze ist.
func truncate(i: int, cell: Vector2i) -> int:
	var path: Array = paths[i]
	var k := path.find(cell)
	var removed := 0
	if k < 0:
		return 0
	while path.size() > k + 1:
		_release(i, path.pop_back())
		removed += 1
	return removed


func _release(i: int, cell: Vector2i) -> void:
	var k := level.crossing_at(cell)
	if k < 0:
		occupant[level.index(cell)] = -1
		return
	var use: Array = crossing_use[k]
	for axis in 2:
		if use[axis] == i:
			use[axis] = -1


## Anzahl Ranken, die in einer Blüte enden.
func finished_count() -> int:
	var n := 0
	for i in paths.size():
		if is_finished(i):
			n += 1
	return n


## Versucht, Ranke i von ihrer Spitze auf das Nachbarfeld `target` zu bewegen.
## Eine Blüte gehört keiner Ranke allein: Jede Ranke kann von ihrer Seite
## hineinwachsen, endet dort aber. Eine Kreuzung wird von zwei
## verschiedenen Ranken ihrer Farben geradeaus durchquert, waagrecht und senkrecht.
func step(i: int, target: Vector2i) -> Step:
	var path: Array = paths[i]
	var t: Vector2i = path[-1]
	var dir := target - t
	if absi(dir.x) + absi(dir.y) != 1:
		return Step.NONE
	if path.size() >= 2 and path[-2] == target:
		path.pop_back()
		_release(i, t)
		return Step.RETRACT
	if level.is_goal(t):
		return Step.BLOCKED_FINISHED
	if level.crossing_at(t) >= 0 and t - path[-2] != dir:
		return Step.BLOCKED_STRAIGHT
	if not level.is_passable(target):
		return Step.BLOCKED_STONE
	if level.is_goal(target):
		path.append(target)
		return Step.GROW
	var k := level.crossing_at(target)
	if k >= 0:
		if not i in level.crossing_colors[k]:
			return Step.BLOCKED_COLOR
		var use: Array = crossing_use[k]
		var axis := 0 if dir.x != 0 else 1
		if use[axis] != -1 or use[1 - axis] == i:
			return Step.BLOCKED_VINE
		use[axis] = i
		path.append(target)
		return Step.GROW
	if occupant[level.index(target)] != -1:
		return Step.BLOCKED_VINE
	path.append(target)
	occupant[level.index(target)] = i
	return Step.GROW


## Freie Felder ohne Blüten; eine Kreuzung zählt als frei, bis sie zweimal durchquert ist.
func free_cell_count() -> int:
	var n := 0
	for idx in occupant.size():
		if occupant[idx] == -1 and level.cells[idx] in [LevelData.Cell.EMPTY, LevelData.Cell.START]:
			n += 1
	for use in crossing_use:
		if use[0] == -1 or use[1] == -1:
			n += 1
	return n


## Gewonnen: alle Felder bedeckt, alle Kreuzungen benutzt, jede Ranke endet in einer Blüte.
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
