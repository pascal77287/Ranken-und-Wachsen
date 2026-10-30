extends SceneTree
## Zeichnet die Vorstellungsgrafik für den Play Store (1024x500) mit den
## Zeichenroutinen des Spiels und speichert sie unter store/.
##
## Aufruf (nicht headless, braucht Rendering):
##   godot --path . --resolution 432x768 --script res://tools/render_feature_graphic.gd

const SIZE := Vector2i(1024, 500)
const OUT := "res://store/feature_graphic_1024x500.png"


class Banner extends Control:
	const CELL := 76.0
	const ORIGIN := Vector2(508, 98)
	# Ranken in Feldkoordinaten; die letzte Ranke ist noch im Wachsen.
	const VINES := [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)],
		[Vector2i(0, 3), Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(2, 2), Vector2i(3, 2)],
	]
	const GOALS := [Vector2i(5, 0), Vector2i(5, 3)]
	const STONE := Vector2i(5, 1)

	func _center(c: Vector2i) -> Vector2:
		return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL

	func _draw() -> void:
		Art.vertical_gradient(self, Rect2(Vector2.ZERO, size), Art.BG_TOP, Art.BG_BOTTOM)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(64, 220), "Wachsen &", HORIZONTAL_ALIGNMENT_LEFT, -1, 68, Art.INK)
		draw_string(font, Vector2(64, 296), "Verflechten", HORIZONTAL_ALIGNMENT_LEFT, -1, 68, Art.INK)
		draw_string(font, Vector2(66, 352), "Entspannende Rankenrätsel", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Art.INK_SOFT)

		var board := Rect2(ORIGIN - Vector2(12, 12), Vector2(6, 4) * CELL + Vector2(24, 24))
		var box := StyleBoxFlat.new()
		box.bg_color = Art.SOIL
		box.set_corner_radius_all(22)
		box.anti_aliasing = true
		draw_style_box(box, board)
		var cell_box := StyleBoxFlat.new()
		cell_box.set_corner_radius_all(14)
		cell_box.anti_aliasing = true
		for y in 4:
			for x in 6:
				var c := Vector2i(x, y)
				var owner_idx := -1
				for i in VINES.size():
					if c in VINES[i] and not c in GOALS:
						owner_idx = i
				cell_box.bg_color = Art.CELL if owner_idx < 0 else Art.CELL.lerp(Art.vine_color(owner_idx).lightened(0.55), 0.55)
				draw_style_box(cell_box, Rect2(ORIGIN + Vector2(c) * CELL, Vector2.ONE * CELL).grow(-3))
		for i in VINES.size():
			var path: Array = VINES[i]
			var color := Art.vine_color(i)
			var pts := PackedVector2Array()
			for c in path:
				pts.append(_center(c))
			for k in range(1, pts.size()):
				Art.draw_leaf(self, pts[k - 1].lerp(pts[k], 0.55), (pts[k] - pts[k - 1]).angle() + (0.85 if k % 2 == 0 else -0.85), CELL * 0.3, color.lightened(0.18))
			draw_polyline(pts, color, CELL * 0.15, true)
			for p in pts:
				draw_circle(p, CELL * 0.075, color, true, -1.0, true)
			var start := pts[0]
			for k in 6:
				draw_circle(start + Vector2(CELL * 0.22, 0).rotated(TAU * k / 6.0 + 0.3), CELL * 0.15, color.lightened(0.35), true, -1.0, true)
			draw_circle(start, CELL * 0.26, color, true, -1.0, true)
			Art.draw_symbol(self, i, start, CELL * 0.15, Art.CREAM)
			if path[-1] not in GOALS:
				draw_circle(pts[-1], CELL * 0.16, color.lightened(0.3), true, -1.0, true)
		Art.draw_blossom(self, _center(GOALS[0]), CELL * 0.44, Art.GOAL, 1.0, 0.3)
		Art.draw_bud(self, _center(GOALS[1]), CELL * 0.3, Art.GOAL)
		Art.draw_stone(self, _center(STONE), CELL * 0.34, 7)


func _initialize() -> void:
	var sv := SubViewport.new()
	sv.size = SIZE
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var banner := Banner.new()
	banner.size = Vector2(SIZE)
	sv.add_child(banner)
	_save.call_deferred(sv)


func _save(sv: SubViewport) -> void:
	for i in 4:
		await process_frame
	sv.get_texture().get_image().save_png(OUT)
	print("Gespeichert: ", OUT)
	quit()
