class_name BoardView
extends Control
## Spielfeld: zeichnet Raster, Steine, Ranken und Effekte und setzt das
## Ziehen mit dem Finger ("Drag & Trace") in Spielzüge um.

signal changed  ## Der Spielzustand hat sich geändert.
signal won  ## Gewinn-Animation ist abgeschlossen.

const GROW_TIME := 0.12  # Zeit, bis die Ranke ein neues Feld erreicht
const LEAF_TIME := 0.4  # Zeit, bis die Blätter ausgewachsen sind
const SHAKE_TIME := 0.3
const WIN_TIME := 1.8

var level: LevelData
var state: BoardState

var _cell := 64.0
var _origin := Vector2.ZERO
var _time := 0.0
var _anim_until := 0.0
var _grown_at := {}  # Feldindex -> Zeitpunkt, an dem es bewachsen wurde
var _active := -1  # Ranke unter dem Finger
var _cursor := Vector2i(-1, -1)  # Feld, auf dem der Finger zuletzt war
var _moved := false
var _last_blocked := Vector2i(-1, -1)
var _shake_path := -1
var _shake_start := -10.0
var _particles: Array[Dictionary] = []
var _won := false
var _win_start := 0.0
var _cell_box := StyleBoxFlat.new()
var _board_box := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_board_box.bg_color = Art.SOIL
	_board_box.anti_aliasing = true
	_cell_box.anti_aliasing = true
	set_process(false)


func load_level(lv: LevelData) -> void:
	level = lv
	state = BoardState.new(lv)
	_grown_at.clear()
	_particles.clear()
	_won = false
	_active = -1
	_layout()
	changed.emit()


func restart() -> void:
	if level:
		load_level(level)


func is_won() -> bool:
	return _won


# --- Layout & Hilfen -------------------------------------------------------

func _layout() -> void:
	if level == null:
		return
	_cell = minf(minf(size.x / level.width, size.y / level.height), 150.0)
	_origin = (size - Vector2(level.width, level.height) * _cell) / 2.0
	_board_box.set_corner_radius_all(int(_cell * 0.22))
	_cell_box.set_corner_radius_all(int(_cell * 0.16))
	queue_redraw()


func _center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


func _cell_at(pos: Vector2) -> Vector2i:
	var p := (pos - _origin) / _cell
	return Vector2i(floori(p.x), floori(p.y))


func _progress(c: Vector2i, delay: float, duration: float) -> float:
	var t0: float = _grown_at.get(level.index(c), -100.0)
	return clampf((_time - t0 - delay) / duration, 0.0, 1.0)


func _animate_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _time + seconds)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.94
		p.life -= delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	queue_redraw()
	if _time > _anim_until and _particles.is_empty():
		set_process(false)


# --- Eingabe ---------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if level == null or _won:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _active >= 0:
		_drag(event.position)
		accept_event()


func _press(pos: Vector2) -> void:
	var c := _cell_at(pos)
	var i := state.path_at(c)
	if i < 0:
		return
	_active = i
	_cursor = c
	_moved = false
	_last_blocked = Vector2i(-1, -1)


## Im Modus „Keine Teilschlangen“ zieht sich eine Ranke ganz zurück, wenn der
## Finger sie loslässt, bevor sie in einer Blüte angekommen ist.
func _release() -> void:
	var i := _active
	_active = -1
	if i < 0 or not Progress.get_setting(Progress.NO_PARTIAL) or state.is_finished(i):
		return
	if state.truncate(i, level.starts[i]) > 0:
		Sound.retract(1)
		Haptics.bump()
		_animate_for(0.1)
		changed.emit()


func _drag(pos: Vector2) -> void:
	var target := _cell_at(pos).clamp(Vector2i.ZERO, Vector2i(level.width - 1, level.height - 1))
	var guard := 0
	while _cursor != target and guard < 64:
		guard += 1
		if not _moved:
			# Erst beim ersten Ziehen kürzen: ein blosses Antippen verändert nichts.
			_moved = true
			if state.truncate(_active, _cursor) > 0:
				Sound.retract(state.paths[_active].size())
				changed.emit()
		if not _step_towards(target):
			return
		if state.is_won():
			_start_win()
			return


## Ein Feld in Richtung `target`. Bei diagonaler Bewegung wird zuerst die
## grössere Achse versucht, dann die andere. Gibt false zurück, wenn blockiert.
func _step_towards(target: Vector2i) -> bool:
	var d := target - _cursor
	var dirs: Array[Vector2i] = []
	var horizontal := Vector2i(signi(d.x), 0)
	var vertical := Vector2i(0, signi(d.y))
	if absi(d.x) >= absi(d.y):
		dirs = [horizontal, vertical]
	else:
		dirs = [vertical, horizontal]
	var first_block := BoardState.Step.NONE
	var first_block_cell := _cursor
	for dir in dirs:
		if dir == Vector2i.ZERO:
			continue
		var next := _cursor + dir
		var result := state.step(_active, next)
		if result == BoardState.Step.GROW:
			_cursor = next
			_on_grow(next)
			return true
		if result == BoardState.Step.RETRACT:
			_cursor = next
			_on_retract()
			return true
		if first_block == BoardState.Step.NONE:
			first_block = result
			first_block_cell = next
	_on_blocked(first_block_cell, first_block == BoardState.Step.BLOCKED_STONE)
	return false


