extends SceneTree
## BK05. Stand on region 40, look at movable 77, and strike.
## A Lizard strike does not run group 7898. A Human strike does, and the floor rises.
const STAND := Vector3(-320.0, -8.0, -1760.0)
const AIM := Vector3(-344.0, -20.0, -1667.0)
var failures := 0

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL: " + message)
	return ok

func _initialize() -> void:
	run.call_deferred()

func click() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame

func run() -> void:
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 120:
		await process_frame
		if scene.ready_for_review and scene.progression != null:
			break
	if not check(scene.ready_for_review and scene.get_node_or_null("L19SewerForms") != null, "L19 ready"):
		quit(1)
		return
	var forms: Node = scene.get_node("L19SewerForms")
	# The host moves this body; the player node has no independent movement loop.
	# Keep the floor owner live while this fixture advances its motion explicitly.
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.player.position = STAND
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 2
	scene.camera.global_position = scene.player.global_position + Vector3(0, 8, 0)
	scene.camera.look_at(AIM, Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.starting_magic.interface_request = true
	await physics_frame
	await physics_frame
	var body: StaticBody3D = forms.get_node("BarHit")
	check(body.has_meta("hive_hit_receiver"), "the bars carry a hit receiver")
	await click()
	check(int(scene.progression.regions[40][1]) == -40, "region 40 stays at -40 after the Lizard click")
	scene.player_form = 0
	check(scene.progression.struck_skipped("movable:77", "L19_BC"), "the L19 bars stay off the struck binder")
	check(not scene.progression.struck_skipped("movable:77", "L9_DR"), "an L9 movable 77 keeps its kind 9 record")
	check(not scene.progression.struck_refs.has("movable:77"), "movable 77 is not collected as a struck door")
	check(scene.progression.aimed_struck() == "", "the struck binder does not take this bars hit")
	await click()
	var rose := false
	for _step in 500:
		scene.progression.advance_floors(1.0 / 60.0)
		await process_frame
		if int(scene.progression.regions[40][1]) == -20:
			rose = true
			break
	check(rose and absf(scene.player.position.y - 12.0) < 1.0, "region 40 rises to -20 and Luther rises (y %s)" % scene.player.position.y)
	check(int(scene.progression.regions[61][1]) == -20, "region 61 rises with the same strike")
	check(forms.choose_form() and bool(forms.state().lizard_at_wall), "G at the mouth asks for the Lizard")
	for _i in 400:
		scene.curse.advance(1.0 / 60.0)
		await process_frame
		if int(scene.player_form) == 2:
			break
	check(int(scene.player_form) == 2, "the mouth finishes as the Lizard")
	if failures == 0:
		print("PASS a left click on the bars raises the corridor and the gutter mouth changes to the Lizard")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
