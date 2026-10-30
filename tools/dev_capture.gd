extends Node
## Entwicklerwerkzeug: öffnet optional ein Level und speichert ein Bildschirmfoto.
## Wird von main.gd nur geladen, wenn das Spiel mit "--capture" gestartet wird.
##
## Aufruf:
##   godot --path . --resolution 540x960 -- --capture <datei.png> [kapitel level [modus]]
## Modus: "half" = Hauptlösung zur Hälfte gelegt, "win" = gelöst mit Gewinn-Animation.
## Mit "--hires" wird unabhängig von der Bildschirmgrösse in 1080x1920 gerendert (Store-Bilder).


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	args = args.slice(args.find("--capture") + 1)
	var out := args[0] if args.size() > 0 else "user://screenshot.png"
	var hires := "--hires" in args
	args = Array(args).filter(func(a): return a != "--hires")
	var main := get_parent()
	var target := get_viewport()
	if hires:
		var sv := SubViewport.new()
		sv.size = Vector2i(1080, 1920)
		sv.size_2d_override = Vector2i(720, 1280)
		sv.size_2d_override_stretch = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_tree().root.add_child(sv)
		reparent(get_tree().root)  # dieses Werkzeug nicht mit verschieben
		main.reparent(sv, false)
		main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		target = sv
	for i in 5:
		await get_tree().process_frame

	if args.size() >= 3:
		main._open_level(int(args[1]), int(args[2]))
		await get_tree().create_timer(0.8).timeout
		var board: BoardView = main._game._board
		var mode := args[3] if args.size() >= 4 else ""
		if mode == "half":
			for i in board.level.solution.size():
				var path: Array = board.level.solution[i]
				for k in range(1, path.size() / 2 + 1):
					board.state.step(i, path[k])
			board.changed.emit()
			board.queue_redraw()
		elif mode == "win":
			board.state.apply_solution(board.level.solution)
			board.changed.emit()
			board._start_win()
			await get_tree().create_timer(0.7).timeout
	await get_tree().create_timer(0.6).timeout
	target.get_texture().get_image().save_png(out)
	print("Gespeichert: ", out)
	get_tree().quit()
