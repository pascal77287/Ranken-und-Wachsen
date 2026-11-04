class_name GameScreen
extends Control
## Spielansicht: Kopfzeile, Spielfeld, Hinweistext und Gewinn-Overlay.

signal back_requested
signal settings_requested
signal next_requested(chapter: int, index: int)

var chapter := 0
var index := 0

var _board := BoardView.new()
var _title := Label.new()
var _subtitle := Label.new()
var _status := Label.new()
var _win_panel := PanelContainer.new()
var _win_title := Label.new()
var _next_button := Button.new()
var _top := MarginContainer.new()
var _buttons_width := 0.0  # Breite der vier Knöpfe samt Abständen in der Kopfzeile


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	_top.add_theme_constant_override("margin_left", 20)
	_top.add_theme_constant_override("margin_right", 20)
	root.add_child(_top)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	var bar := HBoxContainer.new()
	_top.add_child(bar)

	var back := IconButton.new(IconButton.Kind.BACK)
	back.tooltip_text = tr("Zum Lebensbaum")
	back.pressed.connect(back_requested.emit)
	bar.add_child(back)
	# Platzhalter, damit der Titel trotz zwei Buttons rechts mittig steht
	var spacer := Control.new()
	spacer.custom_minimum_size = back.custom_minimum_size
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 0)
	bar.add_child(titles)
	# Lange Namen dürfen die Kopfzeile nicht über den Bildschirm hinaus
	# verbreitern; die Schrift wird stattdessen kleiner (siehe _fit_titles).
	for label in [_title, _subtitle]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_size_override("font_size", 40)
	titles.add_child(_title)
	_subtitle.add_theme_font_size_override("font_size", 24)
	_subtitle.add_theme_color_override("font_color", Art.INK_SOFT)
	titles.add_child(_subtitle)

	var reset := IconButton.new(IconButton.Kind.RESET)
	reset.tooltip_text = tr("Neu beginnen")
	reset.pressed.connect(_on_reset)
	bar.add_child(reset)
	var settings := IconButton.new(IconButton.Kind.SETTINGS)
	settings.tooltip_text = tr("Einstellungen")
	settings.pressed.connect(settings_requested.emit)
	bar.add_child(settings)
	_buttons_width = 4.0 * back.custom_minimum_size.x + 4.0 * bar.get_theme_constant("separation")
	resized.connect(_fit_titles)

	var board_margin := MarginContainer.new()
	board_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		board_margin.add_theme_constant_override("margin_" + side, 36)
	root.add_child(board_margin)
	board_margin.add_child(_board)
	_board.changed.connect(_update_status)
	_board.won.connect(_on_won)

	var bottom := MarginContainer.new()
	bottom.add_theme_constant_override("margin_left", 40)
	bottom.add_theme_constant_override("margin_right", 40)
	bottom.add_theme_constant_override("margin_bottom", 72)
	bottom.custom_minimum_size.y = 190
	root.add_child(bottom)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Art.INK_SOFT)
	_status.add_theme_font_size_override("font_size", 28)
	bottom.add_child(_status)

	_build_win_panel()


func _apply_safe_area() -> void:
	_top.add_theme_constant_override("margin_top", int(UiTheme.safe_top(self)))


func _build_win_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_win_panel.visible = false
	center.add_child(_win_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	_win_panel.add_child(box)
	_win_title.text = tr("Geschafft!")
	_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_title.add_theme_font_size_override("font_size", 52)
	_win_title.add_theme_color_override("font_color", Art.CREAM)
	box.add_child(_win_title)
	_next_button.text = tr("Weiter")
	_next_button.custom_minimum_size = Vector2(360, 96)
	_next_button.pressed.connect(_on_next)
	box.add_child(_next_button)
	var tree_button := Button.new()
	tree_button.text = tr("Zum Lebensbaum")
	tree_button.custom_minimum_size = Vector2(360, 96)
	tree_button.pressed.connect(back_requested.emit)
	box.add_child(tree_button)


func open_level(chapter_index: int, level_index: int) -> void:
	chapter = chapter_index
	index = level_index
	var lv := LevelDB.level(chapter, index)
	_title.text = lv.name
	_subtitle.text = "%s · %s" % [tr(LevelDB.chapters[chapter].name), lv.id]
	_win_panel.visible = false
	_fit_titles()
	_board.load_level(lv)


## Verkleinert Titel und Untertitel, bis sie neben die Knöpfe passen.
func _fit_titles() -> void:
	var avail := size.x - 40.0 - _buttons_width
	_fit_label(_title, avail, 40, 26)
	_fit_label(_subtitle, avail, 24, 18)


func _fit_label(label: Label, avail: float, max_size: int, min_size: int) -> void:
	var font := label.get_theme_font("font")
	var font_size := max_size
	while font_size > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > avail:
		font_size -= 2
	label.add_theme_font_size_override("font_size", font_size)


func _on_reset() -> void:
	if not _board.is_won():
		_board.restart()


func _update_status() -> void:
	var lv := _board.level
	if lv == null:
		return
	var free := _board.state.free_cell_count()
	var missing := _board.state.paths.size() - _board.state.finished_count()
	var closed := _board.state.closed_goal_count()
	var line := ""
	if free > 0:
		line = tr("Noch %d Felder frei") % free if free != 1 else tr("Noch 1 Feld frei")
	elif missing > 0:
		if _board.state.paths.size() == 1:
			line = tr("Die Ranke muss die Blüte erreichen")
		else:
			line = tr("Noch %d Ranken bis zur Blüte") % missing if missing != 1 else tr("Noch 1 Ranke bis zur Blüte")
	elif closed > 0:
		line = tr("Noch %d Blüten ohne Ranke") % closed if closed != 1 else tr("Noch 1 Blüte ohne Ranke")
	_status.text = tr(lv.hint) + "\n" + line if lv.hint != "" else line


func _on_won() -> void:
	Progress.mark_solved(_board.level.id, Progress.get_setting(Progress.NO_PARTIAL))
	var next := LevelDB.next_of(chapter, index)
	_next_button.visible = next.x >= 0
	_win_panel.visible = true
	_win_panel.modulate.a = 0.0
	_win_panel.scale = Vector2(0.9, 0.9)
	_win_panel.pivot_offset = _win_panel.size / 2.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_win_panel, "modulate:a", 1.0, 0.35)
	tw.tween_property(_win_panel, "scale", Vector2.ONE, 0.35)
	if _next_button.visible:
		_next_button.grab_focus.call_deferred()


func _on_next() -> void:
	var next := LevelDB.next_of(chapter, index)
	if next.x >= 0:
		next_requested.emit(next.x, next.y)
