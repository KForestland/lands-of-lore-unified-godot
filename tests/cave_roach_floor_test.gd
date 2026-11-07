extends SceneTree
## Original bug 8 (ORIGINAL_BUGS_TO_FIX.md): roaches in the Draracle cave clipped into the floor. The port places each source
## roach body on the floor by physics and draws its sprite with its feet at the body origin; this pins both so the bug stays out.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/encounter_directions/animation.json"))
	var units: float = float(manifest.world_units_per_pixel)
	var top: float = float(manifest.centre_offset[1]) + float(manifest.canvas_size[1]) * units / 2.0
	# The eight directional idle views: their lowest drawn row is the feet (one action pose, action_5 frame 807, reaches the
	# canvas bottom, 5.9 units lower; that is the sprite, not the placement).
	var lowest := -INF
	for view in manifest.views:
		var image := Image.load_from_file("res://assets/lol2/generated/encounter_directions/" + str(view.frames[0].png))
		# L8 index frames: index 0 is transparent; get_used_rect would count every pixel.
		for y in range(image.get_height() - 1, -1, -1):
			var drawn := false
			for x in image.get_width():
				if image.get_pixel(x, y).r > 0.0: drawn = true; break
			if drawn: lowest = maxf(lowest, float(y + 1)); break
	var feet := top - lowest * units
	check(feet > -3.0 and feet < 6.0, "the idle views' lowest drawn row sits at the body origin (%.1f units; the sprite's own anchoring)" % feet)
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in 40: await process_frame
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var checked := 0
	for body in scene.find_children("SourceRoach*", "CharacterBody3D", true, false):
		var q := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * 20, body.global_position + Vector3.DOWN * 300, 1, [body.get_rid()])
		var hit: Dictionary = space.intersect_ray(q)
		check(not hit.is_empty() and absf(hit.position.y - body.global_position.y) < 1.0, "%s stands on the floor (body %.1f floor %s)" % [body.name, body.global_position.y, str(hit.get("position", Vector3.INF).y)])
		checked += 1
	check(checked >= 6, "source roaches found (%d)" % checked)
	var population = scene.get("roach_population_host") if scene.get("roach_population_host") != null else scene.find_child("*RoachPopulation*", true, false)
	var lifted: Dictionary = {}
	for node in scene.find_children("*", "", true, false):
		if node.get("lifted") is Dictionary and node.get("bodies") is Dictionary and not (node.get("lifted") as Dictionary).is_empty(): lifted = node.lifted; break
	check(lifted.has("50") and lifted.has("51") and lifted.size() == 2 and lifted["50"] > 7.0 and lifted["51"] > 1.0, "exactly roaches 50 and 51 were lifted onto their sloped floors (%s)" % [lifted])
	scene.queue_free(); await process_frame
	print("Cave roach floor: %d failures" % failures)
	if failures == 0: print("PASS cave roach floor: %d roach bodies on their floors (50 and 51 lifted out of theirs), idle sprite feet at the body origin (original bug 8 fixed)" % checked)
	quit(0 if failures == 0 else 1)
