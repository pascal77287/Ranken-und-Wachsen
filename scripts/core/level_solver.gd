class_name LevelSolver
extends RefCounted
## Tiefensuche über alle Rankenverläufe. Zählt Lösungen bis `limit`.
## Wird nur im Prüfwerkzeug verwendet, nicht im Spiel.

var level: LevelData
var limit := 2
var node_limit := 5_000_000
var nodes := 0
var aborted := false
var solutions := 0
var first_solution: Array = []

var _occ := PackedInt32Array()
var _paths: Array = []


func _init(lv: LevelData) -> void:
	level = lv


## Gibt die Anzahl gefundener Lösungen zurück (höchstens `limit`).
## Ist `aborted` danach true, wurde das Knotenlimit erreicht.
func count_solutions() -> int:
	_occ.resize(level.width * level.height)
	_occ.fill(-1)
	_paths.clear()
	for i in level.starts.size():
		_paths.append([level.starts[i]])
		_occ[level.index(level.starts[i])] = i
	_solve_from(0)
	return solutions


func _solve_from(i: int) -> void:
	if i == level.starts.size():
		if _all_covered():
			solutions += 1
			if first_solution.is_empty():
				first_solution = _paths.map(func(p): return p.duplicate())
		return
	if not _all_reachable(i):
		return
	_extend(i)


func _extend(i: int) -> void:
	if solutions >= limit or aborted:
		return
	nodes += 1
	if nodes > node_limit:
		aborted = true
		return
	var path: Array = _paths[i]
	var t: Vector2i = path[-1]
	if path.size() >= 2:
		_solve_from(i + 1)
		if t == level.goal:
			return
	for d in LevelData.NEIGHBORS:
		var n := t + d
		if not level.is_passable(n) or _occ[level.index(n)] != -1:
			continue
		_occ[level.index(n)] = i
		path.append(n)
		if not _isolates_neighbor(n, i):
			_extend(i)
		path.pop_back()
		_occ[level.index(n)] = -1


func _all_covered() -> bool:
	for idx in _occ.size():
		if _occ[idx] == -1 and level.cells[idx] != LevelData.Cell.STONE:
			return false
	return _occ[level.index(level.goal)] != -1


## Ein freies Feld kann nur von einem freien Nachbarn (nicht dem Ziel),
## der aktuellen Spitze oder einer noch ungenutzten Startknospe betreten werden.
func _can_be_entered(cell: Vector2i, active: int, active_tip: Vector2i) -> bool:
	for d in LevelData.NEIGHBORS:
		var m := cell + d
		if not level.is_passable(m):
			continue
		var o := _occ[level.index(m)]
		if o == -1 and m != level.goal:
			return true
		if m == active_tip and o == active:
			return true
		if o > active and _paths[o].size() == 1:
			return true
	return false


func _isolates_neighbor(n: Vector2i, i: int) -> bool:
	for d in LevelData.NEIGHBORS:
		var m := n + d
		if level.is_passable(m) and _occ[level.index(m)] == -1 and not _can_be_entered(m, i, n):
			return true
	return false


func _all_reachable(i: int) -> bool:
	var active_tip: Vector2i = _paths[i][-1]
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if level.is_passable(c) and _occ[level.index(c)] == -1 and not _can_be_entered(c, i, active_tip):
				return false
	return true
