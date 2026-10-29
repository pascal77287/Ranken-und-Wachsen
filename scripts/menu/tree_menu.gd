class_name TreeMenu
extends Control
## Hauptmenü "Der Lebensbaum": ein nach oben wachsender Baum, der vertikal
## gescrollt wird. Kapitel sind Abschnitte des Stamms, Level sind Knospen an Zweigen.

signal level_selected(chapter: int, index: int)
signal settings_requested

const LEVEL_SPACING := 150.0
const CHAPTER_GAP := 200.0
const BOTTOM_MARGIN := 320.0
const TOP_MARGIN := 300.0
const BUD_RADIUS := 34.0
const TAP_SLOP := 14.0

var _height := 0.0
var _scroll := 0.0  # Baum-y-Koordinate am oberen Bildschirmrand
var _velocity := 0.0
var _dragging := false
var _press_pos := Vector2.ZERO
var _last_y := 0.0
var _moved_far := false
var _time := 0.0
var _buds: Array[Dictionary] = []  # {chapter, index, pos (Baumkoordinaten), side}
var _chapter_spans: Array[Vector2] = []  # pro Kapitel: (y_unten, y_oben)
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	resized.connect(_build_layout)
	Progress.changed.connect(queue_redraw)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))

	var settings := IconButton.new(IconButton.Kind.SETTINGS)
	settings.tooltip_text = tr("Einstellungen")
	settings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings.offset_left = -116
	settings.offset_right = -20
	settings.offset_top = 52
	settings.offset_bottom = 148
	settings.pressed.connect(settings_requested.emit)
	add_child(settings)
	_build_layout()


func _build_layout() -> void:
	_buds.clear()
	_chapter_spans.clear()
	var count := 0
	for c in LevelDB.chapters.size():
		count += LevelDB.chapters[c].levels.size()
	_height = BOTTOM_MARGIN + count * LEVEL_SPACING + LevelDB.chapters.size() * CHAPTER_GAP + TOP_MARGIN

	var y := _height - BOTTOM_MARGIN
	var n := 0
	for c in LevelDB.chapters.size():
		y -= CHAPTER_GAP
		var span_bottom := y + CHAPTER_GAP * 0.55
		for i in LevelDB.chapters[c].levels.size():
			var side := -1.0 if n % 2 == 0 else 1.0
			var tx := _trunk_x(y)
			_buds.append({
				"chapter": c, "index": i, "side": side,
				"pos": Vector2(tx + side * size.x * 0.28, y - 34.0),
				"base": Vector2(tx, y + 30.0),
			})
			y -= LEVEL_SPACING
			n += 1
		_chapter_spans.append(Vector2(span_bottom, y + LEVEL_SPACING * 0.4))
	scroll_to_level(LevelDB.first_unsolved())


## Scrollt so, dass das Level gut sichtbar ist (oder ganz nach unten).
func scroll_to_level(level: Vector2i) -> void:
	var target := _height
	for b in _buds:
		if Vector2i(b.chapter, b.index) == level:
			target = b.pos.y + size.y * 0.35
	_scroll = clampf(target - size.y, 0.0, maxf(0.0, _height - size.y))
	queue_redraw()


## Bildschirmposition einer Knospe (für den Zoom-Übergang).
func bud_screen_position(chapter: int, index: int) -> Vector2:
	for b in _buds:
		if b.chapter == chapter and b.index == index:
			return b.pos - Vector2(0, _scroll)
	return size / 2.0


func _trunk_x(y: float) -> float:
	return size.x * 0.5 + sin(y * 0.0045) * size.x * 0.07


func _trunk_width(y: float) -> float:
	return lerpf(30.0, 74.0, clampf(y / maxf(_height, 1.0), 0.0, 1.0))


# --- Eingabe (eigenes Scrollen mit Schwung) ----------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_by(-80.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_by(80.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_moved_far = false
				_press_pos = event.position
				_last_y = event.position.y
				_velocity = 0.0
			else:
				_dragging = false
				if not _moved_far:
					_tap(event.position)
				set_process(true)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var dy: float = event.position.y - _last_y
		_last_y = event.position.y
		if event.position.distance_to(_press_pos) > TAP_SLOP:
			_moved_far = true
		if _moved_far:
			_scroll_by(-dy)
			_velocity = -dy / maxf(get_process_delta_time(), 0.001)
		accept_event()


