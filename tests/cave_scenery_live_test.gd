extends SceneTree
## Actual Cave host: the scenery owner is set up by cave_walkthrough, its 65 billboards (58 rows + 7 chained torch
## flames) are on the indexed layer-2 path with a mask-pass copy, the 18 emitters play once the walkthrough is
## ready, and nothing is saved. Captures at fixed vantages (torch 623, the waterfall/mist pool by
## props 371-388, the meat 536-542, water pillars 474-476) go to user://tests/ for the visual comparison.
const VANTAGES := {"torch623": [[-114, 30, -7767], [-114, 60, -7687]], "waterfalls": [[-200, 25, -4600], [-120, 70, -4520]],
	"meat": [[540, -150, -12240], [540, -110, -12160]], "pillars": [[-2686, 20, -4944], [-2600, 60, -4880]]}
var cave

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> void:
	push_error(message); quit(1)

func run() -> void:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	if not cave.walkthrough_ready: return fail("Cave not ready")
	var scenery = cave.scenery
	if scenery == null or scenery.meshes.size() != 65 or scenery.voices.size() != 18: return fail("Scenery owner missing or incomplete")
	for id in scenery.meshes:
		var m: MeshInstance3D = scenery.meshes[id]
		if m.layers != 2 or not m.material_override is ShaderMaterial or not cave.occluder_by_source.has(m): return fail("Billboard %s not on the indexed layer-2 path" % id)
	cave.set_physics_process(false); cave.flying = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 10: await process_frame
	for id in scenery.voices:
		if not scenery.voices[id].playing: return fail("Emitter %s silent" % id)
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/tests")
	for key in VANTAGES:
		var target: Array = VANTAGES[key][0]; var eye: Array = VANTAGES[key][1]
		cave.player.global_position = Vector3(eye[0], eye[1], eye[2]) + cave.native_translation; cave.player.velocity = Vector3.ZERO
		cave.camera.look_at(Vector3(target[0], target[1], target[2]) + cave.native_translation, Vector3.UP)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://tests/cave_scenery_%s.png" % key)
	if JSON.stringify(cave._save_state()).contains("scenery"): return fail("Ambient scenery must not be saved")
	print("PASS cave_scenery_live: 65 indexed billboards mirrored into the mask pass, 18 emitters playing, not saved; captures in user://tests/cave_scenery_*.png")
	quit()
