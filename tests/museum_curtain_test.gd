extends SceneTree
## Museum curtain / control81 (docs/museum-curtain.md): drawn closed at load across the x -3820 doorway; empty-hand E
## from the hall (aimed, in reach) runs g7036 (drawing + sound347) and the drawing end g7076 (gathered, state 1);
## E again runs g7100 (reverse drawing + sound346) and g7152 (closed, state 0). Refusals: held item, looking away.
## Mid-drawing save round trip, malformed states refused, legacy save restores closed. Rendered pixels change.
const Curtain = preload("res://scripts/lol2/museum_curtain.gd")
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize() -> void:
	_run.call_deferred()

func fail(message: String) -> void:
	push_error(message); print("FAIL " + message); quit(1)

func settle(scene: Node3D) -> void:
	for i in range(30):
		await physics_frame
		scene.player.velocity = Vector3(0,-80,0)
		scene.player.move_and_slide()

func face_curtain(scene: Node3D, x: float, z: float) -> void:
	scene.player.position = Vector3(x, scene.player.position.y + 4, z)
	await settle(scene)
	var target: Vector3 = scene.curtain.aim_point()
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	scene.camera.look_at(target)

func shot(scene: Node3D) -> Image:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func changed(a: Image, b: Image) -> int:
	var n := 0
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			var p := a.get_pixel(x, y); var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.15: n += 1
	return n

func run_drawing(scene: Node3D) -> void:
	for i in range(80): scene.curtain.step(1.0 / 60.0)

func _run() -> void:
	var src := Curtain.source()
	if int(src.control) != 81 or src.groups.size() != 4 or not Curtain.assets_ready(): return fail("Source contract / assets")
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	await settle(scene)
	var curtain = scene.curtain
	if not is_instance_valid(curtain): return fail("Curtain owner missing")
	if curtain.checkpoint() != Curtain.initial() or curtain.material.albedo_texture != curtain.textures["closed.png"]: return fail("Not closed at load")
	await face_curtain(scene, -3870, -1084)
	var closed := await shot(scene)
	# Refusals.
	scene.hand_item = "x"
	if curtain.use(): return fail("Used with a held item")
	scene.hand_item = ""
	scene.camera.rotation.y += PI
	if curtain.use(): return fail("Used while looking away")
	await face_curtain(scene, -3870, -1084)
	# g7036: drawing forward, sound347; frame0 is the closed image.
	if not curtain.use(): return fail("Empty-hand use refused (camera %s)" % scene.camera.global_position)
	if curtain.mode != 1 or curtain.owner_state != 0 or curtain.frame() != 0 or not curtain.voice.playing or curtain.voice.stream == null: return fail("g7036 did not start the drawing with sound347")
	curtain.step(0.5)
	var mid: Dictionary = scene.capture_exhibit_retry()
	if mid.checkpoint.museum_curtain.mode != 1 or not Save.validate(mid).is_empty(): return fail("Mid-drawing save")
	var mid_frame: int = curtain.frame()
	if mid_frame != 4: return fail("Drawing frame at 0.5 s is %d" % mid_frame)
	run_drawing(scene)
	if curtain.mode != 2 or curtain.owner_state != 1 or curtain.material.albedo_texture != curtain.textures["gathered.png"]: return fail("g7076 did not gather the curtain")
	var open := await shot(scene)
	var diff := changed(closed, open)
	if diff < 200: return fail("Rendered curtain did not change (%d samples)" % diff)
	# g7100 / g7152: reverse drawing with sound346, back to closed and state 0.
	if not curtain.use(): return fail("Close use refused")
	if curtain.mode != 1 or curtain.owner_state != 1 or curtain.frame() != 7: return fail("g7100 did not start the reverse drawing")
	run_drawing(scene)
	if curtain.checkpoint() != Curtain.initial(): return fail("g7152 did not close the curtain")
	# Restore mid-drawing.
	scene.apply_save(mid)
	if curtain.mode != 1 or curtain.frame() != mid_frame: return fail("Mid-drawing restore")
	run_drawing(scene)
	if curtain.owner_state != 1 or curtain.mode != 2: return fail("Restored drawing did not finish")
	for bad in [{}, [], {"version":1,"owner_state":0,"mode":2,"clock":0.0}, {"version":1,"owner_state":1,"mode":0,"clock":0.0},
			{"version":1,"owner_state":0,"mode":1,"clock":1.0}, {"version":1,"owner_state":1,"mode":2,"clock":0.5},
			{"version":2,"owner_state":0,"mode":0,"clock":0.0}, {"version":1,"owner_state":0,"mode":0,"clock":0.0,"x":1}]:
		var copy: Dictionary = mid.duplicate(true)
		copy.checkpoint.museum_curtain = bad
		if Save.validate(copy).is_empty(): return fail("Accepted bad curtain state " + str(bad))
	var legacy: Dictionary = mid.duplicate(true)
	legacy.checkpoint.erase("museum_curtain")
	if not Save.validate(legacy).is_empty(): return fail("Legacy save rejected")
	scene.apply_save(legacy)
	if curtain.checkpoint() != Curtain.initial(): return fail("Legacy save did not restore the curtain closed")
	# Owner r5 report 2026-10-20: a carried Stalagmite in the hand. E puts it away and opens the curtain; prompt shown.
	await face_curtain(scene, -3870, -1084)
	var held := "cave:prop144:harvest1:Stalagmite"
	if not held in scene.carried_collected: scene.carried_collected.append(held)
	scene.hand_item = held
	if curtain.interaction_hint() != "": return fail("Hint shown with a held item")
	scene.hand_item = ""
	if curtain.interaction_hint() != "E — Open curtain": return fail("Empty-hand hint is '%s'" % curtain.interaction_hint())
	scene.hand_item = held
	if scene._use_world(): return fail("Held-item E used the world directly")
	if not scene._use_world_with_hand_stowed() or curtain.mode != 1 or scene.hand_item != "" or not held in scene.carried_collected: return fail("Held Stalagmite did not stow and open the curtain")
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("PASS museum curtain: closed at load; E (empty hand, aimed) g7036 drawing+347 -> g7076 gathered; E g7100 reverse+346 -> g7152 closed; refusals; mid-drawing/legacy saves; %d rendered samples changed" % diff)
	quit()
