extends SceneTree
## OF11. E lifts a cave crate, E sets it on another, the stack meets the mace lip, and a save keeps it.
## K90. A lip drop and a bridge-room drop use that floor. Lifting the bottom rests the crate above.
## E does nothing with a free mouse, an open overlay, or the captain lock.
const Stack := preload("res://scripts/lol2/cave_crate_stack.gd")
const SAVE := "user://of11_cave_crate_save.json"
var failures: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL crate lift: ", label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func spot(stack: Node, id: int) -> Vector3:
	var centers: Dictionary = stack.get("centers")
	return centers[id] as Vector3

func press_e(cave: Node) -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_E
	down.pressed = true
	down.echo = false
	cave._unhandled_input(down)

func place_drop(cave: Node, player: CharacterBody3D, stack: Node, id: int, at: Vector3) -> void:
	var sizes: Dictionary = stack.get("sizes")
	var size: Vector3 = sizes[id] as Vector3
	var ahead: float = 15.0 + maxf(size.x, size.z) * 0.5 + Stack.CARRY_GAP
	player.global_position = Vector3(at.x, at.y + 32.0, at.z + ahead)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(at.x, player.global_position.y, at.z), Vector3.UP)
	var cam: Variant = cave.get("camera")
	if cam is Camera3D:
		(cam as Camera3D).rotation = Vector3.ZERO

func stand(cave: Node, player: CharacterBody3D, stack: Node, id: int, floor_y: float) -> void:
	var c: Vector3 = spot(stack, id)
	var sizes: Dictionary = stack.get("sizes")
	var size: Vector3 = sizes[id] as Vector3
	var shove: float = 15.0 + 0.5 * Vector2(size.x, size.z).length() + 1.0
	var best := Vector3(1, 0, 0)
	var best_clear := -1.0
	var centers: Dictionary = stack.get("centers")
	for step in 12:
		var angle := float(step) / 12.0 * TAU
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var at := c + dir * (shove + 12.0)
		var clear := 1.0e9
		for other in centers:
			if int(other) == id: continue
			var o: Vector3 = centers[other]
			clear = minf(clear, Vector2(at.x - o.x, at.z - o.z).length())
		if clear > best_clear:
			best_clear = clear
			best = dir
	player.global_position = c + best * (shove + 12.0)
	player.global_position.y = floor_y + 32.0
	player.velocity = Vector3.ZERO
	var look := Vector3(c.x, player.global_position.y, c.z)
	player.look_at(look, Vector3.UP)
	var cam: Variant = cave.get("camera")
	if cam is Camera3D:
		(cam as Camera3D).rotation = Vector3.ZERO

