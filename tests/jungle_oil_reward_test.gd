extends SceneTree
## Vine-clearing oil pool (prepare_jungle_oil_fire.py): the 15 flames are dark at the start; the production Spark ray
## (player_starting_magic.spark) aimed at the rock pile prop1350 lights all of them; a second Spark changes nothing;
## the lit state survives quicksave/quickload; an invalid saved state is rejected.
const Save = preload("res://scripts/lol2/jungle_save.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL jungle_oil_fire: ", message); quit(1); return false
func run() -> void:
	change_scene_to_file("res://scenes/lol2/jungle_walkthrough.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Jungle not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var fire = scene.oil_fire
	if fire == null or fire.flames.size() != 15: return fail("Oil fire host missing")
	if not fire.source.hit.commands.has("020100000c01"): return fail("Native magic100 source command missing")
	for flame in fire.flames:
		if flame.visible: return fail("A flame burns before the Spark")
	scene.set_physics_process(false)
	var target: Vector3 = fire.get_node("PileReceiver").global_position
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var placed := false
	for angle in range(0, 360, 30):
		var eye := target + Vector3(cos(deg_to_rad(angle)) * 160.0, 40.0, sin(deg_to_rad(angle)) * 160.0)
		var clear := PhysicsRayQueryParameters3D.create(eye, target, 1, [scene.player.get_rid()])
		if not space.intersect_ray(clear).is_empty(): continue
		scene.player.global_position = eye - (scene.camera.global_position - scene.player.global_position)
		scene.player.velocity = Vector3.ZERO
		await physics_frame
		scene.camera.look_at(target)
		await physics_frame
		placed = true
		break
	if not placed: return fail("No clear line of sight to the rock pile")
	var before: Dictionary = scene.starting_magic.magic_state().duplicate(true)
	if int(before.player.experience) != 0 or int(before.player.level) != 1: return fail("Unexpected initial magic fixture")
	scene.starting_magic.spark()
	if int(scene.starting_magic.magic_state().player.experience) != 100: return fail("Oil fire did not grant exactly 100 magic experience")
	if not fire.lit(): return fail("Spark did not light the oil")
	for flame in fire.flames:
		if not flame.visible: return fail("A flame stayed dark after the Spark")
	var rewarded: Dictionary = scene.starting_magic.magic_state().duplicate(true)
	if fire.ignite(): return fail("Second hit lit again")
	if scene.starting_magic.magic_state() != rewarded: return fail("Repeated ignition changed magic")
	var path := "user://tests/jungle_oil_fire.json"
	if not scene.quicksave(path).is_empty(): return fail("Quicksave failed")
	var saved := Save.read_save(path)
	if not str(saved.error).is_empty(): return fail("Read save: " + str(saved.error))
	scene.quest_state.jungle_oil_fire = {"lit": false}
	fire.present()
	var error: String = scene.apply_save(saved.state)
	if not error.is_empty() or not fire.lit() or not fire.flames[0].visible: return fail("Reload lost the fire: %s" % error)
	if int(scene.starting_magic.magic_state().player.experience) != 100: return fail("Reload lost magic reward")
	var reloaded: Dictionary = scene.starting_magic.magic_state().duplicate(true)
	if fire.ignite() or scene.starting_magic.magic_state() != reloaded: return fail("Reload enabled duplicate reward")
	# Existing lit saves get no retroactive reward, and no second ignition.
	scene.starting_magic.commit(before.duplicate(true))
	fire.present()
	if fire.ignite() or scene.starting_magic.magic_state() != before: return fail("Legacy lit state received a retroactive reward")
	# Failed award leaves the unlit puzzle retryable and the invalid checkpoint untouched.
	scene.quest_state.jungle_oil_fire = {"lit": false}
	var invalid := before.duplicate(true)
	invalid.player.experience = -1
	scene.starting_magic.commit(invalid)
	if fire.ignite() or fire.lit() or scene.starting_magic.magic_state() != invalid: return fail("Rejected award mutated state")
	scene.starting_magic.commit(before.duplicate(true))
	if not fire.ignite() or int(scene.starting_magic.magic_state().player.experience) != 100: return fail("Failed award was not retryable")
	var bad: Dictionary = saved.state.quests.duplicate(true)
	bad.jungle_oil_fire = {"lit": 1}
	if preload("res://scripts/lol2/act_one_quest_state.gd").validate(bad).is_empty(): return fail("Invalid fire state accepted")
	print("PASS jungle_oil_reward: 100 XP once, reload preserves it, legacy lit not rewarded, failed award retryable; 15 flames dark, production Spark at prop1350 lights all, second hit inert, kept across quicksave/quickload, bad state rejected")
	quit(0)
