extends Node
## Sound effects, music and ambience. The named sounds were baked from the prototype's
## synthesiser into res://audio, so they sound the same; replace any .ogg to change it.
## The prototype also plays one-off synth notes all over its code (Sfx.tone / Sfx.burst);
## those are synthesised here the same way (oscillator or filtered noise with exponential
## envelopes, like WebAudio), on a worker thread the first time, then cached.

const VOICES := 32
const FADE_OUT := 0.8
const FADE_IN := 2.2
const RATE := 22050

var vol := 0.5        # master
var music_vol := 0.5
var sfx_vol := 0.8

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}
var _music: AudioStreamPlayer
var _music_id := ""
var _music_gain := 0.0      # current fade level 0–1
var _music_target := 0.0
var _pending := ""
var _rain: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _rain_level := 0.0
var _wind_level := 0.0
var _coin_streak := 0
var _last_coin := -9.0
var _synth := {}            # key → AudioStreamWAV
var _jobs := {}             # key → [task id, result holder, gain]
var _noise := PackedFloat32Array()
var _brown := PackedFloat32Array()
var _mutex := Mutex.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_rain = _loop_player("res://audio/ambience/rain.ogg")
	_wind = _loop_player("res://audio/ambience/wind.ogg")
	var len = RATE * 2
	_noise.resize(len)
	_brown.resize(len)
	var last = 0.0
	for i in len:
		_noise[i] = randf() * 2 - 1
		last = (last + 0.02 * (randf() * 2 - 1)) / 1.02
		_brown[i] = last * 3.5


func _loop_player(path: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var s: AudioStreamOggVorbis = load(path)
	if s:
		s = s.duplicate()
		s.loop = true
	p.stream = s
	p.volume_db = -80
	add_child(p)
	p.play()
	return p


func _stream(sfx_name: String) -> AudioStream:
	if not _streams.has(sfx_name):
		var path = "res://audio/sfx/%s.ogg" % sfx_name
		_streams[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sfx_name]


func _voice(s: AudioStream, gain: float, pitch := 1.0) -> void:
	var p = _pool[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(maxf(0.0001, gain * vol * sfx_vol))
	p.play()


## Play a baked sound. `gain` is linear (1 = as baked); `pitch` shifts it up or down.
func play(sfx_name: String, gain := 1.0, pitch := 1.0) -> bool:
	var s = _stream(sfx_name)
	if s == null:
		return false
	_voice(s, gain, pitch)
	return true


func setVol(v: float) -> void:
	vol = v


# ------------------------------------------------------------------ the synthesiser

static func _q(v: float) -> String:
	return str(snappedf(v, 0.001))


## an oscillator note with a quick attack and exponential decay (and an optional pitch slide)
func tone(freq: float, dur: float, type := "square", v := 0.2, slideTo = null, delay := 0.0) -> void:
	var key = "t|%s|%s|%s|%s|%s" % [_q(freq), _q(dur), type, _q(v), _q(slideTo) if slideTo else "-"]
	_play_synth(key, delay, func(): return _gen_tone(freq, dur, type, v, slideTo))


## filtered noise with a sweeping cutoff and exponential decay (whooshes, thuds, splashes)
func burst(dur: float, type: String, f0: float, f1: float, v := 0.3, delay := 0.0, buf = null) -> void:
	var brown: bool = buf != null and str(buf) == "brown"
	var key = "b|%s|%s|%s|%s|%s|%s" % [_q(dur), type, _q(f0), _q(f1), _q(v), "b" if brown else "w"]
	_play_synth(key, delay, func(): return _gen_burst(dur, type, f0, f1, v, brown))


func _play_synth(key: String, delay: float, gen: Callable) -> void:
	if _synth.has(key):
		if delay > 0:
			get_tree().create_timer(delay).timeout.connect(func(): _voice(_synth[key], 1.0))
		else:
			_voice(_synth[key], 1.0)
		return
	if _jobs.has(key):
		return
	var holder = [null]
	var id = WorkerThreadPool.add_task(func(): holder[0] = gen.call())
	_jobs[key] = [id, holder, delay, Time.get_ticks_msec()]


func _wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1, 1) * 32767))
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _env(t: float, dur: float, peak: float) -> float:
	if t < 0.008:
		return 0.0001 * pow(peak / 0.0001, t / 0.008)
	if t < dur:
		return peak * pow(0.0001 / peak, (t - 0.008) / maxf(0.0001, dur - 0.008))
	return 0.0


