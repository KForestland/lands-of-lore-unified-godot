extends "res://tests/dark_halls_earned_detour_test.gd"
## Ordinary use on a visible closed leaf along the route; no lock/health/state mutation.
func open_route_leaf(target: Vector2) -> void:
	var p: Vector3 = scene.player.position
	var onward := (target - Vector2(p.x, p.z)).normalized()
	for owner in [scene.bookcases, scene.doors]:
		var rows: Array = owner.source.controls if owner == scene.bookcases else owner.source.doors
		for row in rows:
			var id: String = str(int(row.control if owner == scene.bookcases else row.movable))
			if owner.is_open(id): continue
			var point: Vector3 = Vector3(row.center[0], row.center[1], row.center[2]) if owner == scene.bookcases else Vector3(row.origin[0], row.origin[1] + row.size[1] * 0.5, row.origin[2])
			var offset: Vector3 = point - scene.camera.global_position
			if offset.length() > 100 or Vector2(offset.x, offset.z).normalized().dot(onward) < 0.2: continue
			look_toward(point)
			await physics_frame
			if owner.aimed() == id:
				await capture("route_" + id + "_closed")
				await tap(KEY_E)
				await capture("route_" + id + "_open")
				if owner.is_open(id): note("Earned route opening " + owner.name + ":" + id)

func walk_to(target: Vector2, tolerance: float, max_frames: int, tag: String, combat: bool = true, stuck_ok: bool = false) -> bool:
	var best := INF
	var since_best := 0
	for frame in max_frames:
		var leaving: Node = scene.get_node_or_null("DarkHallsRoute") if is_instance_valid(scene) else null
		if not is_instance_valid(scene) or current_scene != scene or (leaving != null and bool(leaving.transitioning)):
			# A level change hands over to the next scene: let go of the keys, as a player does on a loading screen.
			release_keys()
			return true
		var rooms: Node = scene.get("monastery") if scene.get("monastery") != null and is_instance_valid(scene.get("monastery")) else null
		var leaving_movie: Node = scene.get("departure") if scene.get("departure") != null and is_instance_valid(scene.get("departure")) else null
		if (rooms != null and rooms.active()) or (leaving_movie != null and leaving_movie.active()):
			# A room view or the departure movie took over (walking into its source region): stop; the caller decides.
			release_keys()
			return true
		await ensure_captured()
		await open_route_leaf(target)
		trace_health(tag)
		if health() <= 0: return fail("Player fell while walking at %s" % tag)
		var p: Vector3 = scene.player.position
		var offset := target - Vector2(p.x, p.z)
		var d := offset.length()
		if d < tolerance:
			set_key(KEY_W, false)
			return true
		if combat and not threat(95.0).is_empty():
			set_key(KEY_W, false)
			var left_route := Vector2(p.x, p.z)
			if not await fight(140.0, tag): return false
			# The fight steps toward each creature, off the walked line; a straight line from there to the target can
			# cut through scenery. Go back to where the fight began first, as a player returns to the path.
			var here: Vector3 = scene.player.position
			if Vector2(here.x, here.z).distance_to(left_route) > 8.0 and is_instance_valid(scene) and current_scene == scene:
				if not await walk_to(left_route, 6.0, max_frames, tag + "/rejoin", combat, stuck_ok): return false
			best = INF
			continue
		if d < best - 0.5: best = d; since_best = 0
		else: since_best += 1
		if since_best > 240:
			set_key(KEY_W, false)
			if stuck_ok: return true
			return fail("Walk stuck at %s: %.1f from %s, position %s" % [tag, d, target, p])
		look_toward(Vector3(target.x, p.y, target.y), false)
		set_key(KEY_SHIFT, d > 30.0)
		set_key(KEY_W, true)
		await physics_frame
	set_key(KEY_W, false)
	return fail("Walk timed out at %s" % tag)

