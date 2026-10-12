extends "res://scripts/lol2/monastery_room_view.gd"
## Original rune-room presentation. Caller owns admission, flags and item effects.
func _ready() -> void:
	super._ready()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_rune_rooms/rooms.json"))
	manifest.rooms.merge(source.rooms)
func show_runes(lights: bool, stone_taken: bool) -> void:
	var data: Dictionary = manifest.rooms.RUNES
	# RUNES setup selects RUNES1_ when local Runes_Lights_On is set,
	# and installs RUNES2_ only while flag7 (stone taken) is clear.
	data.background = data.clips["RUNES1_" if lights else "RUNES_"]
	data.idle = data.clips.RUNES2_ if lights and not stone_taken else {}
	enter_room("RUNES")
	play_idle()
func show_inscription() -> void:
	enter_room("RUNECL")

func show_stone_movie(time: float) -> void:
	enter_room("RUNES")
	background_generation += 1
	background.stop()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(preload("res://scripts/lol2/hive_ancient_stone.gd").ROOT+"stone.json"))
	clip = data.media.duplicate(true)
	clip.stone = true
	visual = clip
	last_frame = -1
	patch.position = Vector2.ZERO
	patch.size = Vector2(640,400)
	set_time(time)
func _process(delta: float) -> void:
	if clip.get("stone",false): return # Entry checkpoint owns this saved movie clock.
	super._process(delta)
