class_name Art
extends RefCounted
## Farbpalette und gemeinsame Zeichenroutinen (Blätter, Blüten, Knospen, Symbole).
## Alle Grafik ist prozedural; echte Grafiken können später einzelne Funktionen ersetzen.

const BG_TOP := Color("#f4efe3")
const BG_BOTTOM := Color("#e3ead3")
const INK := Color("#4a4238")
const INK_SOFT := Color("#8a7f70")
const SOIL := Color("#d9ccb2")
const CELL := Color("#efe6d2")
const CELL_EDGE := Color("#d2c3a5")
const STONE := Color("#8f8a83")
const STONE_LIGHT := Color("#b5b0a8")
const STONE_DARK := Color("#6d6862")
const GOAL := Color("#e7849e")
const GOAL_LIGHT := Color("#f6c1cf")
const LEAF := Color("#6fae55")
const BARK := Color("#8a6446")
const BARK_DARK := Color("#6e4e36")
const WOOD := Color("#a47148")
const WOOD_DARK := Color("#7a5230")
const CREAM := Color("#fbf6ea")
const BLOSSOM_CENTER := Color("#f5d36b")

## Rankenfarben; jede Ranke hat zusätzlich ein eigenes Symbol (Farbenblindheit).
const VINE_COLORS: Array[Color] = [
	Color("#4f9a45"), Color("#9467b8"), Color("#e0883a"),
	Color("#3f84b5"), Color("#d4607f"), Color("#8c8a2e"),
]

enum Symbol { DOT, TRIANGLE, SQUARE, DIAMOND, STAR, RING }


static func vine_color(i: int) -> Color:
	return VINE_COLORS[i % VINE_COLORS.size()]


static func ellipse_points(center: Vector2, rx: float, ry: float, angle := 0.0, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts


## Ein Blatt, das vom Punkt `base` in Richtung `angle` wächst.
static func draw_leaf(ci: CanvasItem, base: Vector2, angle: float, length: float, color: Color) -> void:
	if length < 1.0:
		return
	var pts := PackedVector2Array()
	var n := 10
	for k in n + 1:
		var t := float(k) / n
		pts.append(Vector2(t * length, -sin(t * PI) * length * 0.32))
	for k in range(n - 1, 0, -1):
		var t := float(k) / n
		pts.append(Vector2(t * length, sin(t * PI) * length * 0.32))
	var xf := Transform2D(angle, base)
	ci.draw_colored_polygon(xf * pts, color)
	ci.draw_line(base, base + Vector2(length * 0.8, 0).rotated(angle), color.darkened(0.2), maxf(1.0, length * 0.05), true)


## Offene Blüte mit fünf Blütenblättern; `open` von 0 (zu) bis 1 (offen).
static func draw_blossom(ci: CanvasItem, center: Vector2, radius: float, color: Color, open := 1.0, spin := 0.0) -> void:
	if open <= 0.0:
		return
	var r := radius * open
	if r < 2.0:
		return
	for k in 5:
		var a := spin + TAU * k / 5.0 - PI / 2.0
		ci.draw_colored_polygon(ellipse_points(center + Vector2(r * 0.55, 0).rotated(a), r * 0.55, r * 0.36, a, 12), color)
	ci.draw_circle(center, r * 0.32, BLOSSOM_CENTER, true, -1.0, true)


## Geschlossene Knospe (tropfenförmig, mit Kelchblättern).
static func draw_bud(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var t := TAU * k / 28.0
		pts.append(center + Vector2(sin(t) * sin(t / 2.0) * radius * 0.95, -cos(t) * radius))
	ci.draw_colored_polygon(pts, color)
	ci.draw_line(center + Vector2(0, -radius * 0.7), center + Vector2(0, radius * 0.4), color.lightened(0.35), maxf(1.5, radius * 0.08), true)
	for s in [-1.0, 1.0]:
		draw_leaf(ci, center + Vector2(0, radius * 0.85), -PI / 2.0 + s * 0.9, radius * 0.75, LEAF)


static func draw_symbol(ci: CanvasItem, kind: int, center: Vector2, r: float, color: Color) -> void:
	match kind % 6:
		Symbol.DOT:
			ci.draw_circle(center, r * 0.7, color, true, -1.0, true)
		Symbol.TRIANGLE:
			ci.draw_colored_polygon(_regular(center, r, 3, -PI / 2.0), color)
		Symbol.SQUARE:
			ci.draw_colored_polygon(_regular(center, r * 0.95, 4, PI / 4.0), color)
		Symbol.DIAMOND:
			ci.draw_colored_polygon(_regular(center, r, 4, 0.0), color)
		Symbol.STAR:
			var pts := PackedVector2Array()
			for k in 10:
				var rr := r if k % 2 == 0 else r * 0.45
				var a := -PI / 2.0 + TAU * k / 10.0
				pts.append(center + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, color)
		Symbol.RING:
			ci.draw_arc(center, r * 0.65, 0, TAU, 24, color, r * 0.3, true)


static func _regular(center: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := rot + TAU * k / n
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Stein mit unregelmässiger Kontur; `seed` sorgt für eine stabile Form pro Feld.
static func draw_stone(ci: CanvasItem, center: Vector2, radius: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		pts.append(center + Vector2(cos(a) * 1.05, sin(a) * 0.9) * radius * rng.randf_range(0.86, 1.0))
	ci.draw_colored_polygon(pts, STONE)
	ci.draw_colored_polygon(ellipse_points(center + Vector2(-radius * 0.22, -radius * 0.28), radius * 0.42, radius * 0.22, -0.3, 12), STONE_LIGHT)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), STONE_DARK, maxf(1.5, radius * 0.06), true)


static func vertical_gradient(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(
		PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