func run() -> void:
	var cave: Node = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for _i in 1500:
		await process_frame
		if bool(cave.get("walkthrough_ready")):
			break
	if not check(bool(cave.get("walkthrough_ready")), "cave ready"):
		quit(1)
		return
	var stack: Node = cave.get_node_or_null("CaveCrateStack")
	if not check(stack != null, "crate stack hosted"):
		quit(1)
		return
	var magic: Node = cave.get("starting_magic")
	if magic != null:
		magic.set("interface_request", true)
	cave.set_physics_process(false)
	var player: CharacterBody3D = cave.get("player") as CharacterBody3D
	player.set_physics_process(false)
	var sizes: Dictionary = stack.get("sizes")
	var base: Vector3 = spot(stack, 121)
	var base_size: Vector3 = sizes[121] as Vector3
	var floor_y: float = base.y - base_size.y * 0.5
	var lip: float = floor_y + (Stack.LIP_Y - Stack.FLOOR_Y)
	var shift: Vector3 = base - Vector3(564.0, -205.0, -12367.0)
	var fresh: Dictionary = stack.checkpoint()
	stand(cave, player, stack, 94, floor_y)
	await physics_frame
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		press_e(cave)
		if not check(int(stack.get("carried")) == -1, "a free mouse lifted a crate"):
			quit(1)
			return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var overlay := CanvasLayer.new()
	cave.inventory = overlay
	cave.add_child(overlay)
	press_e(cave)
	cave.inventory = null
	overlay.free()
	if not check(int(stack.get("carried")) == -1, "an open overlay lifted a crate"):
		quit(1)
		return
	var captain_v: Variant = cave.get("captain")
	if not check(captain_v is Node, "captain present"):
		quit(1)
		return
	var captain := captain_v as Node
	var cap_state: Dictionary = captain.get("state")
	var movie_was: float = float(cap_state.movie)
	var done_was: bool = bool(cap_state.movie_done)
	cap_state.movie = 0.0
	cap_state.movie_done = false
	press_e(cave)
	cap_state.movie = movie_was
	cap_state.movie_done = done_was
	if not check(int(stack.get("carried")) == -1, "the captain lock lifted a crate"):
		quit(1)
		return
	var parked: Vector3 = spot(stack, 95)
	var centers: Dictionary = stack.get("centers")
	var raised := parked.y + 80.0
	centers[94] = Vector3(parked.x, raised, parked.z)
	stand(cave, player, stack, 95, floor_y)
	await physics_frame
	press_e(cave)
	await physics_frame
	if not check(int(stack.get("carried")) == 95, "E lifted %s instead of the bottom crate" % str(stack.get("carried"))):
		quit(1)
		return
	var fallen: Vector3 = spot(stack, 94)
	var fallen_size: Vector3 = sizes[94] as Vector3
	if not check(absf(fallen.y - fallen_size.y * 0.5 - floor_y) < 1.0, "crate 94 stayed up at %.1f after the lift, was %.1f" % [fallen.y, raised]):
		quit(1)
		return
	var carried_at: Vector3 = spot(stack, 95)
	if not check(Vector2(fallen.x - carried_at.x, fallen.z - carried_at.z).length() > 8.0, "crate 94 dropped onto the carried crate"):
		quit(1)
		return
	stack.restore(fresh)
	# Five medium crates. 5 * 20 clears the 85-unit lip. The two small crates stay put.
	var order: Array[int] = [96, 97, 112, 122]
	for id in order:
		var home: Vector3 = spot(stack, id)
		stand(cave, player, stack, id, floor_y)
		await physics_frame
		press_e(cave)
		await physics_frame
		if not check(int(stack.get("carried")) == id, "E did not lift crate %d" % id):
			quit(1)
			return
		if not check(spot(stack, id).y > home.y + 4.0, "crate %d stayed on the floor" % id):
			quit(1)
			return
		stand(cave, player, stack, 121, floor_y)
		await physics_frame
		press_e(cave)
		await physics_frame
		if not check(int(stack.get("carried")) == -1, "E did not set crate %d down" % id):
			quit(1)
			return
		var landed: Vector3 = spot(stack, id)
		if not check(Vector2(landed.x - base.x, landed.z - base.z).length() < 1.0, "crate %d missed crate 121" % id):
			quit(1)
			return
	var top: float = floor_y
	for id in [121, 96, 97, 112, 122]:
		var c: Vector3 = spot(stack, id)
		var size: Vector3 = sizes[id] as Vector3
		top = maxf(top, c.y + size.y * 0.5)
	if not check(top + 0.1 >= lip, "the stack top %.1f is short of the lip %.1f" % [top, lip]):
		quit(1)
		return
	stand(cave, player, stack, 94, floor_y)
	await physics_frame
	press_e(cave)
	if not check(int(stack.get("carried")) == 94, "E did not lift crate 94 for the lip"):
		quit(1)
		return
	var lip_at := Vector3(417.0 + shift.x, lip, -12444.0 + shift.z)
	place_drop(cave, player, stack, 94, lip_at)
	await physics_frame
	press_e(cave)
	await physics_frame
	var lip_landed: Vector3 = spot(stack, 94)
	var lip_size: Vector3 = sizes[94] as Vector3
	var lip_bottom: float = lip_landed.y - lip_size.y * 0.5
	if not check(absf(lip_bottom - lip) < 1.5, "lip drop bottom %.1f, lip %.1f, room %.1f" % [lip_bottom, lip, floor_y]):
		quit(1)
		return
	stand(cave, player, stack, 95, floor_y)
	await physics_frame
	press_e(cave)
	if not check(int(stack.get("carried")) == 95, "E did not lift crate 95 for the bridge"):
		quit(1)
		return
	var bridge_y: float = floor_y + (float(Stack.NOT_THIS_STACK.h) - Stack.FLOOR_Y)
	var bridge_at := Vector3(float(Stack.NOT_THIS_STACK.x) + shift.x, bridge_y, -float(Stack.NOT_THIS_STACK.y) + shift.z)
	place_drop(cave, player, stack, 95, bridge_at)
	await physics_frame
	press_e(cave)
	await physics_frame
	var bridge_landed: Vector3 = spot(stack, 95)
	var bridge_size: Vector3 = sizes[95] as Vector3
	var bridge_bottom: float = bridge_landed.y - bridge_size.y * 0.5
	if not check(absf(bridge_bottom - bridge_y) < 1.5, "bridge drop bottom %.1f, bridge %.1f, room %.1f" % [bridge_bottom, bridge_y, floor_y]):
		quit(1)
		return
	var crown: Vector3 = spot(stack, 122)
	var crown_size: Vector3 = sizes[122] as Vector3
	player.global_position = Vector3(crown.x, crown.y + crown_size.y * 0.5 + 34.0, crown.z)
	player.velocity = Vector3(0, -40, 0)
	var climbed := false
	for _step in 20:
		await physics_frame
		player.velocity = Vector3(0, -40, 0)
		player.move_and_slide()
		var feet: float = player.global_position.y - 32.0
		if player.is_on_floor() and feet + 1.0 >= lip:
			climbed = true
			break
	if not check(climbed, "the player did not stand on the lip, feet %.1f lip %.1f floor %s" % [player.global_position.y - 32.0, lip, player.is_on_floor()]):
		quit(1)
		return
	var before: Vector3 = spot(stack, 122)
	var saved: String = str(cave.call("quicksave", SAVE))
	if not check(saved.is_empty(), "save failed: " + saved):
		quit(1)
		return
	player.global_position = Vector3(floor_y, floor_y, floor_y)
	var loaded: String = str(cave.call("quickload", SAVE))
	if not check(loaded.is_empty(), "load failed: " + loaded):
		quit(1)
		return
	await physics_frame
	var after: Vector3 = spot(stack, 122)
	if not check(after.distance_to(before) < 0.5, "reload moved crate 122 from %s to %s" % [before, after]):
		quit(1)
		return
	var feet_now: float = player.global_position.y - 32.0
	if not check(feet_now + 1.0 >= lip, "reload dropped the player to %.1f" % feet_now):
		quit(1)
		return
	print("PASS crate lift: E stacked five crates to the lip, and the save kept the stand")
	cave.queue_free()
	await process_frame
	quit(0)
