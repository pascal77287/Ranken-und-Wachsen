extends Control
## Wurzel der App: verwaltet Lebensbaum, Spielansicht, Einstellungen
## und die stufenlosen Zoom-Übergänge dazwischen.

const ZOOM_TIME := 0.5

var _tree := TreeMenu.new()
var _game := GameScreen.new()
var _settings := SettingsOverlay.new()
var _busy := false


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	add_child(_tree)
	add_child(_game)
	add_child(_settings)
	_game.visible = false

	_tree.level_selected.connect(_open_level)
	_tree.settings_requested.connect(_settings.open)
	_game.settings_requested.connect(_settings.open)
	_game.back_requested.connect(_back_to_tree)
	_game.next_requested.connect(_next_level)

	if "--capture" in OS.get_cmdline_user_args():
		add_child(load("res://tools/dev_capture.gd").new())


func _draw() -> void:
	Art.vertical_gradient(self, Rect2(Vector2.ZERO, size), Art.BG_TOP, Art.BG_BOTTOM)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settings.visible:
			_settings.close()
		elif _game.visible:
			_back_to_tree()
		else:
			get_tree().quit()


## Zoomt in die Knospe hinein und blendet das Spielfeld ein.
func _open_level(chapter: int, index: int) -> void:
	if _busy:
		return
	_busy = true
	_game.open_level(chapter, index)
	_tree.pivot_offset = _tree.bud_screen_position(chapter, index)
	_game.pivot_offset = _tree.pivot_offset
	_game.visible = true
	_game.scale = Vector2(0.15, 0.15)
	_game.modulate.a = 0.0

	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_tree, "scale", Vector2(5.0, 5.0), ZOOM_TIME)
	tw.tween_property(_tree, "modulate:a", 0.0, ZOOM_TIME * 0.8)
	tw.tween_property(_game, "scale", Vector2.ONE, ZOOM_TIME)
	tw.tween_property(_game, "modulate:a", 1.0, ZOOM_TIME * 0.7).set_delay(ZOOM_TIME * 0.3)
	tw.chain().tween_callback(func():
		_tree.visible = false
		_busy = false)


## Zoomt aus dem Spielfeld zurück zur Knospe im Lebensbaum.
func _back_to_tree() -> void:
	if _busy:
		return
	_busy = true
	_tree.visible = true
	_tree.scroll_to_level(Vector2i(_game.chapter, _game.index))
	_tree.pivot_offset = _tree.bud_screen_position(_game.chapter, _game.index)
	_game.pivot_offset = _tree.pivot_offset

	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_tree, "scale", Vector2.ONE, ZOOM_TIME)
	tw.tween_property(_tree, "modulate:a", 1.0, ZOOM_TIME * 0.7).set_delay(ZOOM_TIME * 0.3)
	tw.tween_property(_game, "scale", Vector2(0.15, 0.15), ZOOM_TIME)
	tw.tween_property(_game, "modulate:a", 0.0, ZOOM_TIME * 0.6)
	tw.chain().tween_callback(func():
		_game.visible = false
		_busy = false)


## Weiter zum nächsten Level: kurzes Ausblenden statt Zoom über den Baum.
func _next_level(chapter: int, index: int) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_game, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _game.open_level(chapter, index))
	tw.tween_property(_game, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _busy = false)
