extends SceneTree
## BK06. Stand on the walkway, aim at movables 74, 75, and 76, and shoot.
## A Human with a bow fires kind 6. Caller 15 raises region 103 on the third shot.
## Caller 16 restores it when local 0 is already 1. The 15/16 button split is an adapter.
const Forms = preload("res://scripts/lol2/l19_sewer_forms.gd")
const BLUE := "act2:L12_CM:blue_bow"
const DARK := "act2:L16_CA:item24"
const SWORD := "act2:L13_RC:dark_sword"
const WALK_Y := 22.0
const WALK_Z := -2088.0
var failures := 0

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL: " + message)
	return ok

func _initialize() -> void:
	run.call_deferred()

func click(button: int) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame

func stand(scene: Node, aim: Vector3) -> void:
	scene.player.position = Vector3(aim.x, WALK_Y, WALK_Z)
	scene.player.velocity = Vector3.ZERO
	scene.camera.global_position = scene.player.global_position + Vector3(0, 8, 0)
	scene.camera.look_at(aim, Vector3.UP)

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
	scene.player.set_physics_process(false)
	scene.player_form = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.starting_magic.interface_request = true
	for id in [74, 75, 76]:
		var body: Node = scene.progression.hinges[id].get_node("MoverCollision")
		check(body.has_meta("bow_hit_receiver"), "switch %d carries a hit receiver" % id)
	stand(scene, forms.AIM_75)
	await physics_frame
	await physics_frame
	scene.player.position = forms.AT_75
	await process_frame
	check(forms.state().switches.is_empty(), "standing at a slot does not mark it")
	stand(scene, forms.AIM_75)
	await click(MOUSE_BUTTON_LEFT)
	check(forms.state().switches.is_empty(), "empty hands do not shoot")
	check(not scene.progression.native.locals.has(0), "empty hands leave local 0 unknown")
	scene.carried_collected.append(SWORD)
	check(scene.set_equipped_item(SWORD), "the sword equips")
	await click(MOUSE_BUTTON_LEFT)
	check(forms.state().switches.is_empty(), "a sword does not shoot")
	scene.player_form = 2
	scene.carried_collected.append(BLUE)
	check(scene.set_equipped_item(BLUE), "the blue bow equips")
	await click(MOUSE_BUTTON_LEFT)
	check(forms.state().switches.is_empty(), "a Lizard does not shoot")
	scene.player_form = 1
	await click(MOUSE_BUTTON_LEFT)
	check(forms.state().switches.is_empty(), "a Beast does not shoot")
	scene.player_form = 0
	check(int(scene.progression.regions[103][1]) == -55, "region 103 starts at -55")
	var aims: Array = [forms.AIM_74, forms.AIM_75, forms.AIM_76]
	var ids: Array = [74, 75, 76]
	for n in 3:
		stand(scene, aims[n])
		await physics_frame
		await click(MOUSE_BUTTON_LEFT)
		if not check(forms.state().switches.size() == n + 1, "left click shot %d" % int(ids[n])):
			break
		if n < 2:
			check(int(scene.progression.regions[103][1]) == -55, "region 103 stays until the third click")
		check(forms.state().switches.size() == n + 1, "shot %d records the slot" % (n + 1))
		check(int(scene.progression.native.locals.get(0, -1)) == n + 1, "local 0 is %d" % (n + 1))
	var angle: int = int(scene.progression.native.attributes["movable:77"].angle_word)
	var hinge: Node3D = scene.progression.hinges[77]
	var before: Vector3 = hinge.global_position
	check(int(scene.progression.travel.get(77, -1)) == angle, "movable 77 travel is the angle byte")
	scene.progression.advance_movers(1.0)
	check(hinge.global_position.distance_to(before) > 1.0, "the door hinge poses")
	var flooded := false
	for _step in 500:
		scene.progression.advance_floors(1.0 / 60.0)
		if int(scene.progression.regions[103][1]) == -45:
			flooded = true
			break
	check(flooded, "region 103 rises to -45")
	scene.progression.native.locals.erase(0)
	forms._sync_counter()
	check(int(scene.progression.native.locals.get(0, -1)) == 3, "the saved counter restores local 0")
	stand(scene, forms.AIM_74)
	for _n in 3:
		await physics_frame
		await click(MOUSE_BUTTON_RIGHT)
		check(int(scene.progression.native.locals.get(0, -1)) == 2 - _n, "right click %d" % (_n + 1))
	check(int(scene.progression.travel.get(77, -1)) == 0, "the drain clears movable 77 travel")
	check(int(scene.progression.native.locals.get(0, -1)) == 0, "local 0 returns to 0")
	var drained := false
	for _step in 800:
		scene.progression.advance_floors(1.0 / 60.0)
		if int(scene.progression.regions[103][1]) == -55:
			drained = true
			break
	check(drained, "region 103 returns to -55")
	scene.equipped_item = DARK
	stand(scene, forms.AIM_76)
	await physics_frame
	await click(MOUSE_BUTTON_LEFT)
	check(int(scene.progression.native.locals.get(0, -1)) == 1, "the dark bow adds one")
	if failures == 0:
		print("PASS left and right clicks on switches 74, 75, and 76 raise the channel and the drain restores it")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
