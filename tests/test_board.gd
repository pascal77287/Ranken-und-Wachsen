extends SceneTree
## Tests der Spielregeln (BoardState).
##
## Aufruf:
##   godot --headless --path . --script res://tests/test_board.gd

var _failures := 0


func _initialize() -> void:
	_test_grow_and_retract()
	_test_blocking()
	_test_goal_is_endpoint()
	_test_win_conditions()
	_test_truncate()
	_test_multiple_goals()
	_test_crossings()
	print("\n%s" % ("Alle Tests bestanden." if _failures == 0 else "%d Test(s) fehlgeschlagen." % _failures))
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   " + what)
	else:
		_failures += 1
		print("  FAIL " + what)


func _level(grid: Array, extra := {}) -> LevelData:
	var d := {"id": "t", "grid": grid, "solution": {}}
	d.merge(extra)
	return LevelData.from_dict(d)


func _test_grow_and_retract() -> void:
	print("Wachsen & Einziehen")
	var s := BoardState.new(_level(["1..Z"]))
	_check(s.step(0, Vector2i(1, 0)) == BoardState.Step.GROW, "wächst auf freies Feld")
	_check(s.step(0, Vector2i(2, 0)) == BoardState.Step.GROW, "wächst weiter")
	_check(s.step(0, Vector2i(1, 0)) == BoardState.Step.RETRACT, "zurückziehen zieht ein")
	_check(s.tip(0) == Vector2i(1, 0), "Spitze nach Einziehen korrekt")
	_check(s.path_at(Vector2i(2, 0)) == -1, "eingezogenes Feld ist wieder frei")
	_check(s.step(0, Vector2i(3, 1)) == BoardState.Step.NONE, "diagonal/nicht benachbart ignoriert")


func _test_blocking() -> void:
	print("Blockaden")
	var s := BoardState.new(_level(["1X.", "..2", "Z.."]))
	_check(s.step(0, Vector2i(1, 0)) == BoardState.Step.BLOCKED_STONE, "Stein blockiert")
	_check(s.step(0, Vector2i(-1, 0)) == BoardState.Step.BLOCKED_STONE, "Rand blockiert")
	s.step(1, Vector2i(1, 1))
	s.step(0, Vector2i(0, 1))
	_check(s.step(0, Vector2i(1, 1)) == BoardState.Step.BLOCKED_VINE, "andere Ranke blockiert")
	s.step(0, Vector2i(0, 2))
	s.reset()
	var t := BoardState.new(_level(["1..", "...", "..Z"]))
	for c in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		t.step(0, c)
	_check(t.step(0, Vector2i(0, 0)) == BoardState.Step.BLOCKED_VINE, "eigene Ranke blockiert (ausser Vorgänger)")


func _test_goal_is_endpoint() -> void:
	print("Ziel-Knospe")
	var s := BoardState.new(_level(["1Z."]))
	_check(s.step(0, Vector2i(1, 0)) == BoardState.Step.GROW, "Ziel kann betreten werden")
	_check(s.is_finished(0), "Ranke im Ziel ist beendet")
	_check(s.step(0, Vector2i(2, 0)) == BoardState.Step.BLOCKED_FINISHED, "kein Weiterwachsen durch das Ziel")
	_check(s.step(0, Vector2i(0, 0)) == BoardState.Step.RETRACT, "aus dem Ziel zurückziehen geht")


func _test_win_conditions() -> void:
	print("Gewinnbedingung")
	var lv := _level(["1..Z", "2..."])
	var s := BoardState.new(lv)
	for c in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]:
		s.step(0, c)
	_check(not s.is_won(), "nicht gewonnen: Felder frei")
	for c in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
		s.step(1, c)
	_check(s.free_cell_count() == 0, "alle Felder bedeckt")
	_check(not s.is_won(), "nicht gewonnen: Ranke 2 endet nicht in der Blüte")
	_check(s.step(1, Vector2i(3, 0)) == BoardState.Step.GROW, "zweite Ranke darf ebenfalls in die Blüte")
	_check(s.finished_count() == 2, "beide Ranken enden in der Blüte")
	_check(s.is_won(), "gewonnen: alles bedeckt, jede Ranke in der Blüte")
	s.step(1, Vector2i(3, 1))
	_check(s.is_finished(0), "Einziehen einer Ranke lässt die andere in der Blüte")

	var u := BoardState.new(_level(["1.Z", "2.."]))
	u.step(0, Vector2i(1, 0))
	u.step(0, Vector2i(1, 1))
	u.step(0, Vector2i(2, 1))
	u.step(0, Vector2i(2, 0))
	_check(u.free_cell_count() == 0, "alle Felder bedeckt")
	_check(not u.is_won(), "nicht gewonnen: Knospe 2 ist nicht gewachsen")

	var v := BoardState.new(_level(["1..", "Z.."]))
	v.step(0, Vector2i(1, 0))
	_check(not v.is_won(), "nicht gewonnen: Ziel nicht erreicht")


