extends Node
## Music and sound effects. Every file in audio/ is synthesized by
## tools/make_audio.py: original sounds built from oscillators and noise.
## An AudioStreamPlayer plays one sound at a time, so a small pool of them
## lets effects overlap. They play through a "SFX" bus and the waltz through
## a "Music" bus, so each group's volume is set in one place.

const SFX := {
	"step": preload("res://audio/sfx/step.wav"), "slide": preload("res://audio/sfx/slide.wav"),
	"nope": preload("res://audio/sfx/nope.wav"), "freeze": preload("res://audio/sfx/freeze.wav"),
	"melt": preload("res://audio/sfx/melt.wav"), "push": preload("res://audio/sfx/push.wav"),
	"bridge": preload("res://audio/sfx/bridge.wav"), "light": preload("res://audio/sfx/light.wav"),
	"gate": preload("res://audio/sfx/gate.wav"), "win": preload("res://audio/sfx/win.wav"),
	"undo": preload("res://audio/sfx/undo.wav"), "home": preload("res://audio/sfx/home.wav"),
}
const MUSIC := preload("res://audio/music/waltz.wav")

var music_on := true
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	_bus("Music", -10.0)
	_bus("SFX", -4.0)
	# The waltz is written to loop exactly, so loop the whole file.
	var music: AudioStreamWAV = MUSIC
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = int(round(music.get_length() * music.mix_rate))
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = MUSIC
	add_child(_music)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)


func start_music() -> void:
	if music_on and not _music.playing:
		_music.play()


func toggle_music() -> bool:
	music_on = not music_on
	if music_on:
		_music.play()
	else:
		_music.stop()
	return music_on


func play(sound: String, volume_db := 0.0, pitch_jitter := 0.0) -> void:
	var p := _pool[0]
	for c in _pool:
		if not c.playing:
			p = c
			break
	p.stream = SFX[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


static func _bus(bus_name: String, db: float) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, db)
