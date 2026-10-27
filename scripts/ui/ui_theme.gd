class_name UiTheme
extends RefCounted
## Gemeinsames Theme für alle Oberflächen (Holzschild-Optik).


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 32

	t.set_stylebox("normal", "Button", _box(Art.WOOD, Art.WOOD_DARK))
	t.set_stylebox("hover", "Button", _box(Art.WOOD.lightened(0.06), Art.WOOD_DARK))
	t.set_stylebox("pressed", "Button", _box(Art.WOOD_DARK, Art.WOOD_DARK))
	t.set_stylebox("focus", "Button", _focus_ring())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", Art.CREAM)

	t.set_color("font_color", "Label", Art.INK)
	t.set_color("font_color", "CheckButton", Art.CREAM)
	t.set_color("font_hover_color", "CheckButton", Art.CREAM)
	t.set_color("font_pressed_color", "CheckButton", Art.CREAM)
	t.set_color("font_hover_pressed_color", "CheckButton", Art.CREAM)
	t.set_color("font_focus_color", "CheckButton", Art.CREAM)
	t.set_stylebox("focus", "CheckButton", _focus_ring())

	var panel := _box(Art.WOOD, Art.WOOD_DARK, 28)
	panel.set_content_margin_all(36)
	panel.shadow_color = Color(0, 0, 0, 0.18)
	panel.shadow_size = 18
	panel.shadow_offset = Vector2(0, 8)
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


static func _box(bg: Color, border: Color, radius := 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(4)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	s.anti_aliasing = true
	return s


## Sichtbarer Fokusrahmen für Tastatur- und Gamepad-Bedienung.
static func _focus_ring() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Art.BLOSSOM_CENTER
	s.set_border_width_all(5)
	s.set_corner_radius_all(26)
	s.set_expand_margin_all(6)
	s.anti_aliasing = true
	return s
