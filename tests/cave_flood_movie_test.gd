extends SceneTree
## g146 op21 (prop614, movie 29 "flood"): source pins, staged media, and the overlay's pause/skip contract.
const Flood = preload("res://scripts/lol2/cave_flood_movie.gd")
func fail(message: String) -> void:
	push_error(message);quit(1)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Flood.SOURCE))
	if int(data.group)!=146 or data.commands.size()!=15 or str(data.commands[1])!="150366021d00": return fail("g146 op21 pin.")
	if int(data.record.kind)!=8 or int(data.record.value)!=956: return fail("kind-8 value956 owner.")
	var movie: Dictionary=Flood.movie_info()
	if movie.is_empty(): return fail("FLOOD media not staged (tools/prepare_cave_flood_movie.py).")
	if str(movie.name)!="flood" or int(movie.entry)!=14 or int(movie.key)!=486230760 or int(movie.frames)!=200: return fail("Movie identity.")
	if FileAccess.get_sha256(String(movie.path))!=str(movie.sha256): return fail("FLOOD media hash differs.")
	var host:=Node.new();root.add_child(host)
	var overlay=Flood.new();var reasons: Array=[]
	overlay.ended.connect(func(r: String): reasons.append(r))
	host.add_child(overlay)
	if not paused or not overlay.video.is_playing(): return fail("FLOOD must pause the world and play.")
	await process_frame
	if not paused: return fail("World resumed during the movie.")
	overlay.close("skipped")
	if paused or reasons!=["skipped"]: return fail("Skip must resume the world once: "+str(reasons))
	await process_frame
	if is_instance_valid(overlay): return fail("Overlay not freed.")
	print("PASS cave FLOOD movie: g146 op21 movie29 pinned, L1_DCI entry14 staged (200 frames, hash), overlay pauses the world, skip resumes it once.")
	quit()
