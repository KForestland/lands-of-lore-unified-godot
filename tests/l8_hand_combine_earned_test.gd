extends SceneTree
## BJ13 step 3: the serum and a Silverleaf are mixed by hand in the pack, by real mouse drag in either order, from the earned save after the shaman's trade.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const INPUT := "res://tmp/l8_shaman_serum_earned_save.json"
const SERUM := "act2:L8_SJ:shaman_amaranth"
const VAPORS := "act2:L8_SJ:larkhon_vapors"
var failures := 0
var scene: Node
func check(c: bool, m: String) -> bool:
	if not c:
		failures += 1; print("FAIL L8 hand combine: ", m)
	return c
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func boot() -> void:
	var source := Save.read_save(INPUT, "lol2-restoration-darker-jungle")
	check(source.error.is_empty(), "earned save: " + str(source.error))
	set_meta("lol2_darker_resume", source.state); Engine.set_meta("lol2_enhanced", false)
	scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	check(scene.ready_for_review, "scene ready")
func press_key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
		root.push_input(e); await process_frame
func open() -> Node:
	await press_key(KEY_I); await frames(3)
	check(is_instance_valid(scene.inventory), "the real I key opens the pack")
	return scene.inventory
func row(inv: Node, kind: int, exclude: String = "") -> int:
	for i in inv.item_list.item_count:
		var id := str(inv.item_list.get_item_metadata(i))
		if Items.definition(id) == kind and id != exclude: return i
	return -1
func point(inv: Node, index: int) -> Vector2:
	var rect: Rect2 = inv.item_list.get_item_rect(index)
	return inv.item_list.get_global_transform_with_canvas() * (rect.position + rect.size * 0.5)
## Real X11 pointer events (xdotool on this run's private Xvfb): Godot only performs a drop for events that come through the window.
func xdo(args: Array) -> void:
	OS.execute("xdotool", args)
	await frames(4)
func at_screen(p: Vector2) -> Array:
	var w := Vector2(root.position) + p
	return [str(int(w.x)), str(int(w.y))]
func drag(from: Vector2, to: Vector2) -> void:
	await xdo(["mousemove"] + at_screen(from))
	await xdo(["mousedown", "1"])
	for i in range(1, 13):
		await xdo(["mousemove"] + at_screen(from.lerp(to, float(i) / 12.0)))
	await xdo(["mouseup", "1"])
	await frames(4)
func leaves() -> int:
	return scene.carried_collected.filter(func(id): return Items.definition(id) == 117).size()
func combine(serum_first: bool) -> void:
	await boot()
	var inv: Node = await open()
	var serum_row := row(inv, 119); var leaf_row := row(inv, 117)
	if not check(serum_row >= 0 and leaf_row >= 0, "the pack holds the serum and a leaf"): return
	check(inv.item_list.get_item_text(serum_row) == "Amaranth Serum", "the serum reads by name (%s)" % inv.item_list.get_item_text(serum_row))
	inv.select_item(serum_row); await frames(1)
	check(inv.use_button.text != "Play flute", "no flute button on the serum (%s)" % inv.use_button.text)
	check(inv.detail_text.text.contains("Silverleaf"), "the serum says what it mixes with (%s)" % inv.detail_text.text)
	var count := leaves()
	# A leaf dropped on something else does nothing.
	var other := -1
	for i in inv.item_list.item_count:
		if inv._larkhon_recipe(str(inv.item_list.get_item_metadata(i))) < 0: other = i; break
	await drag(point(inv, leaf_row), point(inv, other))
	check(is_instance_valid(scene.inventory) and SERUM in scene.carried_collected and leaves() == count, "a leaf dropped on another item mixes nothing")
	var from := point(inv, serum_row if serum_first else leaf_row); var to := point(inv, leaf_row if serum_first else serum_row)
	await drag(from, to)
	check(VAPORS in scene.carried_collected, "the drag made the Larkhon Vapors (serum first: %s)" % serum_first)
	check(SERUM not in scene.carried_collected and leaves() == count - 1, "the serum and one leaf are used (%d of %d leaves)" % [leaves(), count])
	var path := "res://tmp/l8_hand_combine_save.json"
	if check(scene._quicksave_unrecorded(path).is_empty(), "save after the mix"):
		check(scene._quickload_unrecorded(path).is_empty() and VAPORS in scene.carried_collected, "the vapors survive a reload")
	inv = await open()
	if is_instance_valid(inv):
		var vapors := row(inv, 128)
		check(vapors >= 0 and inv.item_list.get_item_text(vapors) == "Larkhon Vapors", "the vapors read by name")
	scene.queue_free(); current_scene = null; await frames(3)
func run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.time_scale = 1
	await combine(true)
	await combine(false)
	if failures == 0: print("PASS L8 hand combine: real mouse drag, serum on leaf and leaf on serum, names and text, reload")
	quit(0 if failures == 0 else 1)
