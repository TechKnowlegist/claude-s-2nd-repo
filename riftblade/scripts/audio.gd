extends Node
## Autoload "Audio". Every sound in the game is synthesized in code at
## runtime (no external audio files) so it stays consistent with the rest
## of the project's fully-procedural art. Short one-shot sounds are cached
## AudioStreamWAVs played through throwaway AudioStreamPlayers; music is a
## single looping AudioStreamPlayer that crossfades when the track changes.

const SAMPLE_RATE := 22050.0

var _cache := {}
var _music_player: AudioStreamPlayer
var _current_track := ""
var muted := false

## note name -> MIDI number, for readable chord progressions below.
const C4 := 60


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -14.0
	add_child(_music_player)


func set_muted(value: bool) -> void:
	muted = value
	_music_player.stream_paused = value


# --- Sound effects ----------------------------------------------------------------

func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if muted:
		return
	var stream: AudioStreamWAV = _cache.get(name)
	if stream == null:
		stream = _build_sfx(name)
		_cache[name] = stream
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- Music ------------------------------------------------------------------------

## `variant` (0-2) picks a related but distinct take on the same track -
## a different key and slightly different tempo - so a long dimension
## doesn't loop the exact same music in every room.
func play_music(track: String, variant := 0) -> void:
	var key := "%s_%d" % [track, variant]
	if muted or _current_track == key:
		return
	_current_track = key
	var stream: AudioStreamWAV = _cache.get("music_" + key)
	if stream == null:
		stream = _build_music(track, variant)
		_cache["music_" + key] = stream
	var tw := create_tween()
	tw.tween_property(_music_player, "volume_db", -40.0, 0.35)
	tw.tween_callback(func() -> void:
		_music_player.stream = stream
		_music_player.play()
	)
	tw.tween_property(_music_player, "volume_db", -14.0, 0.5)


# --- Synthesis helpers --------------------------------------------------------------

static func _to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream


static func _midi_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


static func _osc(shape: String, freq: float, t: float) -> float:
	var phase := fmod(freq * t, 1.0)
	match shape:
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"saw":
			return 2.0 * phase - 1.0
		"noise":
			return randf_range(-1.0, 1.0)
		_:
			return sin(TAU * phase)


## Renders `duration` seconds of `gen(t) -> -1..1` into a sample buffer.
static func _render(duration: float, gen: Callable) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		samples[i] = gen.call(float(i) / SAMPLE_RATE)
	return samples


static func _build_sfx(name: String) -> AudioStreamWAV:
	match name:
		"swing":
			return _to_stream(_render(0.11, func(t):
				var env := pow(1.0 - t / 0.11, 1.5)
				var f := lerpf(1100.0, 300.0, t / 0.11)
				return _osc("sine", f, t) * env * 0.5 + _osc("noise", 0, t) * env * 0.15
			))
		"hit":
			return _to_stream(_render(0.09, func(t):
				var env := pow(1.0 - t / 0.09, 2.0)
				return (_osc("square", 160.0, t) * 0.5 + _osc("noise", 0, t) * 0.5) * env * 0.55
			))
		"crit":
			return _to_stream(_render(0.16, func(t):
				var env := pow(1.0 - t / 0.16, 1.6)
				var f := lerpf(1400.0, 500.0, t / 0.16)
				return (_osc("square", f, t) * 0.6 + _osc("noise", 0, t) * 0.3) * env * 0.6
			))
		"player_hit":
			return _to_stream(_render(0.22, func(t):
				var env := pow(1.0 - t / 0.22, 1.3)
				return (_osc("square", 110.0, t) * 0.6 + _osc("noise", 0, t) * 0.4) * env * 0.6
			))
		"death_enemy":
			return _to_stream(_render(0.28, func(t):
				var env := pow(1.0 - t / 0.28, 1.2)
				var f := lerpf(500.0, 60.0, t / 0.28)
				return (_osc("saw", f, t) * 0.5 + _osc("noise", 0, t) * 0.35) * env * 0.6
			))
		"death_player":
			return _to_stream(_render(0.9, func(t):
				var env := pow(1.0 - t / 0.9, 1.1)
				var f := lerpf(340.0, 40.0, t / 0.9)
				return (_osc("saw", f, t) * 0.55 + _osc("noise", 0, t) * 0.25) * env * 0.6
			))
		"pickup":
			return _to_stream(_render(0.16, func(t):
				var f := 620.0 if t < 0.08 else 930.0
				var env := pow(1.0 - fmod(t, 0.08) / 0.08, 1.4)
				return _osc("sine", f, t) * env * 0.4
			))
		"shard":
			return _to_stream(_render(0.09, func(t):
				var env := pow(1.0 - t / 0.09, 1.8)
				return _osc("sine", 1300.0, t) * env * 0.35
			))
		"chest":
			return _to_stream(_render(0.4, func(t):
				var steps := [440.0, 550.0, 660.0]
				var idx := mini(int(t / 0.12), steps.size() - 1)
				var f: float = steps[idx]
				var env := pow(1.0 - fmod(t, 0.12) / 0.12, 1.3)
				return _osc("sine", f, t) * env * 0.4
			))
		"levelup":
			return _to_stream(_render(0.5, func(t):
				var steps := [523.0, 659.0, 784.0, 1046.0]
				var idx := mini(int(t / 0.11), steps.size() - 1)
				var f: float = steps[idx]
				var env := pow(1.0 - fmod(t, 0.11) / 0.11, 1.2)
				return _osc("square", f, t) * env * 0.32
			))
		"equip":
			return _to_stream(_render(0.3, func(t):
				var f := lerpf(300.0, 700.0, t / 0.3)
				var env := pow(1.0 - t / 0.3, 1.2)
				return _osc("sine", f, t) * env * 0.45
			))
		"portal":
			return _to_stream(_render(0.45, func(t):
				var env := sin(PI * minf(t / 0.45, 1.0))
				var f := 500.0 + sin(t * 24.0) * 160.0
				return _osc("sine", f, t) * env * 0.4
			))
		"gate":
			return _to_stream(_render(0.5, func(t):
				var env := pow(1.0 - t / 0.5, 1.1)
				return (_osc("saw", 90.0, t) * 0.5 + _osc("noise", 0, t) * 0.2) * env * 0.5
			))
		"boss_roar":
			return _to_stream(_render(0.65, func(t):
				var env := pow(1.0 - t / 0.65, 1.0) * minf(t / 0.05, 1.0)
				var f := 90.0 + sin(t * 8.0) * 12.0
				return (_osc("square", f, t) * 0.5 + _osc("noise", 0, t) * 0.3) * env * 0.6
			))
		"click":
			return _to_stream(_render(0.05, func(t):
				var env := pow(1.0 - t / 0.05, 2.0)
				return _osc("sine", 700.0, t) * env * 0.3
			))
		"puzzle_step":
			return _to_stream(_render(0.14, func(t):
				var env := pow(1.0 - t / 0.14, 1.3)
				return _osc("sine", 500.0, t) * env * 0.4
			))
		"puzzle_wrong":
			return _to_stream(_render(0.3, func(t):
				var env := pow(1.0 - t / 0.3, 1.2)
				var f := lerpf(220.0, 140.0, t / 0.3)
				return _osc("square", f, t) * env * 0.4
			))
		"puzzle_solved":
			return _to_stream(_render(0.55, func(t):
				var steps := [523.0, 659.0, 784.0, 1046.0, 1318.0]
				var idx := mini(int(t / 0.1), steps.size() - 1)
				var f: float = steps[idx]
				var env := pow(1.0 - fmod(t, 0.1) / 0.1, 1.1)
				return _osc("sine", f, t) * env * 0.4
			))
		_:
			return _to_stream(_render(0.05, func(t): return 0.0))


