extends Node

# AudioManager Autoload Singleton
# Provides procedural sound synthesis and audio feedback for UI, telemetry, and simulation events.

var _sfx_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _synth_cache: Dictionary = {}

var sfx_volume_db: float = 0.0
var sfx_enabled: bool = true

func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	add_child(_ambient_player)

	_pregenerate_sounds()

func _pregenerate_sounds() -> void:
	_synth_cache["click"] = _generate_tone(880.0, 0.04, 0.25, 0.005, 0.035, false)
	_synth_cache["hover"] = _generate_tone(440.0, 0.02, 0.1, 0.002, 0.018, false)
	_synth_cache["confirm"] = _generate_chord([523.25, 659.25, 783.99], 0.12, 0.3)
	_synth_cache["warning"] = _generate_tone(330.0, 0.18, 0.4, 0.01, 0.17, true)
	_synth_cache["error"] = _generate_chord([220.0, 233.08], 0.25, 0.45)
	_synth_cache["telemetry"] = _generate_tone(1760.0, 0.03, 0.2, 0.003, 0.027, false)
	_synth_cache["launch"] = _generate_noise_ramp(1.8, 0.5)
	_synth_cache["success"] = _generate_chord([523.25, 659.25, 783.99, 1046.50], 0.4, 0.4)
	_synth_cache["laser"] = _generate_tone(2200.0, 0.045, 0.28, 0.002, 0.043, true)
	_synth_cache["drill"] = _generate_tone(140.0, 0.16, 0.35, 0.01, 0.15, true)
	_synth_cache["seal"] = _generate_chord([440.0, 659.25, 880.0], 0.22, 0.35)
	_synth_cache["retro_rocket"] = _generate_noise_ramp(1.6, 0.45)
	_synth_cache["touchdown"] = _generate_tone(85.0, 0.35, 0.55, 0.005, 0.34, true)
	_synth_cache["servo"] = _generate_tone(1150.0, 0.18, 0.18, 0.02, 0.16, false)
	_synth_cache["cable_cut"] = _generate_tone(2800.0, 0.05, 0.45, 0.001, 0.049, true)

func play_sfx(sound_name: String) -> void:
	if not sfx_enabled:
		return
	if _synth_cache.has(sound_name):
		var p = AudioStreamPlayer.new()
		p.stream = _synth_cache[sound_name]
		p.volume_db = sfx_volume_db
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func play_click() -> void:
	play_sfx("click")

func play_hover() -> void:
	play_sfx("hover")

func play_confirm() -> void:
	play_sfx("confirm")

func play_warning() -> void:
	play_sfx("warning")

func play_error() -> void:
	play_sfx("error")

func play_telemetry() -> void:
	play_sfx("telemetry")

func play_launch() -> void:
	play_sfx("launch")

func play_success() -> void:
	play_sfx("success")

func play_laser() -> void:
	play_sfx("laser")

func play_drill() -> void:
	play_sfx("drill")

func play_seal() -> void:
	play_sfx("seal")

func play_retro_rocket() -> void:
	play_sfx("retro_rocket")

func play_touchdown() -> void:
	play_sfx("touchdown")

func play_servo() -> void:
	play_sfx("servo")

func play_cable_cut() -> void:
	play_sfx("cable_cut")

# Procedural Sound Generators
func _generate_tone(freq: float, duration: float, amp: float, attack: float, decay: float, square: bool) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0
		if t < attack and attack > 0.0:
			env = t / attack
		elif decay > 0.0:
			env = max(0.0, 1.0 - ((t - attack) / decay))

		var val: float = 0.0
		if square:
			val = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		else:
			val = sin(TAU * freq * t)

		var s = clamp(int(val * env * amp * 127.0 + 128.0), 0, 255)
		byte_data[i] = s

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = byte_data
	return stream

func _generate_chord(freqs: Array, duration: float, amp: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = max(0.0, 1.0 - (t / duration))
		var sum: float = 0.0
		for f in freqs:
			sum += sin(TAU * float(f) * t)
		sum /= float(freqs.size())
		var s = clamp(int(sum * env * amp * 127.0 + 128.0), 0, 255)
		byte_data[i] = s

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = byte_data
	return stream

func _generate_noise_ramp(duration: float, amp: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples)

	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var progress: float = t / duration
		var env: float = sin(progress * PI)
		var n: float = rng.randf_range(-1.0, 1.0)
		var s = clamp(int(n * env * amp * 127.0 + 128.0), 0, 255)
		byte_data[i] = s

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = byte_data
	return stream
