class_name GameAudio
extends Node
## Bruitages (pool de lecteurs 3D/2D) + musique avec fondu enchaîné selon la situation.

var streams := {}
var pool3d: Array = []
var pool2d: Array = []
var mus_a: AudioStreamPlayer
var mus_b: AudioStreamPlayer
var cur_track := ""
var music_on := true

func _ready() -> void:
	var dir := DirAccess.open("res://assets/sfx")
	if dir:
		for f in dir.get_files():
			var fn := f.replace(".import", "")
			if fn.ends_with(".ogg") and not streams.has(fn.get_basename()):
				streams[fn.get_basename()] = load("res://assets/sfx/" + fn)
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = 60.0
		add_child(p)
		pool3d.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool2d.append(p)
	mus_a = AudioStreamPlayer.new()
	mus_b = AudioStreamPlayer.new()
	add_child(mus_a)
	add_child(mus_b)
	print("AUDIO sons chargés ", streams.size())

func play(name: String, pos = null, vol := 0.0, pitch_var := 0.08) -> void:
	if not streams.has(name):
		return
	if pos == null:
		for p in pool2d:
			var pl := p as AudioStreamPlayer
			if not pl.playing:
				pl.stream = streams[name]
				pl.volume_db = vol
				pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
				pl.play()
				return
		return
	for p in pool3d:
		var pl := p as AudioStreamPlayer3D
		if not pl.playing:
			pl.stream = streams[name]
			pl.global_position = pos
			pl.volume_db = vol
			pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			pl.play()
			return

func music(track: String) -> void:
	if track == cur_track or not music_on:
		return
	cur_track = track
	var st := load("res://assets/music/%s.ogg" % track) as AudioStreamOggVorbis
	if st == null:
		return
	st.loop = true
	var old := mus_a if mus_a.playing else mus_b
	var nw := mus_b if old == mus_a else mus_a
	nw.stream = st
	nw.volume_db = -40.0
	nw.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(nw, "volume_db", -9.0, 1.5)
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, 1.5)
		tw.chain().tween_callback(old.stop)
	print("MUSIC ", track)