# --- Rückmeldungen ---------------------------------------------------------

func _on_grow(c: Vector2i) -> void:
	_last_blocked = Vector2i(-1, -1)
	_grown_at[level.index(c)] = _time
	Sound.grow(state.paths[_active].size())
	Haptics.tick()
	_spawn_particles(_center(c), Art.vine_color(_active).lightened(0.3), 5)
	if level.is_goal(c):
		Sound.goal_reached()
		_spawn_particles(_center(c), Art.GOAL_LIGHT, 10)
	_animate_for(LEAF_TIME + 0.2)
	changed.emit()


func _on_retract() -> void:
	_last_blocked = Vector2i(-1, -1)
	Sound.retract(state.paths[_active].size())
	Haptics.tick()
	_animate_for(0.1)
	changed.emit()


func _on_blocked(c: Vector2i, is_stone: bool) -> void:
	if c == _last_blocked:
		return  # nicht bei jeder Fingerbewegung erneut klopfen
	_last_blocked = c
	_shake_path = _active
	_shake_start = _time
	if is_stone:
		Sound.block()
	Haptics.bump()
	_animate_for(SHAKE_TIME)


func _spawn_particles(at: Vector2, color: Color, count: int) -> void:
	for k in count:
		var life := randf_range(0.4, 0.8)
		_particles.append({
			"pos": at + Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)) * _cell,
			"vel": Vector2(randf_range(-1.0, 1.0), randf_range(-1.6, -0.4)) * _cell * 0.9,
			"life": life,
			"max": life,
			"size": randf_range(0.03, 0.06) * _cell,
			"color": color,
		})


func _start_win() -> void:
	_won = true
	_active = -1
	_win_start = _time
	Sound.win()
	Haptics.success()
	_animate_for(WIN_TIME + 1.5)
	var lv := level
	get_tree().create_timer(WIN_TIME).timeout.connect(func():
		if level == lv and _won:
			won.emit())


# --- Zeichnen --------------------------------------------------------------

func _draw() -> void:
	if level == null:
		return
	var board := Rect2(_origin, Vector2(level.width, level.height) * _cell)
	draw_style_box(_board_box, board.grow(_cell * 0.1))

	for y in level.height:
		for x in level.width:
			_draw_cell(Vector2i(x, y))
	for i in state.paths.size():
		_draw_vine(i)
	for i in level.starts.size():
		_draw_start(i)
	for g in level.goals.size():
		_draw_goal(g)
	if _won:
		_draw_win()
	for p in _particles:
		var a: float = p.life / p.max
		draw_circle(p.pos, p.size * (0.5 + a * 0.5), Color(p.color, a), true, -1.0, true)


func _draw_cell(c: Vector2i) -> void:
	var rect := Rect2(_origin + Vector2(c) * _cell, Vector2.ONE * _cell).grow(-_cell * 0.045)
	if level.cell_at(c) == LevelData.Cell.STONE:
		Art.draw_stone(self, _center(c), _cell * 0.36, c.x * 31 + c.y * 17 + 3)
		return
	var k := level.crossing_at(c)
	if k >= 0:
		_draw_crossing(k, rect)
		return
	var owner_idx := state.path_at(c)
	var color := Art.CELL
	if owner_idx >= 0:
		color = Art.CELL.lerp(Art.vine_color(owner_idx).lightened(0.55), 0.55 * _progress(c, 0.0, LEAF_TIME))
	_cell_box.bg_color = color
	draw_style_box(_cell_box, rect)
	if owner_idx < 0 and level.cell_at(c) == LevelData.Cell.EMPTY:
		draw_circle(_center(c), _cell * 0.05, Art.CELL_EDGE, true, -1.0, true)


func _shake_offset(i: int) -> Vector2:
	var t := _time - _shake_start
	if i != _shake_path or t > SHAKE_TIME:
		return Vector2.ZERO
	return Vector2(sin(t * 70.0), cos(t * 55.0) * 0.5) * _cell * 0.06 * (1.0 - t / SHAKE_TIME)


