extends Node
## Sound effects, music and ambience. Every sound was baked from the prototype's synthesiser
## into res://audio, so they sound the same; replace any .ogg to change it.

const VOICES := 24
const FADE_OUT := 0.8
const FADE_IN := 2.2

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_rain = _loop_player("res://audio/ambience/rain.ogg")
	_wind = _loop_player("res://audio/ambience/wind.ogg")


func _loop_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
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
		var path := "res://audio/sfx/%s.ogg" % sfx_name
		_streams[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sfx_name]


## Play a one-shot sound. `gain` is linear (1 = as baked); `pitch` shifts it up or down.
func play(sfx_name: String, gain := 1.0, pitch := 1.0) -> void:
	var s := _stream(sfx_name)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(max(0.0001, gain * vol * sfx_vol))
	p.play()


## Coins climb in pitch while you keep picking them up quickly, like the original.
func coin() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_coin_streak = mini(_coin_streak + 1, 14) if now - _last_coin < 0.7 else 0
	_last_coin = now
	play("coin", 1.0, pow(2.0, _coin_streak / 12.0))


func step(heavy: bool, surf: String) -> void:
	match surf:
		"wood": play("step_wood")
		"snow": play("step_snow", 1.3 if heavy else 1.0)
		"wet": play("step_wet", 1.0, randf_range(0.9, 1.15))
		_: play("step_grass_heavy" if heavy else "step_grass", 1.0, randf_range(0.9, 1.15))


func music(id: String) -> void:
	if id == _music_id or not ResourceLoader.exists("res://audio/music/%s.ogg" % id):
		return
	_music_id = id
	_pending = id
	_music_target = 0.0


## rain 0–1.3 and wind 0–1.5, as the weather reports them
func ambience(rain: float, wind: float) -> void:
	_rain_level = rain * 0.22
	_wind_level = 0.03 + wind * 0.13


func _process(delta: float) -> void:
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
	_music.volume_db = linear_to_db(max(0.0001, _music_gain * music_vol * vol * 1.8))
	var k := 1.0 - exp(-delta / 0.4)
	_rain.volume_db = lerpf(_rain.volume_db, linear_to_db(max(0.0001, _rain_level * vol * sfx_vol)), k)
	_wind.volume_db = lerpf(_wind.volume_db, linear_to_db(max(0.0001, _wind_level * vol * sfx_vol)), k)
