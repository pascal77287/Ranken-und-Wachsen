class_name LevelSolver
extends RefCounted
## Tiefensuche über alle Rankenverläufe. Zählt Lösungen bis `limit`.
## Wird nur im Prüfwerkzeug verwendet, nicht im Spiel.
##
## Jede Ranke muss in der Ziel-Knospe enden. Daraus folgt: Jedes freie Feld
## liegt mitten in einer Ranke und braucht einen Vorgänger und einen Nachfolger.

var level: LevelData
var limit := 2
var node_limit := 5_000_000
var nodes := 0
var aborted := false
var solutions := 0
var first_solution: Array = []

var _occ := PackedInt32Array()  # Ziel bleibt -1
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
	if level.starts.size() <= 4:
		_extend(0)
	return solutions


func _extend(i: int) -> void:
	if solutions >= limit or aborted:
		return
	nodes += 1
	if nodes > node_limit:
		aborted = true
		return
	var path: Array = _paths[i]
	var t: Vector2i = path[-1]
	if t == level.goal:
		if i + 1 == level.starts.size():
			if _all_covered():
				solutions += 1
				if first_solution.is_empty():
					first_solution = _paths.map(func(p): return p.duplicate())
			return
		if _feasible(i + 1, _paths[i + 1][0]):
			_extend(i + 1)
		return
	for d in LevelData.NEIGHBORS:
		var n := t + d
		if not level.is_passable(n):
			continue
		if n == level.goal:
			path.append(n)
			_extend(i)
			path.pop_back()
			continue
		if _occ[level.index(n)] != -1:
			continue
		_occ[level.index(n)] = i
		path.append(n)
		if _locally_ok(n, i):
			_extend(i)
		path.pop_back()
		_occ[level.index(n)] = -1


func _all_covered() -> bool:
	for idx in _occ.size():
		if _occ[idx] == -1 and level.cells[idx] != LevelData.Cell.STONE and idx != level.index(level.goal):
			return false
	return true


## Ein freies Feld braucht mindestens einen möglichen Vorgänger (freier Nachbar,
## aktive Spitze oder ungenutzte Startknospe) und insgesamt zwei mögliche
## Anschlüsse (zusätzlich zählt das Ziel als Nachfolger).
func _has_two_links(cell: Vector2i, active: int, active_tip: Vector2i) -> bool:
	var entries := 0
	var goal := 0
	for d in LevelData.NEIGHBORS:
		var m := cell + d
		if not level.is_passable(m):
			continue
		if m == level.goal:
			goal = 1
			continue
		var o := _occ[level.index(m)]
		if o == -1 or (m == active_tip and o == active) or (o > active and _paths[o].size() == 1):
			entries += 1
	return entries >= 1 and entries + goal >= 2


## Prüft nach einem Schritt auf `n` die Nachbarfelder und die freien Ziel-Eingänge.
func _locally_ok(n: Vector2i, i: int) -> bool:
	for d in LevelData.NEIGHBORS:
		var m := n + d
		if m != level.goal and level.is_passable(m) and _occ[level.index(m)] == -1 and not _has_two_links(m, i, n):
			return false
	return _goal_entries_ok(i, n)


## Jede noch nicht fertige Ranke braucht einen eigenen Eingang zur Ziel-Knospe.
func _goal_entries_ok(active: int, active_tip: Vector2i) -> bool:
	var open := 0
	for d in LevelData.NEIGHBORS:
		var m := level.goal + d
		if not level.is_passable(m):
			continue
		var o := _occ[level.index(m)]
		if o == -1 or (m == active_tip and o == active) or (o > active and _paths[o].size() == 1):
			open += 1
	return open >= level.starts.size() - active


## Vor dem Start von Ranke `active`: alle freien Felder müssen anschliessbar sein.
func _feasible(active: int, active_tip: Vector2i) -> bool:
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if c != level.goal and level.is_passable(c) and _occ[level.index(c)] == -1 and not _has_two_links(c, active, active_tip):
				return false
	return _goal_entries_ok(active, active_tip)
