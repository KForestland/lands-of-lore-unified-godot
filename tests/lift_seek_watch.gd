extends "res://scripts/lol2/cave_prop83_lift.gd"
## Test-only subclass. Timestamps the existing _sync_sound. Does not change the seek argument.
## derived_offset is computed after super returns from the same expression production uses.
## It is not the value observed as the play() argument. usec_before/usec bracket super.
## Native play() happens inside that bracket. post is read after super returns.

var seek_stamps: Array = []

func _sync_sound() -> void:
	var pre := 0.0
	if sound != null:
		pre = sound.get_playback_position()
	var t0 := Time.get_ticks_usec()
	super._sync_sound()
	var t1 := Time.get_ticks_usec()
	var derived_offset := 0.0
	if float(state.sound) > 0.0:
		derived_offset = maxf(sound_seconds - float(state.sound), 0.0)
	var post := 0.0
	if sound != null:
		post = sound.get_playback_position()
	seek_stamps.append({
		"pre": pre,
		"derived_offset": derived_offset,
		"post": post,
		"usec_before": t0,
		"usec": t1,
	})

func stamp_list() -> Array:
	return seek_stamps.duplicate(true)

static func install(lift) -> Node:
	var saved := {}
	for prop in lift.get_property_list():
		var usage := int(prop["usage"])
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not (usage & PROPERTY_USAGE_READ_ONLY):
			var key := String(prop["name"])
			if key == "seek_stamps" or key == "script":
				continue
			saved[key] = lift.get(key)
	lift.set_script(load("res://tests/lift_seek_watch.gd"))
	for key in saved:
		lift.set(key, saved[key])
	lift.seek_stamps = []
	return lift
