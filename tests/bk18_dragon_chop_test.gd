extends SceneTree
## BK18. Stand in the dragon room, aim at prop 241, and left-click.
## Group 6384 runs from that click. A second click is refused by predicate 206.
const Host = preload("res://scripts/lol2/native_script_host.gd")
const ADMIT := {
	"word0": 2,
	"word2": 0,
	"dword_26": 0,
	"global_23331": 0,
	"context": "prop:241",
}
var failures := 0

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL: " + message)
	return ok

func _initialize() -> void:
	run.call_deferred()

func row_for(results: Array, group: int) -> Dictionary:
	for raw in results:
		var row: Dictionary = raw
		if int(row.get("group", -1)) == group:
			return row
	return {}

func enqueued(row: Dictionary) -> bool:
	for raw in row.get("effects", []):
		var effect: Dictionary = raw
		if str(effect.get("type", "")) != "enqueue":
			continue
		if str(effect.get("ref", "")) == "control:73" and int(effect.get("event_kind", -1)) == 6 and int(effect.get("caller_byte", -1)) == 0x14:
			return true
	return false

func click() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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

func host_fire() -> bool:
	var host = Host.new()
	if not check(str(host.load_area("res://scripts/lol2/native_scripts/L16_CA.json")).is_empty(), "L16 native load"):
		return false
	var results: Array = host.fire_event("prop:241", 9, ADMIT)
	var row: Dictionary = row_for(results, 6384)
	var adapters: Array = row.get("adapters", [])
	var ok: bool = str(row.get("status", "")) == "ran"
	ok = ok and adapters.has("opcode7_prop_frame")
	ok = ok and int(host.field("prop:241", "byte_0x25")) == 1
	ok = ok and int(host.field("prop:241", "byte_0x37")) == 8
	ok = ok and int(host.field("prop:241", "byte_0x31")) == 0
	ok = ok and int(host.field("prop:241", "byte_0x30")) == 3
	ok = ok and int(host.field("prop:241", "bit_0x36_0x01")) == 1
	ok = ok and int(host.field("prop:241", "bit_0x36_0x04")) == 1
	ok = ok and enqueued(row)
	check(ok, "group 6384 runs on the host (%s %s)" % [row.get("status", ""), row.get("reasons", [])])
	var again: Array = host.fire_event("prop:241", 9, ADMIT)
	var second: Dictionary = row_for(again, 6384)
	check(str(second.get("status", "")) == "rejected" and str(second.get("reasons", [])).contains("predicate 206"), "second fire rejects predicate 206 (%s)" % [second.get("reasons", [])])
	return failures == 0

func run() -> void:
	if not host_fire():
		quit(1)
		return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.ready_for_review and scene.progression != null and scene.progression.native != null and scene.get_node_or_null("L16DragonRoom") != null:
			break
	var room: Node = scene.get_node_or_null("L16DragonRoom")
	if not check(room != null and scene.progression != null and scene.progression.native != null, "L16 dragon room ready"):
		scene.queue_free()
		await process_frame
		quit(1)
		return
	scene.player.set_physics_process(false)
	scene.set_physics_process(false)
	scene.starting_magic.interface_request = true
	scene.progression.change_scene_enabled = false
	print("TELEPORT")
	scene.player.position = Vector3(1645, 82, 4435)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(room.DRAGON_AT, Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not check(room.aimed(room.DRAGON_AT, 180.0), "aimed at prop 241"):
		scene.queue_free()
		await process_frame
		quit(1)
		return
	await click()
	var native = scene.progression.native
	var clicked: Dictionary = row_for(room.fire_results, 6384)
	var chop_ok: bool = bool(room.state().chopped) and str(clicked.get("status", "")) == "ran"
	chop_ok = chop_ok and (clicked.get("adapters", []) as Array).has("opcode7_prop_frame")
	chop_ok = chop_ok and int(native.field("prop:241", "byte_0x25")) == 1
	chop_ok = chop_ok and int(native.field("prop:241", "byte_0x37")) == 8
	chop_ok = chop_ok and int(native.field("prop:241", "byte_0x31")) == 0
	chop_ok = chop_ok and int(native.field("prop:241", "bit_0x36_0x01")) == 1
	chop_ok = chop_ok and int(native.field("prop:241", "bit_0x36_0x04")) == 1
	chop_ok = chop_ok and enqueued(clicked)
	check(chop_ok, "left click runs group 6384 (%s %s)" % [clicked.get("status", ""), clicked.get("reasons", [])])
	await click()
	check(bool(room.state().chopped) and room.fire_results.size() == 1, "a second click while chopped does not fire again")
	var cleared: Dictionary = room.state().duplicate(true)
	cleared.chopped = false
	scene.quest_state[room.KEY] = cleared
	await click()
	var refused: Dictionary = row_for(room.fire_results, 6384)
	var stay: bool = not bool(room.state().chopped)
	stay = stay and str(refused.get("status", "")) == "rejected"
	stay = stay and str(refused.get("reasons", [])).contains("predicate 206")
	stay = stay and int(native.field("prop:241", "byte_0x25")) == 1
	stay = stay and int(native.field("prop:241", "byte_0x37")) == 8
	check(stay, "the next click sees +0x25 = 1 and does not chop (%s)" % [refused.get("reasons", [])])
	if failures == 0:
		print("PASS left click on prop 241 runs group 6384 and the next click does not")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