func _scroll_by(dy: float) -> void:
	_scroll = clampf(_scroll + dy, 0.0, maxf(0.0, _height - size.y))
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not _dragging and absf(_velocity) > 5.0:
		_scroll_by(_velocity * delta)
		_velocity *= pow(0.04, delta)
	queue_redraw()


func _tap(pos: Vector2) -> void:
	var p := pos + Vector2(0, _scroll)
	for b in _buds:
		if p.distance_to(b.pos) < BUD_RADIUS * 1.6:
			Sound.click()
			level_selected.emit(b.chapter, b.index)
			return


# --- Zeichnen ----------------------------------------------------------------

func _draw() -> void:
	Art.vertical_gradient(self, Rect2(Vector2.ZERO, size), Color("#e8f1f0"), Art.BG_TOP)
	draw_set_transform(Vector2(0, -_scroll))
	var view_top := _scroll - 200.0
	var view_bottom := _scroll + size.y + 200.0

	_draw_ground()
	_draw_chapter_glow()
	_draw_trunk(view_top, view_bottom)
	var next := LevelDB.first_unsolved()
	for b in _buds:
		if b.pos.y < view_top or b.pos.y > view_bottom:
			continue
		_draw_twig_and_bud(b, Vector2i(b.chapter, b.index) == next)
	_draw_chapter_signs()
	_draw_crown()
	draw_set_transform(Vector2.ZERO)

	var sky := Color("#e8f1f0")
	draw_rect(Rect2(0, 0, size.x, 150), sky)
	Art.vertical_gradient(self, Rect2(0, 150, size.x, 70), sky, Color(sky, 0.0))
	draw_string(_font, Vector2(36, 118), tr("Wachsen & Verflechten"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 170, 44, Art.INK)


func _draw_ground() -> void:
	var y := _height - BOTTOM_MARGIN * 0.55
	var pts := PackedVector2Array()
	for k in 25:
		var x := size.x * k / 24.0
		pts.append(Vector2(x, y + sin(k * 0.7) * 10.0 - 30.0 * sin(PI * k / 24.0)))
	pts.append(Vector2(size.x, _height + 400.0))
	pts.append(Vector2(0, _height + 400.0))
	draw_colored_polygon(pts, Color("#a9c98a"))
	var tx := _trunk_x(y)
	for s in [-1.0, 1.0]:
		for k in 3:
			var a := Vector2(tx + s * 20.0, y - 10.0)
			var b := a + Vector2(s * (50.0 + k * 40.0), 30.0 + k * 22.0)
			draw_line(a, b, Art.BARK_DARK, 10.0 - k * 2.0, true)


func _draw_trunk(view_top: float, view_bottom: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var y_start := _height - BOTTOM_MARGIN * 0.5
	var y_end := TOP_MARGIN * 0.6
	var y := y_start
	while y > y_end - 20.0:
		var x := _trunk_x(y)
		var w := _trunk_width(y)
		left.append(Vector2(x - w / 2.0, y))
		right.append(Vector2(x + w / 2.0, y))
		y -= 24.0
	right.reverse()
	draw_colored_polygon(left + right, Art.BARK)
	var line := PackedVector2Array()
	y = y_start
	while y > y_end:
		line.append(Vector2(_trunk_x(y) - _trunk_width(y) * 0.18, y))
		y -= 24.0
	draw_polyline(line, Art.BARK_DARK, 5.0, true)


func _draw_twig_and_bud(b: Dictionary, is_next: bool) -> void:
	var chapter: Dictionary = LevelDB.chapters[b.chapter]
	var lv: LevelData = chapter.levels[b.index]
	var solved := Progress.is_solved(lv.id)
	var complete := LevelDB.is_chapter_complete(b.chapter)
	var base: Vector2 = b.base
	var tip: Vector2 = b.pos
	var mid := base.lerp(tip, 0.5) + Vector2(0, -36.0)
	var twig := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		twig.append(base.lerp(mid, t).lerp(mid.lerp(tip, t), t))
	var twig_color := Art.BARK.lerp(chapter.color, 0.45) if complete else Art.BARK
	draw_polyline(twig, twig_color, 11.0, true)
	var leaf_color: Color = chapter.color if solved else Art.LEAF.lerp(Art.STONE_LIGHT, 0.35)
	Art.draw_leaf(self, twig[5], (twig[6] - twig[4]).angle() - 0.9 * b.side, 34.0, leaf_color)
	Art.draw_leaf(self, twig[9], (twig[10] - twig[8]).angle() + 0.9 * b.side, 28.0, leaf_color.darkened(0.08))

	if is_next:
		var pulse := 0.5 + 0.5 * sin(_time * 2.4)
		draw_circle(tip, BUD_RADIUS * (1.35 + 0.15 * pulse), Color(1.0, 0.96, 0.75, 0.35 + 0.25 * pulse), true, -1.0, true)
	if Progress.is_solved_hard(lv.id):
		draw_circle(tip, BUD_RADIUS * 1.35, Color(Art.GOLD, 0.25), true, -1.0, true)
		Art.draw_blossom(self, tip, BUD_RADIUS * 1.2, Art.GOLD, 1.0, b.index * 0.4)
	elif solved:
		var petal: Color = chapter.color.lightened(0.35) if complete else Art.GOAL
		Art.draw_blossom(self, tip, BUD_RADIUS * 1.2, petal, 1.0, b.index * 0.4)
	else:
		Art.draw_bud(self, tip, BUD_RADIUS * 0.85, Art.GOAL.lerp(chapter.color, 0.25))
	draw_string(_font, tip + Vector2(-60, BUD_RADIUS + 34.0), str(b.index + 1), HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Art.INK_SOFT)


func _draw_chapter_glow() -> void:
	for c in _chapter_spans.size():
		if not LevelDB.is_chapter_complete(c):
			continue
		var span := _chapter_spans[c]
		var color: Color = LevelDB.chapters[c].color
		var rect := Rect2(0, span.y, size.x, span.x - span.y)
		var glow := 0.16 + 0.05 * sin(_time * 1.5)
		Art.vertical_gradient(self, rect, Color(color, 0.0), Color(color, glow))


func _draw_chapter_signs() -> void:
	for c in _chapter_spans.size():
		var y := _chapter_spans[c].x - 40.0
		var x := _trunk_x(y)
		var name_text := tr(LevelDB.chapters[c].name)
		var w := _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 56.0
		var rect := Rect2(x - w / 2.0, y - 34.0, w, 64.0)
		draw_line(Vector2(x - w * 0.3, rect.position.y), Vector2(x - w * 0.3, rect.position.y - 26.0), Art.WOOD_DARK, 4.0, true)
		draw_line(Vector2(x + w * 0.3, rect.position.y), Vector2(x + w * 0.3, rect.position.y - 26.0), Art.WOOD_DARK, 4.0, true)
		var box := StyleBoxFlat.new()
		box.bg_color = Art.WOOD
		box.border_color = Art.WOOD_DARK
		box.set_border_width_all(4)
		box.set_corner_radius_all(16)
		box.anti_aliasing = true
		draw_style_box(box, rect)
		draw_string(_font, Vector2(rect.position.x, y + 10.0), name_text, HORIZONTAL_ALIGNMENT_CENTER, w, 30, Art.CREAM)


func _draw_crown() -> void:
	var y := TOP_MARGIN * 0.6
	var x := _trunk_x(y)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 14:
		var a := rng.randf_range(-PI, 0.0)
		var p := Vector2(x, y) + Vector2(cos(a) * rng.randf_range(20, 150), sin(a) * rng.randf_range(10, 90))
		draw_circle(p, rng.randf_range(34, 60), Art.LEAF.lerp(Color("#a9c98a"), rng.randf()), true, -1.0, true)
