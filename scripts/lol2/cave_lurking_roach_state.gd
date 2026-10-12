extends RefCounted
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Audio=preload("res://scripts/lol2/scripted_creature_audio_state.gd")
static func source() -> Dictionary: return Generic.source("res://scripts/lol2/cave_lurking_roach_source.json")
static func initial() -> Dictionary:
	var result:=Generic.initial(source())
	result.marker59=59
	return result
static func validate(value: Variant) -> String:
	var src:=source()
	var error:=Generic.validate(value,src)
	if not error.is_empty(): return error
	var marker=value.get("marker59")
	if not (marker is int or marker is float) or marker!=59: return "Invalid lurking creature startup marker."
	for id in ["36","37"]:
		if not value.actors[id].present: return "Source-present lurking creature is missing."
	if value.has("audio"):
		var audio: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_lurking_roach_audio_source.json"))
		return Audio.validate(value.audio,src.actors,audio)
	return ""
