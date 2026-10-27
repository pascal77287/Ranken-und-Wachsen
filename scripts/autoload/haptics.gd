extends Node
## Vibrationsfeedback. Wirkt nur auf Mobilgeräten und wenn in den Einstellungen aktiv.


## Zartes Mikroticken beim Überqueren eines Feldes.
func tick() -> void:
	_vibrate(8, 0.25)


## Weicher Stoss bei Berührung eines Steins.
func bump() -> void:
	_vibrate(30, 0.55)


## Dreistufige Erfolgswelle beim Levelabschluss.
func success() -> void:
	_vibrate(35, 0.3)
	await get_tree().create_timer(0.16).timeout
	_vibrate(55, 0.6)
	await get_tree().create_timer(0.2).timeout
	_vibrate(110, 1.0)


func _vibrate(ms: int, amplitude: float) -> void:
	if OS.has_feature("mobile") and Progress.get_setting("haptics"):
		Input.vibrate_handheld(ms, amplitude)
