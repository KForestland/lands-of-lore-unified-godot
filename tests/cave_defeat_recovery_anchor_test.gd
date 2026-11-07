extends SceneTree
## Playtest 2026-10-17 report11-01-44 ("can't move here, I just froze"): at the roach nest the owner (13 HP) was
## killed, R revived them in place inside the awake nest and they were killed again. Production scene and input;
## SUPPLIED: owner poses from three reports, owner health13, and the nest wake (State.first_contact, the same call
## that entering source region1140 makes). Damage comes only from the real roach attacks.
## r3 2026-10-29: under the native disposition (docs/cave-roach-disposition.md) a woken nest Wanders from a human
## Luther and never attacks, so the 10-17 death is not reachable as a human. r4 2026-10-29: the native lizard row
## applies again, so the nest attacks a lizard Luther on sight (row 19 -> Destroy). SUPPLIED: player_form 2.
const State = preload("res://scripts/lol2/cave_roach_population_state.gd")
## Report poses (map X/Y/H) -> Godot = (X+4, H+430, Y+12794).
const SAFE_EARLIER := Vector3(1358.0, 247.0, 565.0)   # report11-02-43 (1354,-12229,-183)
## report11-00-00 (1084,-11597,-183) stood ~190 from actor40's spawn (899,215,1200). With the native disposition
## actor40 Wanders within WANDER_LEASH 160 of its spawn, so that pose is no longer reliably in its range. r3 uses a
## pose 30 units from the spawn toward the report pose: any wander position stays inside RECOVERY_CLEARANCE 200,
## and the test checks that premise against actor40's live body before R.
const NEAR_ACTOR40 := Vector3(929.0, 247.0, 1199.5)
const NEST := Vector3(511.747, 247.05, 601.256)       # report11-01-44 (507.7,-12192.7,-182.9)
var failed := false
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	failed = true; push_error(message); print("FAIL cave_defeat_recovery_anchor: ", message); quit(1); return false
func stand(scene, at: Vector3, frames: int) -> void:
	scene.player.global_position = at
	scene.player.velocity = Vector3.ZERO
	for i in frames: await physics_frame
func run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for frame in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	if scene.development_mode: return fail("development_mode must be false (pass --demo-interface)")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await stand(scene, SAFE_EARLIER, 60)
	await stand(scene, NEAR_ACTOR40, 60)
	if scene.recovery_trail.size() < 2: return fail("Trail did not sample grounded poses: %d" % scene.recovery_trail.size())
	var nest_frames := 0
	scene.player.global_position = NEST
	scene.player.rotation.y = -1.018
	scene.roach.model.player_health = 13
	if not State.first_contact(scene.roach_population, 1140): return fail("Nest already awake")
	if State.dispose(scene.roach_population, "27", 0, true) != State.GOAL_WANDER: return fail("Native control: a woken nest Roach must Wander from a human Luther")
	scene.player_form = 2
	while scene.roach.model.player_health > 0 and nest_frames < 1800:
		await physics_frame; nest_frames += 1
	if scene.roach.model.player_health > 0: return fail("Nest did not attack")
	for i in 3: await process_frame
	if not scene.defeat_notice.visible or not scene.defeat_notice.text.begins_with("You fell"): return fail("No centred defeat notice")
	if not scene.hud_prompt().begins_with("You fell"): return fail("Hint lost its 'You fell' prefix: " + scene.hud_prompt())
	var death_at: Vector3 = scene.player.global_position
	var actor40: Vector3 = scene.roach_population_live.bodies["40"].global_position
	if State.dormant(scene.roach_population, "40") or Vector2(actor40.x-NEAR_ACTOR40.x, actor40.z-NEAR_ACTOR40.z).length() >= scene.RECOVERY_CLEARANCE:
		return fail("Premise: actor40 (%s) must be awake and inside the clearance of the newer trail pose" % actor40)
	var key := InputEventKey.new(); key.keycode = KEY_R; key.pressed = true
	Input.parse_input_event(key); Input.flush_buffered_events()
	for i in 2: await physics_frame
	var revived_at: Vector3 = scene.player.global_position
	if scene.roach.model.player_health != 30: return fail("R did not restore health: %d" % scene.roach.model.player_health)
	if scene.defeat_notice.visible: return fail("Defeat notice stayed up after R")
	if revived_at.distance_to(death_at) < 100: return fail("R revived in place (%.1f units)" % revived_at.distance_to(death_at))
	if Vector2(revived_at.x-SAFE_EARLIER.x, revived_at.z-SAFE_EARLIER.z).length() > 1.0:
		return fail("R chose %s, expected the safe earlier pose (the newer pose is in actor40's range)" % revived_at)
	for h in scene._awake_hostile_positions():
		if Vector2(h.x-revived_at.x, h.z-revived_at.z).length() < scene.RECOVERY_CLEARANCE: return fail("Revived next to an awake hostile at %s" % h)
	var survive := 0
	while survive < 600 and scene.roach.model.player_health == 30:
		await physics_frame; survive += 1
	if scene.roach.model.player_health != 30: return fail("Killed again %d frames after R" % survive)
	print("PASS cave_defeat_recovery_anchor: nest death in %d frames with centred notice; real R revived %.0f units away at the newest safe pose (skipped the pose in actor40's range); 600 physics frames unharmed" % [nest_frames, revived_at.distance_to(death_at)])
	scene.queue_free(); await process_frame; quit()
