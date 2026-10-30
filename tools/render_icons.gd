extends SceneTree
## Rendert die Icon-SVGs aus assets/icon/ in die PNG-Grössen für Android und den Play Store.
##
## Aufruf:
##   godot --headless --path . --script res://tools/render_icons.gd

const JOBS := [
	["res://assets/icon/foreground.svg", "res://assets/icon/adaptive_foreground_432.png", 432],
	["res://assets/icon/background.svg", "res://assets/icon/adaptive_background_432.png", 432],
	["res://icon.svg", "res://assets/icon/launcher_192.png", 192],
	["res://assets/icon/icon_store.svg", "res://store/icon_512.png", 512],
]


func _initialize() -> void:
	for job in JOBS:
		var svg := FileAccess.get_file_as_string(job[0])
		if svg.is_empty():
			push_error("Fehlt: " + job[0])
			continue
		var width := float(svg.get_slice("width=\"", 1).get_slice("\"", 0))
		var image := Image.new()
		image.load_svg_from_string(svg, job[2] / width)
		image.save_png(job[1])
		print("%s -> %s (%dx%d)" % [job[0], job[1], image.get_width(), image.get_height()])
	quit()
