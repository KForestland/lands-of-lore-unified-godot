extends "res://scripts/lol2/cave_captain_audio.gd"
## Preserve captain's scripted cue override while selecting guard39's source path walk.
var controls: Node3D
func pose(id: String) -> Dictionary:
	if controls!=null and not controls.state.is_empty():
		if id=="52" and controls.input_locked():return {"definition":"2","selector":-1,"time":0.0,"loop":0.0}
		if id=="39" and controls.walking39():return {"definition":"1","selector":1,"time":float(controls.state.walk_clock),"loop":1.75}
	return super.pose(id)
