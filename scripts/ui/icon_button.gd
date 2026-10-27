class_name IconButton
extends Button
## Runder Knopf mit gezeichnetem Symbol (keine Schrift- oder Bildabhängigkeit).

enum Kind { BACK, RESET, SETTINGS }

var kind := Kind.BACK


func _init(icon_kind := Kind.BACK) -> void:
	kind = icon_kind
	flat = true
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pressed.connect(Sound.click)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	var bg := Art.CREAM.darkened(0.08) if get_draw_mode() == DRAW_PRESSED else Art.CREAM
	draw_circle(c, r, bg, true, -1.0, true)
	draw_arc(c, r, 0, TAU, 40, Art.CELL_EDGE, 3.0, true)
	if has_focus():
		draw_arc(c, r + 5.0, 0, TAU, 40, Art.BLOSSOM_CENTER, 5.0, true)
	var w := r * 0.14
	var ink := Art.INK
	match kind:
		Kind.BACK:
			var a := c + Vector2(-r * 0.4, 0)
			draw_line(a, c + Vector2(r * 0.45, 0), ink, w, true)
			draw_line(a, a + Vector2(r * 0.35, -r * 0.35), ink, w, true)
			draw_line(a, a + Vector2(r * 0.35, r * 0.35), ink, w, true)
			draw_circle(a, w / 2.0, ink, true, -1.0, true)
		Kind.RESET:
			draw_arc(c, r * 0.45, -PI * 0.35, PI * 1.35, 24, ink, w, true)
			var tip := c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * r * 0.45
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(r * 0.22, -r * 0.05), tip + Vector2(-r * 0.12, -r * 0.22), tip + Vector2(-r * 0.02, r * 0.2)]), ink)
		Kind.SETTINGS:
			for k in 3:
				var y := c.y + (k - 1) * r * 0.38
				draw_line(Vector2(c.x - r * 0.5, y), Vector2(c.x + r * 0.5, y), ink, w * 0.8, true)
				var knob: float = c.x + [-0.2, 0.25, -0.05][k] * r
				draw_circle(Vector2(knob, y), w * 1.1, Art.LEAF, true, -1.0, true)
