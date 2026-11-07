extends SceneTree
## Actual Cave host: a grounded walk from the CFALL op18 point (536, -11154) into the entry regions (1815 first) opens room 32 (the
## waterfall pool); the world pauses, saves are refused, a pool click heals 5; Back leaves and the op18 placement puts
## the player back on the floor outside the regions; a second walk in opens the room again without the first-visit quip.
const Body = preload("res://scripts/lol2/player_form_body.gd")
var cave
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); quit(1)
func host_point(x: float, z: float) -> Vector3: return Vector3(x, 0, z) + cave.native_translation
func step(dir: Vector3, frames: int) -> void:
	for i in frames:
		if paused: return
		cave.player.velocity.x = dir.x * cave.WALK_SPEED
		cave.player.velocity.z = dir.z * cave.WALK_SPEED
		cave.player.velocity.y = 0.0 if cave.player.is_on_floor() else cave.player.velocity.y - 128.0 / 60.0
		cave.player.move_and_slide()
		# The host's physics step calls this with the same arguments (cave_walkthrough.gd, world-active branch).
		cave.cfall_room.advance(cave.player.global_position - cave.native_translation, cave.player.is_on_floor())
		await physics_frame
func walk_in(target: Vector2) -> bool:
	for i in 300:
		if cave.cfall_room.active(): return true
		var d: Vector3 = host_point(target.x, target.y) - cave.player.global_position; d.y = 0
		if d.length() < 3.0: break
		await step(d.normalized(), 1)
	return cave.cfall_room.active()
func stand_at(x: float, z: float) -> void:
	var p := host_point(x, z)
	var ray := PhysicsRayQueryParameters3D.create(p + Vector3(0, -150, 0), p - Vector3(0, 400, 0), 1, [cave.player.get_rid()])
	var hit: Dictionary = cave.get_world_3d().direct_space_state.intersect_ray(ray)
	cave.player.global_position = (hit.position if not hit.is_empty() else p + Vector3(0, -192, 0)) + Vector3.UP * Body.FOOT_OFFSET
	cave.player.velocity = Vector3.ZERO
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture")
	root.get_texture().get_image().save_png("user://capture/%s.png" % name)
func run() -> void:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	if cave.cfall_room == null: return fail("CFALL room owner missing (media not staged?)")
	cave.set_physics_process(false); cave.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stand_at(536, -11154)
	for i in 10: await step(Vector3.ZERO, 1)
	var start: Vector3 = cave.player.global_position - cave.native_translation
	if absf(start.y - Body.FOOT_OFFSET + 192.0) > 6.0: return fail("op18 point is not on the -192 floor: %s" % start)
	if not await walk_in(Vector2(625, -11120)): return fail("Walking into the entry regions did not open CFALL: %s" % (cave.player.global_position - cave.native_translation))
	var room = cave.cfall_room
	if not paused or cave.video_overlay != room or int(room.state.flags["5"]) != 1: return fail("Room did not take the world")
	if cave._quicksave("user://tests/cave_cfall_refused.json").is_empty(): return fail("Save allowed inside CFALL")
	for i in 20: await process_frame
	await capture("cfall_room")
	while room.skip_line(): pass
	cave.starting_magic.set_health(10)
	if not room.click(Vector2i(480, 360)) or cave.starting_magic.health() != 15: return fail("Pool click did not heal 5: %d" % cave.starting_magic.health())
	while room.skip_line(): pass
	var entered: int = room.region
	var place: Dictionary = {}
	for row in room.src.regions:
		if int(row.region) == entered: place = row.place
	if place.is_empty(): return fail("Unknown entry region %d" % entered)
	if int(room.state.flags["6"]) != 1 or not room.leave_room(): return fail("Leave refused")
	if paused or is_instance_valid(cave.video_overlay): return fail("World not resumed")
	for i in 10: await step(Vector3.ZERO, 1)
	var after: Vector3 = cave.player.global_position - cave.native_translation
	if Vector2(after.x - float(place.x), after.z + float(place.y)).length() > 4.0 or absf(after.y - Body.FOOT_OFFSET + 192.0) > 6.0: return fail("op18 placement for region %d: %s" % [entered, after])
	await capture("cfall_after")
	var saved: Dictionary = cave._save_state()
	if saved.get("cave_cfall", {}).get("flags", {}).get("6") != 1: return fail("Save lacks CFALL flags")
	if not await walk_in(Vector2(640, -11140)): return fail("Second entry did not reopen CFALL")
	if room.speaking(): return fail("First-visit quip repeated")
	room.leave_room()
	print("PASS cave CFALL live: walk from the op18 point into the entry regions opens room32 (paused world, save refused), pool heals 5, Back + the entry region's op18 places the player on the -192 floor, flags saved, re-entry without the first-visit quip.")
	cave.queue_free(); await process_frame; quit()
