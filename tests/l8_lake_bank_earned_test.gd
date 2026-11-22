extends SceneTree
## BJ12 (owner F10 2026-11-10T00-02-13 at (5372,2889), H -486: "under water, does not die -> stuck"). The east gorge of the
## Darker Jungle is 600 deep (regions 3301/3320, floor -550). Luther walks off the west bank (region 3302) on foot, sinks,
## drowns on the 15 s clock, and the real R key puts him back on the bank he last stood on - not on the bed, where he
## drowned again at once. Then the owner's own spot: the body is set down over region 3320 (TELEPORT, the F10 place has
## no walkable rim) and R again returns to the last dry ground.
const Save = preload("res://scripts/lol2/act2_save.gd")
const INPUT := "~/AI_COMMS/act1_completion_20261017/r12w_qualification/campaign/userdata/act1_dark_halls_darker_arrival.json"
const BANK := Vector3(5130, 32, 1881)
var failures := 0
var scene: Node
func check(ok: bool, message: String) -> bool:
	if not ok: failures += 1; print("FAIL L8 lake bank: ", message)
	return ok
func _initialize(): run.call_deferred()
func key(code: int) -> void:
	var d := InputEventKey.new(); d.keycode = code; d.physical_keycode = code; d.pressed = true; Input.parse_input_event(d); Input.flush_buffered_events()
	await process_frame
	var u := InputEventKey.new(); u.keycode = code; u.physical_keycode = code; u.pressed = false; Input.parse_input_event(u); Input.flush_buffered_events()
	await process_frame
## Drowns where the body is, presses R, and checks the bank. Returns the place Luther stands afterwards.
func drown_and_recover(label: String, dry: Vector3) -> void:
	var water = scene.liquid_drowning
	var dead := false
	for i in 6000:
		await physics_frame
		if water.drowning.dead: dead = true; break
	if not check(dead and scene.starting_magic.health() == 0, "%s: the water kills (clock %s, at %s)" % [label, str(water.drowning.elapsed), str(scene.player.position.round())]): return
	for i in 240: await physics_frame
	check(not water.polygon_at(scene.player.global_position).is_empty(), "%s: the body lies in the water until R (%s)" % [label, str(scene.player.position.round())])
	await key(KEY_R)
	for i in 30: await physics_frame
	var at: Vector3 = scene.player.global_position
	check(scene.starting_magic.health() == 30, "%s: R revives (health %d)" % [label, scene.starting_magic.health()])
	check(water.polygon_at(at).is_empty() and at.distance_to(dry) < 60.0, "%s: R puts Luther on the bank he last stood on (%s, bank %s)" % [label, str(at.round()), str(dry.round())])
	# The loop the owner met: revived in the water, drowned again. A full clock and more on the bank: alive.
	for i in 20 * 60: await physics_frame
	check(not water.drowning.dead and scene.starting_magic.health() == 30 and scene.player.global_position.distance_to(dry) < 80.0, "%s: no second drowning after the recovery (%s)" % [label, str(scene.player.position.round())])
func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var source := Save.read_save(INPUT, "lol2-restoration-darker-jungle")
	if not check(source.error.is_empty(), "earned save validates: " + str(source.error)): quit(1); return
	set_meta("lol2_darker_resume", source.state); Engine.set_meta("lol2_enhanced", false)
	scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.ready_for_review, "production scene ready"): quit(1); return
	scene.starting_magic.interface_request = true
	var water = scene.liquid_drowning
	if not check(is_instance_valid(water), "the level has its liquids"): quit(1); return
	# 1. The west bank of the gorge (TELEPORT: the start is a long walk away; the walk into the water is on foot).
	print("TELEPORT the west bank of the gorge, region 3302")
	scene.player.position = BANK; scene.player.velocity = Vector3.ZERO
	for i in 120: await physics_frame
	var dry: Vector3 = scene.player.global_position
	if not check(scene.player.is_on_floor() and water.polygon_at(dry).is_empty() and water.last_dry.distance_to(dry) < 5.0, "Luther stands dry on the bank (%s, last dry %s)" % [str(dry.round()), str(water.last_dry.round())]): quit(1); return
	scene.player.set_physics_process(false); scene.set_physics_process(false)
	for i in 2400:
		scene.move_grounded(Vector3(1, 0, 0), 1.0 / 60.0); await physics_frame
		if not water.polygon_at(scene.player.global_position).is_empty() and scene.player.position.x > dry.x + 60.0: break
	scene.player.set_physics_process(true); scene.set_physics_process(true)
	dry = water.last_dry
	if not check(not water.polygon_at(scene.player.global_position).is_empty(), "walking east off the bank ends in the water (%s)" % str(scene.player.position.round())): quit(1); return
	await drown_and_recover("the walk off the bank", dry)
	# 2. The owner's F10 spot.
	dry = scene.player.global_position
	print("TELEPORT the owner's F10 spot over region 3320")
	scene.player.position = Vector3(5372, 60, 2889); scene.player.velocity = Vector3.ZERO
	await drown_and_recover("the F10 spot", dry)
	check(int(scene.get("resets")) == 0, "no fall recovery (%s)" % str(scene.get("resets")))
	scene.queue_free(); await process_frame
	if failures == 0: print("PASS L8 lake: on foot off the bank -> sinks -> drowns -> R -> back on the bank, no drown loop; the F10 spot the same")
	quit(0 if failures == 0 else 1)
