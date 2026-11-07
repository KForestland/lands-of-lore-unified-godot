extends RefCounted
## Portable validation; source durations match original staged frame counts at15fps.
const State=preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
static func validate(packet: Variant) -> String:
	var src:=State.source()
	var guard_source:=Generic.source("res://scripts/lol2/jungle_exit_guard_population_source.json")
	var media=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_exit_movies/movies.json"))
	if not media is Dictionary: return "Missing exit movie timing manifest."
	var clips: Dictionary={};var endings: Dictionary={}
	for row in media.poses: clips[int(row.selector)]={"duration":float(row.duration)}
	for row in media.endings: endings[str(row.movie)]={"duration":float(row.duration)}
	if not packet is Dictionary or packet.get("version")!=1 or packet.size() not in [6,7]: return "Invalid exit encounter packet."
	if packet.has("visibility"):
		var v=packet.visibility
		if not v is Dictionary or v.size()!=2 or not v.get("seen") is bool or not v.get("present") is bool: return "Invalid exit visibility latch."
	var error:=State.validate(packet.get("encounter"),src)
	if not error.is_empty(): return error
	error=Generic.validate(packet.get("guards"),guard_source)
	if not error.is_empty(): return error
	var e: Dictionary=packet.encounter;var g: Dictionary=packet.guards
	if not packet.get("poses") is Dictionary or packet.poses.size()!=3: return "Invalid exit pose clocks."
	for id in State.GUARDS:
		var a: Dictionary=e.actors[id];var b: Dictionary=g.actors[id]
		if bool(a.present)!=bool(b.present) or (a.present and int(a.health)!=int(b.health)): return "Exit guard presentation disagrees with the encounter."
		var t=packet.poses.get(id)
		if not (t is int or t is float) or not is_finite(float(t)): return "Invalid exit pose clock."
		var clip: Dictionary=clips.get(int(a.pose),{})
		if clip.is_empty() != (float(t)==-1.0) or (not clip.is_empty() and (float(t)<0 or float(t)>=float(clip.duration))): return "Exit pose clock disagrees with its pose."
	var m=packet.get("movie")
	if not m is Dictionary or m.size()!=2 or not m.get("phase") is String or m.phase not in ["none","playing","done"]: return "Invalid exit movie."
	var t=m.get("elapsed")
	if not (t is int or t is float) or not is_finite(float(t)) or float(t)<0: return "Invalid exit movie clock."
	if (m.phase=="none")!=e.ending.is_empty(): return "Exit movie disagrees with the ending."
	if m.phase=="playing" and float(t)>=float(endings[str(e.ending.movie)].duration): return "Exit movie clock exceeds the movie."
	if m.phase!="playing" and float(t)!=0: return "Idle exit movie retains a clock."
	if not packet.get("inside") is Array: return "Invalid exit region history."
	var seen: Array=[]
	for r in packet.inside:
		if not State._integer(r,65535) or int(r) not in src.regions.map(func(x):return int(x.region)) or int(r) in seen: return "Invalid exit region history."
		seen.append(int(r))
	return ""

