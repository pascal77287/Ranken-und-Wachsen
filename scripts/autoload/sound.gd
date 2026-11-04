extends Node
## Prozedural erzeugte Klänge.
## Keine Audiodateien nötig; alles wird beim Start synthetisiert.

const RATE := 22050
# Pentatonik (C-Dur) ab C5, für ansteigende Wachstumstöne.
const GROW_NOTES: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.51, 1567.98, 1760.0]

var _sfx_players: Array[AudioStreamPlayer] = []
var _grow: Array[AudioStreamWAV] = []
var _knock: AudioStreamWAV
var _chord: AudioStreamWAV
var _bloom: AudioStreamWAV


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

	for f in GROW_NOTES:
		_grow.append(_make_wav(_pluck(f, 0.22, 22.0, 0.35)))
	_knock = _make_wav(_wood_knock())
	_chord = _make_wav(_chime([523.25, 659.25, 783.99, 987.77, 1174.66], 2.6))
	_bloom = _make_wav(_chime([1046.5, 1318.51], 0.9))


## Wachstumston; die Tonhöhe steigt mit der Länge der Ranke.
func grow(length: int) -> void:
	_play(_grow[clampi(length - 2, 0, _grow.size() - 1)], -8.0, randf_range(0.99, 1.01))


func retract(length: int) -> void:
	_play(_grow[clampi(length - 1, 0, _grow.size() - 1)], -16.0, 0.8)


func block() -> void:
	_play(_knock, -5.0)


func goal_reached() -> void:
	_play(_bloom, -8.0)


func win() -> void:
	_play(_chord, -4.0)


func click() -> void:
	_play(_grow[4], -14.0, 1.2)


func _play(stream: AudioStream, volume_db: float, pitch := 1.0) -> void:
	if not Progress.get_setting("sound"):
		return
	var player := _sfx_players[0]
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


# --- Synthese --------------------------------------------------------------

## Gezupfter Ton mit sanftem Einschwingen und exponentiellem Ausklingen.
func _pluck(freq: float, length: float, decay: float, overtone: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var w := TAU * freq / RATE
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.004, 1.0) * exp(-t * decay)
		out[i] = (sin(w * i) + overtone * sin(w * 2.0 * i) * exp(-t * decay * 2.0)) * env * 0.5
	return out


func _wood_knock() -> PackedFloat32Array:
	var n := int(0.18 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var noise := 0.0
	for i in n:
		var t := float(i) / RATE
		noise = noise * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3
		var body := sin(TAU * 170.0 * t) * 0.7 + sin(TAU * 420.0 * t) * 0.3
		out[i] = (body * exp(-t * 32.0) + noise * exp(-t * 90.0) * 0.6) * minf(t / 0.002, 1.0) * 0.7
	return out


## Glockenartiger Akkord, Töne leicht versetzt wie ein Windspiel.
func _chime(freqs: Array, length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in freqs.size():
		var offset := int(k * 0.07 * RATE)
		var f: float = freqs[k]
		for i in range(offset, n):
			var t := float(i - offset) / RATE
			var env := minf(t / 0.003, 1.0) * exp(-t * 1.8)
			out[i] += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.76 * t) * exp(-t * 4.0)) * env * 0.18
	return out


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
