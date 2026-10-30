extends SceneTree
## Prüft alle Level: Format, Hauptlösung und Anzahl Lösungen (nur zur Info).
##
## Aufruf:
##   godot --headless --path . --script res://tools/validate_levels.gd [-- 09_ 10_]
## Optional nach "--": nur Kapitel prüfen, deren Dateiname einen der Teile enthält.

const INDEX_PATH := "res://levels/index.json"


func _initialize() -> void:
	var failed := 0
	var total := 0
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	var only := OS.get_cmdline_user_args()
	for chapter_path in index.chapters:
		if not only.is_empty() and not Array(only).any(func(part): return part in chapter_path):
			continue
		var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chapter_path))
		print("== %s (%s)" % [chapter.name, chapter_path])
		var ids := {}
		for entry in chapter.levels:
			total += 1
			var lv := LevelData.from_dict(entry)
			var problems := Array(lv.errors)
			if ids.has(lv.id):
				problems.append("ID doppelt")
			ids[lv.id] = true
			if problems.is_empty():
				var err := BoardState.new(lv).apply_solution(lv.solution)
				if err != "":
					problems.append("Hauptlösung ungültig: " + err)
			if not problems.is_empty():
				failed += 1
				print("  FEHLER %s %s" % [lv.id, lv.name])
				for p in problems:
					print("     - " + p)
				continue

			var solver := LevelSolver.new(lv)
			solver.node_limit = 20_000_000  # die schwersten Level brauchen über 5 Mio. Knoten
			var count := solver.count_solutions()
			var info := "eindeutig" if count == 1 else "mehrere Lösungen"
			if solver.aborted:
				info = "Suche abgebrochen (zu gross)"
			print("  ok     %s %-18s %dx%d, %d Ranke(n), %s, %d Knoten" % [
				lv.id, lv.name, lv.width, lv.height, lv.starts.size(), info, solver.nodes])
	print("\n%d Level geprüft, %d fehlerhaft." % [total, failed])
	quit(1 if failed > 0 else 0)
