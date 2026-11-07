extends SceneTree
## Museum wheel door / control80 (docs/museum-wheel-door.md): linked and solid at load across doorway region1232; from
## the west room the closed curtain takes the click; once gathered, empty-hand E with a level gaze (no look_at) runs
## g7008 (phase group + sound342) and the group end g7030 unlinks it, opening the passage. Use from the east face.
## Refusals: held item, looking away. Mid-group save round trip, malformed states refused, legacy save restores linked.
## Rendered pixels change; the owned assembly is not also drawn by the generic static pass.
const WheelDoor = preload("res://scripts/lol2/museum_wheel_door.gd")
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

## Level gaze along +x (east) or -x (west); no aiming at the target.
func stand(scene: Node3D, x: float, z: float, east: bool) -> void:
	scene.player.position = Vector3(x, scene.player.position.y + 4, z)
	await settle(scene)
	scene.player.rotation = Vector3(0, -PI / 2 if east else PI / 2, 0)
	scene.camera.rotation = Vector3.ZERO

func walk_east(scene: Node3D, frames: int) -> void:
	for i in range(frames):
		await physics_frame
		scene.player.velocity = Vector3(160, -80, 0)
		scene.player.move_and_slide()

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

func run_group(scene: Node3D) -> void:
	for i in range(200): scene.wheel_door.step(1.0 / 60.0)

func _run() -> void:
	var src := WheelDoor.source()
	if int(src.control) != 80 or src.faces.size() != 6 or src.frames.size() != 40 or not WheelDoor.assets_ready(): return fail("Source contract / assets")
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	await settle(scene)
	var door = scene.wheel_door
	if not is_instance_valid(door): return fail("Wheel door owner missing")
	if door.checkpoint() != WheelDoor.initial() or not door.visible or door.body.collision_layer != 1: return fail("Not linked and solid at load")
	if is_instance_valid(scene.get("static_assemblies")):
		for child in scene.static_assemblies.get_children():
			if str(child.name).begins_with("Assembly80_"): return fail("Generic static pass also draws assembly80")
	# Solid: walking east from the west room stops at the west face (x -3815).
	await stand(scene, -3870, -1091, true)
	await walk_east(scene, 60)
	if scene.player.position.x > -3815: return fail("Walked through the linked wheel door (x %.1f)" % scene.player.position.x)
	# The closed curtain hangs in front of it on the west side and takes the click.
	await stand(scene, -3870, -1091, true)
	if door.use(): return fail("Used through the closed curtain")
	if not scene.curtain.use(): return fail("Curtain refused from the west room")
	for i in range(80): scene.curtain.step(1.0 / 60.0)
	if int(scene.curtain.mode) != 2: return fail("Curtain did not gather")
	var linked_view := await shot(scene)
	# Refusals.
	scene.hand_item = "x"
	if door.use(): return fail("Used with a held item")
	scene.hand_item = ""
	scene.camera.rotation.y += PI
	if door.use(): return fail("Used while looking away")
	scene.camera.rotation = Vector3.ZERO
	# g7008: level gaze, phase group + sound342.
	if not door.use(): return fail("Empty-hand level-gaze use refused (camera %s)" % scene.camera.global_position)
	if door.state != 1 or door.frame() != 0 or not door.voice.playing or door.voice.stream == null: return fail("g7008 did not start the group with sound342")
	door.step(1.0)
	var mid: Dictionary = scene.capture_exhibit_retry()
	if mid.checkpoint.museum_wheel_door.state != 1 or not Save.validate(mid).is_empty(): return fail("Mid-group save")
	var mid_frame: int = door.frame()
	if mid_frame != 15: return fail("Group frame at 1.0 s is %d" % mid_frame)
	if door.wheel_material.albedo_texture != door.frames[15]: return fail("Wheel face not showing frame 15")
	run_group(scene)
	if door.state != 2 or door.visible or door.body.collision_layer != 0: return fail("g7030 did not unlink the door")
	var open_view := await shot(scene)
	var diff := changed(linked_view, open_view)
	if diff < 200: return fail("Rendered door did not change (%d samples)" % diff)
	await walk_east(scene, 60)
	if scene.player.position.x < -3795: return fail("Passage still blocked after unlink (x %.1f)" % scene.player.position.x)
	if door.use(): return fail("Unlinked door used again")
	# Restore mid-group, then finish.
	scene.apply_save(mid)
	if door.state != 1 or door.frame() != mid_frame or not door.visible: return fail("Mid-group restore")
	run_group(scene)
	if door.state != 2: return fail("Restored group did not finish")
	# East face: usable from the hall whatever the curtain does.
	scene.curtain.restore(null)
	door.restore(null)
	await stand(scene, -3770, -1091, false)
	if not door.use(): return fail("East-face use refused (camera %s)" % scene.camera.global_position)
	for bad in [{}, [], {"version":1,"state":3,"clock":0.0}, {"version":1,"state":2,"clock":0.5}, {"version":1,"state":1,"clock":3.0},
			{"version":2,"state":0,"clock":0.0}, {"version":1,"state":0,"clock":0.0,"x":1}, {"version":1,"state":0.5,"clock":0.0}]:
		var copy: Dictionary = mid.duplicate(true)
		copy.checkpoint.museum_wheel_door = bad
		if Save.validate(copy).is_empty(): return fail("Accepted bad wheel door state " + str(bad))
	var legacy: Dictionary = mid.duplicate(true)
	legacy.checkpoint.erase("museum_wheel_door")
	if not Save.validate(legacy).is_empty(): return fail("Legacy save rejected")
	scene.apply_save(legacy)
	if door.checkpoint() != WheelDoor.initial() or not door.visible: return fail("Legacy save did not restore the door linked")
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("PASS museum wheel door: linked+solid at load; closed curtain takes the click; gathered -> level-gaze E g7008 group+342, g7030 unlinks and the passage opens; east-face use; refusals; mid-group/legacy saves; %d rendered samples changed" % diff)
	quit()