func _draw_vine(i: int) -> void:
	var path: Array = state.paths[i]
	if path.size() < 2:
		return
	var color := Art.vine_color(i)
	var width := _cell * 0.15
	var pts := PackedVector2Array()
	for k in path.size():
		var p := _center(path[k])
		if k == path.size() - 1:
			p = _center(path[k - 1]).lerp(p, _progress(path[k], 0.0, GROW_TIME)) + _shake_offset(i)
		pts.append(p)

	for k in range(1, path.size()):
		var grow := _progress(path[k], 0.05, LEAF_TIME)
		if grow <= 0.0:
			continue
		var a := _center(path[k - 1])
		var b := _center(path[k])
		var side := 1.0 if k % 2 == 0 else -1.0
		var leaf_len := _cell * 0.3 * ease(grow, 0.4)
		Art.draw_leaf(self, a.lerp(b, 0.55), (b - a).angle() + side * 0.85, leaf_len, color.lightened(0.18))

	draw_polyline(pts, color, width, true)
	for p in pts:
		draw_circle(p, width / 2.0, color, true, -1.0, true)
	if not level.is_goal(path[-1]):
		draw_circle(pts[-1], width * 1.05, color.lightened(0.3), true, -1.0, true)
		Art.draw_symbol(self, i, pts[-1], width * 0.55, color.darkened(0.25))


func _draw_start(i: int) -> void:
	var c := _center(level.starts[i])
	var color := Art.vine_color(i)
	var r := _cell * 0.36
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		draw_circle(c + Vector2(r * 0.62, 0).rotated(a), r * 0.42, color.lightened(0.35), true, -1.0, true)
	draw_circle(c, r * 0.72, color, true, -1.0, true)
	if i == _active:
		draw_arc(c, r * 1.12, 0, TAU, 40, Color(color, 0.6), _cell * 0.04, true)
	Art.draw_symbol(self, i, c, r * 0.42, Art.CREAM)


## Farbmarke einer Ranke (Farbe plus Symbol) für Kreuzungen.
func _draw_badge(i: int, at: Vector2) -> void:
	var r := _cell * 0.11
	draw_circle(at, r, Art.vine_color(i), true, -1.0, true)
	Art.draw_symbol(self, i, at, r * 0.6, Art.CREAM)


## Kreuzung: Kreuz auf dem Feld, die beiden Farbmarken in gegenüberliegenden Ecken.
func _draw_crossing(k: int, rect: Rect2) -> void:
	var c := _center(level.crossings[k])
	var use: Array = state.crossing_use[k]
	_cell_box.bg_color = Art.CELL.darkened(0.04) if use.has(-1) else Art.CELL.lerp(Art.GOAL_LIGHT, 0.4)
	draw_style_box(_cell_box, rect)
	var arm := _cell * 0.36
	var w := _cell * 0.16
	draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), Art.CELL_EDGE, w, true)
	draw_line(c - Vector2(0, arm), c + Vector2(0, arm), Art.CELL_EDGE, w, true)
	var colors: Array = level.crossing_colors[k]
	var corner := _cell * 0.3
	for n in colors.size():
		var s := -1.0 if n == 0 else 1.0
		_draw_badge(colors[n], c + Vector2(s, s) * corner)


func _draw_goal(g: int) -> void:
	var cell: Vector2i = level.goals[g]
	var c := _center(cell)
	var reached := false
	for i in state.paths.size():
		reached = reached or state.tip(i) == cell
	var open := _progress(cell, 0.05, 0.5) if reached else 0.0
	if open < 1.0:
		Art.draw_bud(self, c, _cell * 0.34 * (1.0 - open * 0.6), Art.GOAL)
	if open > 0.0:
		Art.draw_blossom(self, c, _cell * 0.44, Art.GOAL, ease(open, 0.5), open * 0.6)


func _draw_win() -> void:
	var t := _time - _win_start
	var center := _center(level.goals[0])
	var reach := Vector2(level.width, level.height).length() * _cell
	var radius := t / (WIN_TIME * 0.6) * reach
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			var owner_idx := state.path_at(c)
			if owner_idx < 0 or level.is_goal(c):
				continue
			var dist := _center(c).distance_to(center)
			var open := clampf((radius - dist) / (_cell * 1.2), 0.0, 1.0)
			if open > 0.0:
				var tint := Art.vine_color(owner_idx).lightened(0.45)
				Art.draw_blossom(self, _center(c) + Vector2(_cell * 0.18, -_cell * 0.18), _cell * 0.2, tint, ease(open, 0.5), float(x + y))
	var wave := clampf(1.0 - t / WIN_TIME, 0.0, 1.0)
	if wave > 0.0:
		draw_arc(center, radius, 0, TAU, 72, Color(1.0, 0.97, 0.8, 0.55 * wave), _cell * 0.6 * wave, true)
		draw_rect(Rect2(_origin, Vector2(level.width, level.height) * _cell), Color(1.0, 0.98, 0.85, 0.18 * sin(wave * PI)))