func _gen_tone(freq: float, dur: float, type: String, v: float, slideTo) -> AudioStreamWAV:
	var n = int((dur + 0.05) * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var ph = 0.0
	var f1: float = slideTo if slideTo else freq
	for i in n:
		var t = float(i) / RATE
		var f = freq * pow(f1 / freq, minf(1.0, t / dur)) if slideTo else freq
		ph = fmod(ph + f / RATE, 1.0)
		var s = 0.0
		match type:
			"sine": s = sin(ph * TAU)
			"square": s = 1.0 if ph < 0.5 else -1.0
			"sawtooth": s = 2.0 * ph - 1.0
			"triangle": s = 4.0 * absf(ph - 0.5) - 1.0
		out[i] = s * _env(t, dur, v) * 0.85
	return _wav(out)


func _gen_burst(dur: float, type: String, f0: float, f1: float, v: float, brown: bool) -> AudioStreamWAV:
	var src = _brown if brown else _noise
	var n = int((dur + 0.05) * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var off = randi() % src.size()
	var x1 = 0.0
	var x2 = 0.0
	var y1 = 0.0
	var y2 = 0.0
	var b0 = 0.0
	var b1 = 0.0
	var b2 = 0.0
	var a1 = 0.0
	var a2 = 0.0
	# WebAudio's lowpass/highpass Q is in dB; bandpass Q is the plain Q
	var q = pow(10.0, 1.1 / 20.0) if type != "bandpass" else 1.1
	for i in n:
		var t = float(i) / RATE
		if i % 16 == 0:
			var f = clampf(f0 * pow(f1 / f0, minf(1.0, t / dur)), 10.0, RATE * 0.49)
			var w0 = TAU * f / RATE
			var cw = cos(w0)
			var alpha = sin(w0) / (2.0 * q)
			var a0 = 1.0 + alpha
			match type:
				"lowpass":
					b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2
				"highpass":
					b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2
				_:
					b0 = alpha; b1 = 0; b2 = -alpha
			b0 /= a0; b1 /= a0; b2 /= a0
			a1 = -2 * cw / a0
			a2 = (1 - alpha) / a0
		var x = src[(off + i) % src.size()]
		var y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		var g = v * pow(0.0001 / v, t / dur) if t < dur else 0.0
		out[i] = y * g
	return _wav(out)


# ------------------------------------------------------------------ the prototype's named sounds

func coin() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	_coin_streak = mini(_coin_streak + 1, 14) if now - _last_coin < 0.7 else 0
	_last_coin = now
	play("coin", 1.0, pow(2.0, _coin_streak / 12.0))

func swing(h := false) -> void: play("swing_heavy" if h else "swing")
func hit(h := false) -> void: play("hit_crit" if h else "hit")
func squish() -> void: play("squish")
func jump() -> void: play("jump")
func djump() -> void: play("djump")
func dodge() -> void: play("dodge")
func land() -> void: play("land")
func parry() -> void: play("parry")
func block() -> void: play("block")
func hurt() -> void: play("hurt")
func goo() -> void: play("goo", 1.0, randf_range(0.9, 1.2))
func bang() -> void: play("bang")
func levelUp() -> void: play("levelUp")
func thunder() -> void: play("thunder")
func buy() -> void: play("buy")
func slam() -> void: play("slam")
func slide() -> void: play("slide")
func guard() -> void: play("guard")
func rope() -> void: play("rope", 1.0, randf_range(0.95, 1.2))
func swim() -> void: play("swim")
func ui() -> void: play("ui")
func buff() -> void: play("buff")


func rankUp(r: int) -> void:
	if r >= 4 and r <= 9:
		play("rankUp_%d" % r)
	else:
		var b = 330 * pow(2, r / 5.0)
		tone(b, 0.1, "square", 0.07)
		tone(b * 1.5, 0.22, "square", 0.07, null, 0.06)


func bowShot(big := false) -> void:
	if not play("bowShot_big" if big else "bowShot"):
		tone(200 if big else 320, 0.12 if big else 0.07, "triangle", 0.1 if big else 0.07, 90 if big else 160)
		burst(0.18 if big else 0.09, "highpass", 2500, 6000, 0.2 if big else 0.12)


func whoosh(p := 1.0, heavy := false) -> void:
	play("whoosh_heavy" if heavy else "whoosh", 1.0, p / (0.7 if heavy else 1.0))


func step(heavy: bool, surf: String) -> void:
	match surf:
		"wood": play("step_wood")
		"snow": play("step_snow", 1.3 if heavy else 1.0)
		"wet": play("step_wet", 1.0, randf_range(0.9, 1.15))
		_: play("step_grass_heavy" if heavy else "step_grass", 1.0, randf_range(0.9, 1.15))


# ------------------------------------------------------------------ music and ambience

func music(id: String) -> void:
	if id == _music_id or not ResourceLoader.exists("res://audio/music/%s.ogg" % id):
		return
	_music_id = id
	_pending = id
	_music_target = 0.0


func music_id() -> String:
	return _music_id


## rain 0–1.3 and wind 0–1.5, as the weather reports them
func ambience(rain: float, wind: float) -> void:
	_rain_level = rain * 0.22
	_wind_level = 0.03 + wind * 0.13


func _process(delta: float) -> void:
	for key in _jobs.keys():
		var j: Array = _jobs[key]
		if WorkerThreadPool.is_task_completed(j[0]):
			WorkerThreadPool.wait_for_task_completion(j[0])
			_jobs.erase(key)
			if j[1][0] != null:
				_synth[key] = j[1][0]
				var late = (Time.get_ticks_msec() - j[3]) / 1000.0
				if late < 0.4:
					if j[2] - late > 0:
						get_tree().create_timer(j[2] - late).timeout.connect(func(): _voice(_synth[key], 1.0))
					else:
						_voice(_synth[key], 1.0)
	# crossfade: fade the old track out, then start the new one and fade it in
	if _pending != "":
		_music_gain = move_toward(_music_gain, 0.0, delta / FADE_OUT)
		if _music_gain <= 0.0 or not _music.playing:
			var s: AudioStreamOggVorbis = load("res://audio/music/%s.ogg" % _pending)
			s = s.duplicate()
			s.loop = true
			_music.stream = s
			_music.play()
			_pending = ""
			_music_target = 1.0
	else:
		_music_gain = move_toward(_music_gain, _music_target, delta / FADE_IN)
	_music.volume_db = linear_to_db(maxf(0.0001, _music_gain * music_vol * vol * 1.8))
	var k = 1.0 - exp(-delta / 0.4)
	_rain.volume_db = lerpf(_rain.volume_db, linear_to_db(maxf(0.0001, _rain_level * vol * sfx_vol)), k)
	_wind.volume_db = lerpf(_wind.volume_db, linear_to_db(maxf(0.0001, _wind_level * vol * sfx_vol)), k)
