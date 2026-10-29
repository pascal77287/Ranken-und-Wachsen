extends Node
## Spielstand und Einstellungen, lokal gespeichert in user://progress.cfg.

signal changed

const SAVE_PATH := "user://progress.cfg"
## Einstellung „Keine Teilschlangen“: Hebt man den Finger, bevor die Ranke in
## einer Blüte ist, zieht sie sich ganz zurück.
const NO_PARTIAL := "no_partial"

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(SAVE_PATH)  # Fehlt die Datei, starten wir mit leerem Stand.


func is_solved(level_id: String) -> bool:
	return _cfg.get_value("solved", level_id, false)


## Im Modus „Keine Teilschlangen“ gelöst (goldene Blüte im Lebensbaum).
func is_solved_hard(level_id: String) -> bool:
	return _cfg.get_value("solved_hard", level_id, false)


func mark_solved(level_id: String, hard := false) -> void:
	if is_solved(level_id) and (not hard or is_solved_hard(level_id)):
		return
	_cfg.set_value("solved", level_id, true)
	if hard:
		_cfg.set_value("solved_hard", level_id, true)
	_save()


func reset_progress() -> void:
	for section in ["solved", "solved_hard"]:
		if _cfg.has_section(section):
			_cfg.erase_section(section)
	_save()


func get_setting(key: String) -> bool:
	return _cfg.get_value("settings", key, key != NO_PARTIAL)


func set_setting(key: String, value: bool) -> void:
	_cfg.set_value("settings", key, value)
	_save()


func _save() -> void:
	_cfg.save(SAVE_PATH)
	changed.emit()
