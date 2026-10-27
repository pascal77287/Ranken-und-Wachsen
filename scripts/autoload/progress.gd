extends Node
## Spielstand und Einstellungen, lokal gespeichert in user://progress.cfg.

signal changed

const SAVE_PATH := "user://progress.cfg"

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(SAVE_PATH)  # Fehlt die Datei, starten wir mit leerem Stand.


func is_solved(level_id: String) -> bool:
	return _cfg.get_value("solved", level_id, false)


func mark_solved(level_id: String) -> void:
	if is_solved(level_id):
		return
	_cfg.set_value("solved", level_id, true)
	_save()


func reset_progress() -> void:
	if _cfg.has_section("solved"):
		_cfg.erase_section("solved")
	_save()


func get_setting(key: String) -> bool:
	return _cfg.get_value("settings", key, true)


func set_setting(key: String, value: bool) -> void:
	_cfg.set_value("settings", key, value)
	_save()


func _save() -> void:
	_cfg.save(SAVE_PATH)
	changed.emit()
