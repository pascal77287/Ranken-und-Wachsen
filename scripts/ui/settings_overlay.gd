class_name SettingsOverlay
extends Control
## Unaufdringliches Holzschild mit Einstellungen (Klänge, Musik, Vibration,
## Schwierigkeit, Reset).

signal closed

var _reset_button := Button.new()
var _reset_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.17, 0.12, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size.x = 480
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("Einstellungen")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Art.CREAM)
	box.add_child(title)

	_add_toggle(box, tr("Klänge"), "sound")
	_add_toggle(box, tr("Musik"), "music")
	_add_toggle(box, tr("Vibration"), "haptics")
	_add_toggle(box, tr("Keine Teilschlangen"), Progress.NO_PARTIAL)
	var note := Label.new()
	note.text = tr("Ranken in einem Zug bis zur Blüte ziehen. Gelöste Level blühen golden.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 480
	note.add_theme_font_size_override("font_size", 24)
	note.add_theme_color_override("font_color", Art.CREAM.darkened(0.15))
	box.add_child(note)

	_reset_button.custom_minimum_size.y = 88
	_reset_button.pressed.connect(_on_reset)
	box.add_child(_reset_button)

	var close_button := Button.new()
	close_button.text = tr("Schliessen")
	close_button.custom_minimum_size.y = 88
	close_button.pressed.connect(close)
	box.add_child(close_button)


func _add_toggle(parent: Control, label: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = Progress.get_setting(key)
	toggle.custom_minimum_size.y = 80
	toggle.toggled.connect(func(on: bool): Progress.set_setting(key, on))
	parent.add_child(toggle)


func open() -> void:
	_reset_armed = false
	_reset_button.text = tr("Fortschritt zurücksetzen")
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(hide)
	closed.emit()


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = tr("Wirklich zurücksetzen?")
		return
	Progress.reset_progress()
	_reset_armed = false
	_reset_button.text = tr("Zurückgesetzt")
