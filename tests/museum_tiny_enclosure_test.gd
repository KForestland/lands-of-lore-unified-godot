extends SceneTree
## Museum Long arm chute softlock (docs/museum-tiny-enclosure.md), owner r3 report 2026-10-20T11-20-57: a human at the
## quicksaved spot (-1771.8, -10.56, -1088) in sludge region 965 cannot climb out (967 is 30 high) and cannot leave
## downhill (958 is 20 high). The enclosure gives the held tiny form back; the lizard climbs out through 967 and the
## duct mouth returns it to human. A timed form running out inside the chute waits (tiny kept); beast is refused too.
## Negative control: without the hook the same expiry makes the player human inside the chute.
const Body = preload("res://scripts/lol2/player_form_body.gd")
const Curse = preload("res://scripts/lol2/player_curse.gd")
const Save = preload("res://scripts/lol2/museum_save.gd")
const STUCK := Vector3(-1771.813, -10.56, -1088.045)
func _initialize() -> void:
	_run.call_deferred()

func fail(message: String) -> void:
	push_error(message); print("FAIL " + message); quit(1)

## The Museum walking controller (museum_review._physics_process) without input polling.
func walk(scene: Node3D, direction: Vector3, seconds: float) -> void:
	var player: CharacterBody3D = scene.player
	for i in int(seconds * 60):
		await physics_frame
		var delta := 1.0 / 60.0
		player.velocity.x = direction.x * 80
		player.velocity.z = direction.z * 80
		player.velocity.y = 0.0 if player.is_on_floor() else player.velocity.y - 320 * delta
		if player.velocity.y <= 0 and preload("res://scripts/lol2/walk_step.gd").try_step(player, Vector3(player.velocity.x, 0, player.velocity.z) * delta):
			player.velocity.x = 0
			player.velocity.z = 0
		player.move_and_slide()

func place(scene: Node3D, form: int, position: Vector3) -> void:
	Body.apply(scene.player, scene.camera, form, false)
	scene.player_form = form
	scene.curse.restore(Curse.initial())
	scene.player.global_position = position
	for i in 10: await physics_frame

func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	for i in 5: await physics_frame
	var enclosure = scene.tiny_enclosure
	if not is_instance_valid(enclosure): return fail("Tiny enclosure owner missing")
	enclosure.set_physics_process(false)
	if is_instance_valid(scene.long_arm): scene.long_arm.set_physics_process(false)
	scene.curse.set_physics_process(false)
	# Reproduce the report: human at the quicksave spot cannot climb out.
	await place(scene, 0, STUCK)
	if not enclosure.inside(): return fail("Report position not inside the chute")
	await walk(scene, Vector3.LEFT, 3.0)
	if scene.player.global_position.x < -1790: return fail("Human climbed out of the chute (x %.1f)" % scene.player.global_position.x)
	# Rescue: held tiny form, valid save mid-warning, morph after the warning.
	if not enclosure.rescue(): return fail("Rescue refused")
	if int(scene.curse.state.phase) != 1 or int(scene.curse.state.target) != 2 or float(scene.curse.state.duration) != 0.0: return fail("Rescue did not request the held tiny form")
	if not Curse.valid(scene.curse.snapshot(), scene.player_form): return fail("Rescue curse state invalid for saves")
	var mid: Dictionary = scene.capture_exhibit_retry()
	if not Save.validate(mid).is_empty(): return fail("Mid-rescue save invalid: " + Save.validate(mid))
	if enclosure.rescue(): return fail("Rescue repeated while pending")
	scene.curse.advance(Curse.WARNING_SECONDS + 0.1)
	if scene.player_form != 2 or int(scene.curse.state.phase) != 0: return fail("Tiny form not applied (form %d phase %d)" % [scene.player_form, scene.curse.state.phase])
	# The lizard climbs out past 967 into the duct mouth.
	await walk(scene, Vector3.LEFT, 4.0)
	var out: Vector3 = scene.player.global_position
	if out.x > -1836 or enclosure.inside(): return fail("Tiny form did not climb out (at %s)" % out)
	# Past the duct mouth (region1463 op2 sub0x3C), in the hall: the human return is not blocked outside the chute.
	# The corridor west of the mouth is 35 wide; stand mid-corridor so the human body has side room.
	await place(scene, 2, Vector3(-1930, Body.FOOT_OFFSET + 1, -1096.5))
	if enclosure.inside() or not scene.curse.request_human(): return fail("Human request refused in the hall")
	scene.curse.advance(0.1)
	if scene.player_form != 0: return fail("Human return blocked in the hall at %s" % out)
	# Timed form expiry inside the chute keeps tiny form (waits as if there were no room); beast is refused too.
	# Region 964: flat bottom of the north side lane (floor -160, ceiling -100), where a human body has room to appear.
	await place(scene, 2, Vector3(-1625, -160 + Body.FOOT_OFFSET + 0.5, -1065))
	if not enclosure.inside(): return fail("Region 964 not inside the chute")
	scene.curse.state.merge({"phase":2,"previous":0,"target":2,"remaining":0.5,"duration":60.0}, true)
	scene.curse.advance(1.0)
	if scene.player_form != 2 or int(scene.curse.state.phase) != 3: return fail("Expiry inside the chute did not wait (form %d phase %d)" % [scene.player_form, scene.curse.state.phase])
	if enclosure.rescue(): return fail("Rescue with a return pending")
	scene.curse.state.merge({"phase":1,"previous":2,"target":1,"remaining":0.0,"duration":60.0}, true)
	scene.curse.advance(0.1)
	if scene.player_form != 2: return fail("Beast morph allowed inside the chute")
	# Negative control: without the hook the expiry makes the player human inside the chute (the reported trap).
	scene.tiny_enclosure = null
	scene.curse.state.merge({"phase":3,"previous":2,"target":0,"remaining":0.0,"duration":0.0}, true)
	scene.curse.advance(0.1)
	if scene.player_form != 0: return fail("Negative control: expiry did not make the player human in the chute (phase %d target %d at %s)" % [scene.curse.state.phase, scene.curse.state.target, scene.player.global_position])
	scene.tiny_enclosure = enclosure
	print("PASS museum tiny enclosure: report spot rescued, climbed out to x %.1f, mouth return, expiry/beast held, control trapped" % out.x)
	quit(0)
