extends SceneTree
## Owner F10 2026-10-24 18:43 (Dark Halls): "cant hit the skely rats". The Rat body (also the strike target) was a
## 6-radius ball under a sprite about 35 wide and 22 tall, so aiming at the visible rat missed. Aimed at points on the
## drawn Rat (upper body, both flanks), the production strike ray must find it; Rat, ROACH and WORM looks must cover
## their front-view sprite.
const SCALE := 0.21818181818181817
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL small_creature_hit_size: ", message); quit(1)

func run() -> void:
	# Front-view sprite size (pixels: width, height above floor_row) from the original frames, per look.
	var looks := {
		"Rat": [preload("res://scripts/lol2/dark_halls.gd").CREATURE_CONFIG.look["1"], 147, 99],
		"Museum Rat": [preload("res://scripts/lol2/museum_skeleton_population.gd").MUSEUM_CONFIG.look["1"], 147, 99],
		"ROACH": [preload("res://scripts/lol2/cave_wild_roach.gd").SETTINGS.look["5"], 124, 56],
		"WORM": [preload("res://scripts/lol2/cave_lurking_roach.gd").SETTINGS.look["6"], 124, 56]}
	for key in looks:
		var look: Dictionary = looks[key][0]
		if float(look.radius) < 0.9 * looks[key][1] * SCALE / 2.0 or float(look.height) < 0.9 * looks[key][2] * SCALE:
			return fail("%s hit capsule %s/%s smaller than its sprite" % [key, look.radius, look.height])
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in 1500:
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Dark Halls not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var pop = scene.creatures
	pop.set_physics_process(false); pop.set_process(false)
	var rat: CharacterBody3D = pop.bodies["55"]
	scene.player.global_position = rat.global_position + Vector3(80, 34, 0)
	scene.player.velocity = Vector3.ZERO
	for i in 30: await physics_frame
	for point in [Vector3(0, 18, 0), Vector3(0, 8, 12), Vector3(0, 8, -12)]:
		# Turn the player and pitch the camera (as mouse look does) toward the point.
		var d: Vector3 = rat.global_position + point - scene.camera.global_position
		scene.player.rotation.y = atan2(-d.x, -d.z)
		scene.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await physics_frame
		if pop.aimed() != "55": return fail("Aim at the drawn Rat %s missed (aimed '%s')" % [point, pop.aimed()])
	print("PASS small_creature_hit_size: Rat/ROACH/WORM capsules cover their sprites; aim at the drawn Rat's back and flanks hits")
	quit(0)