func _test_truncate() -> void:
	print("Kürzen")
	var s := BoardState.new(_level(["1...Z"]))
	for x in [1, 2, 3]:
		s.step(0, Vector2i(x, 0))
	_check(s.truncate(0, Vector2i(1, 0)) == 2, "Kürzen entfernt Felder hinter dem Punkt")
	_check(s.tip(0) == Vector2i(1, 0), "neue Spitze")
	_check(s.free_cell_count() == 2, "Felder wieder frei (ohne Ziel)")


func _test_multiple_goals() -> void:
	print("Mehrere Blüten")
	var lv := _level(["1.Z", "2.Z"])
	_check(lv.errors.is_empty(), "Level mit zwei Blüten ist gültig")
	var s := BoardState.new(lv)
	s.step(0, Vector2i(1, 0))
	_check(s.step(0, Vector2i(2, 0)) == BoardState.Step.GROW, "Ranke 1 endet in der oberen Blüte")
	s.step(1, Vector2i(1, 1))
	_check(s.step(1, Vector2i(2, 1)) == BoardState.Step.GROW, "Ranke 2 endet in der unteren Blüte")
	_check(s.is_won(), "gewonnen, obwohl jede Blüte nur eine Ranke hat")
	var t := BoardState.new(_level(["1Z.", ".2Z"]))
	t.step(1, Vector2i(1, 0))
	_check(t.is_finished(1), "jede Ranke darf in jede Blüte")
	var u := BoardState.new(_level(["1.Z", "2.Z"]))
	u.step(0, Vector2i(1, 0))
	u.step(0, Vector2i(2, 0))
	u.step(1, Vector2i(1, 1))
	_check(u.closed_goal_count() == 1, "untere Blüte noch geschlossen")
	var v := BoardState.new(_level(["1..", "2.Z", "..Z"]))
	for c in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)]:
		v.step(0, c)
	for c in [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1)]:
		v.step(1, c)
	_check(v.free_cell_count() == 0 and v.finished_count() == 1, "alles bedeckt, Ranke 2 noch offen")
	_check(v.step(1, Vector2i(2, 1)) == BoardState.Step.GROW, "Ranke 2 darf in dieselbe Blüte")
	_check(not v.is_won(), "nicht gewonnen: eine Blüte ist nicht erblüht")
	_check(not _level(["1.Z", "..Z"]).errors.is_empty(), "weniger Ranken als Blüten ist ein Fehler")
	_check(not _level(["1Z.Z.Z.Z"]).errors.is_empty(), "höchstens 3 Blüten")
	_check(not _level(["12345", "Z...."]).errors.is_empty(), "eine Blüte nimmt höchstens 4 Ranken auf")


func _test_crossings() -> void:
	print("Kreuzungen")
	var lv := _level([".1.", "2a.", ".Z."], {"crossings": {"a": "12"}})
	_check(lv.errors.is_empty(), "Level mit Kreuzung ist gültig")
	var s := BoardState.new(lv)
	_check(s.step(1, Vector2i(1, 1)) == BoardState.Step.GROW, "waagrecht auf die Kreuzung")
	_check(s.step(1, Vector2i(1, 2)) == BoardState.Step.BLOCKED_STRAIGHT, "auf der Kreuzung nicht abbiegen")
	_check(s.step(1, Vector2i(2, 1)) == BoardState.Step.GROW, "geradeaus weiter")
	_check(s.step(0, Vector2i(1, 1)) == BoardState.Step.GROW, "zweite Ranke senkrecht über die Kreuzung")
	_check(s.free_cell_count() == 4, "Kreuzung ist nach zwei Durchgängen bedeckt")
	_check(s.step(0, Vector2i(1, 0)) == BoardState.Step.RETRACT, "zurückziehen gibt die Kreuzung frei")
	_check(s.crossing_use[0] == [1, -1], "nur die senkrechte Spur ist wieder frei")

	var t := BoardState.new(_level(["2..", "1a.", "...", ".Z."], {"crossings": {"a": "12"}}))
	t.step(0, Vector2i(1, 1))
	t.step(0, Vector2i(2, 1))
	t.step(0, Vector2i(2, 0))
	t.step(0, Vector2i(1, 0))
	_check(t.step(0, Vector2i(1, 1)) == BoardState.Step.BLOCKED_VINE, "eine Ranke kreuzt sich nicht selbst")
	var u := BoardState.new(_level(["13.", ".a.", ".Z2"], {"crossings": {"a": "12"}}))
	_check(u.step(2, Vector2i(1, 1)) == BoardState.Step.BLOCKED_COLOR, "Kreuzung nur für ihre Farben")
