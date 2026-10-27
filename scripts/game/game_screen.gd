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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_left", 20)
	top.add_theme_constant_override("margin_right", 20)
	top.add_theme_constant_override("margin_top", 52)
	root.add_child(top)
	var bar := HBoxContainer.new()
	top.add_child(bar)

	var back := IconButton.new(IconButton.Kind.BACK)
	back.tooltip_text = tr("Zum Lebensbaum")
	back.pressed.connect(back_requested.emit)
	bar.add_child(back)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 0)
	bar.add_child(titles)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	titles.add_child(_title)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_win_title.text = tr("Erblüht!")
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
	_board.load_level(lv)


func _on_reset() -> void:
	if not _board.is_won():
		_board.restart()


func _update_status() -> void:
	var lv := _board.level
	if lv == null:
		return
	var free := _board.state.free_cell_count()
	var waiting := 0
	for path in _board.state.paths:
		if path.size() < 2:
			waiting += 1
	var line := ""
	if free > 0:
		line = tr("Noch %d Felder frei") % free if free != 1 else tr("Noch 1 Feld frei")
	elif waiting > 0:
		line = tr("Jede Knospe muss wachsen")
	elif _board.state.path_at(lv.goal) == -1:
		line = tr("Eine Ranke muss die Blüte erreichen")
	_status.text = tr(lv.hint) + "\n" + line if lv.hint != "" else line


func _on_won() -> void:
	Progress.mark_solved(_board.level.id)
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