# --- Music tracks -------------------------------------------------------------------
# Each track is a short chord-arpeggio loop. Notes are MIDI numbers; -1 is a rest.

const MUSIC := {
	"hub": {"wave": "sine", "beat": 0.34, "notes": [
		C4, C4 + 4, C4 + 7, C4 + 11, C4 + 7, C4 + 4,
		C4 - 5, C4 - 1, C4 + 2, C4 + 6, C4 + 2, C4 - 1,
	]},
	"pixel": {"wave": "square", "beat": 0.22, "notes": [
		C4, C4, C4 + 7, C4 + 7, C4 + 9, C4 + 9, C4 + 7, C4 + 5,
		C4 + 5, C4 + 5, C4 + 4, C4 + 4, C4 + 2, C4 + 2, C4, -1,
	]},
	"ascii": {"wave": "saw", "beat": 0.4, "notes": [
		C4 - 12, -1, C4 - 5, -1, C4 - 12, -1, C4 - 8, -1,
		C4 - 13, -1, C4 - 6, -1, C4 - 13, -1, C4 - 9, -1,
	]},
	"geometry": {"wave": "sine", "beat": 0.3, "notes": [
		C4 + 2, C4 + 9, C4 + 14, C4 + 9,
		C4 - 1, C4 + 6, C4 + 11, C4 + 6,
		C4 + 4, C4 + 11, C4 + 16, C4 + 11,
		C4 + 2, C4 + 9, C4 + 14, C4 + 9,
	]},
	"puzzle": {"wave": "sine", "beat": 0.5, "notes": [
		C4, C4 + 3, C4 + 7, C4 + 10, C4 + 7, C4 + 3,
		C4 - 2, C4 + 1, C4 + 5, C4 + 8, C4 + 5, C4 + 1,
	]},
}

## Semitones and tempo scale for each of the 3 room-to-room variants, so
## the same dimension's rooms don't all sound identical.
const VARIANT_TRANSPOSE := [0, 3, -4]
const VARIANT_TEMPO := [1.0, 0.9, 1.12]


static func _build_music(track: String, variant := 0) -> AudioStreamWAV:
	var cfg: Dictionary = MUSIC.get(track, MUSIC.hub)
	var notes: Array = cfg.notes
	var v := clampi(variant, 0, VARIANT_TRANSPOSE.size() - 1)
	var transpose: int = VARIANT_TRANSPOSE[v]
	var beat: float = cfg.beat * VARIANT_TEMPO[v]
	var wave: String = cfg.wave
	var duration := beat * notes.size()
	var samples := _render(duration, func(t):
		var i := int(t / beat) % notes.size()
		var note: int = notes[i]
		if note < 0:
			return 0.0
		var local_t := fmod(t, beat)
		var env := clampf(1.0 - local_t / beat, 0.0, 1.0)
		env = pow(env, 0.6) * 0.22
		var freq := _midi_hz(note + 48 + transpose)
		var lead := _osc(wave, freq, t)
		var sub := _osc("sine", freq * 0.5, t) * 0.35
		return (lead + sub) * env
	)
	return _to_stream(samples, true)
