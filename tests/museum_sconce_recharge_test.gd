extends SceneTree
## Actual Museum host, SUPPLIED item scope (no burnt crystal can reach the Museum in Act 1): a burnt Fire crystal in
## hand at an unlit sconce is refused; after the real Sk-key locks light the sconces, E at a lit sconce runs the source
## kind4 mode3 record (take the held "57b-Fire brnt", grant "57a-Fire crstl" property1): the crystal holds 1 charge and
## leaves the hand; a charged crystal is not rekindled; control134 (recharge record, no burn record) also rekindles;
## the rekindled crystal fires once and burns out again. Supplied camera vantages and crystal.
const State = preload("res://scripts/lol2/museum_key_locks_state.gd")
const CRYSTAL := "jungle:magic_shop:Fire_crystals_1"
var museum
var locks
var failed := false
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	if failed: return
	failed = true; push_error(message); quit(1)
func press() -> void:
	var event := InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	museum._unhandled_input(event)
func view(target: Vector3) -> bool:
	for distance in [45.0, 70.0, 30.0, 88.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			for lift in [0.0, -12.0, 12.0]:
				var eye: Vector3 = target + d * distance + Vector3(0, lift, 0)
				museum.player.position = eye - Vector3(0, museum.camera.position.y, 0)
				museum.camera.rotation = Vector3.ZERO; museum.player.rotation = Vector3.ZERO
				museum.camera.look_at(target)
				await physics_frame
				if museum.can_reach_item(target): return true
	return false
func supply_burnt() -> void:
	if not CRYSTAL in museum.carried_collected: museum.carried_collected.append(CRYSTAL)
	var fx: Dictionary = museum.item_effects.state()
	if not fx.has("fire_crystals"): fx.fire_crystals = {}
	fx.fire_crystals[CRYSTAL] = 0
	museum.hand_item = CRYSTAL
func run() -> void:
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum); current_scene = museum
	await process_frame; await process_frame
	museum.set_physics_process(false)
	museum.sword_transfer.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	locks = museum.key_locks
	supply_burnt()
	if not museum.item_effects.crystal_burnt(CRYSTAL): return fail("Supplied crystal not burnt")
	# Unlit sconce: no recharge offered.
	if not await view(locks.sconce_point(117)) or locks.interaction_hint() != "": return fail("Unlit sconce offers: " + locks.interaction_hint())
	press()
	if not museum.item_effects.crystal_burnt(CRYSTAL): return fail("Unlit sconce rekindled")
	# Light the sconces through the real locks (hand must be empty for the key).
	museum.hand_item = ""
	if not await view(locks.aim_point(87)): return fail("No vantage control87")
	press()
	if not await view(locks.aim_point(113)): return fail("No vantage control113")
	press()
	if not State.sconces_lit(locks.state): return fail("Sconces not lit")
	museum.hand_item = CRYSTAL
	if not await view(locks.sconce_point(117)): return fail("No vantage sconce117")
	if locks.interaction_hint() != "E — Rekindle the fire crystal": return fail("Lit hint: " + locks.interaction_hint())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/museum_sconce_recharge.png")
	var health: int = museum.starting_magic.health()
	press()
	if museum.item_effects.crystal_charges(CRYSTAL) != 1 or museum.hand_item != "" or not CRYSTAL in museum.carried_collected: return fail("Recharge: charges %d hand '%s'" % [museum.item_effects.crystal_charges(CRYSTAL), museum.hand_item])
	if museum.starting_magic.health() != health: return fail("Recharge burned the player")
	# A charged crystal in hand is not rekindled (and does not burn: the hand is busy).
	museum.hand_item = CRYSTAL
	if locks.interaction_hint() != "": return fail("Charged crystal offered: " + locks.interaction_hint())
	press()
	if museum.item_effects.crystal_charges(CRYSTAL) != 1 or museum.starting_magic.health() != health: return fail("Charged crystal changed")
	# The rekindled crystal fires once and burns out again.
	museum.hand_item = ""
	museum.camera.rotation = Vector3.ZERO
	# Item use runs from the open inventory (shared controller rule).
	if not museum.open_inventory(): return fail("Inventory did not open")
	await process_frame
	var fired: bool = museum.item_effects.use(CRYSTAL)
	if is_instance_valid(museum.inventory): museum.inventory.queue_free()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not fired or not museum.item_effects.crystal_burnt(CRYSTAL): return fail("Rekindled crystal did not fire once")
	# control134: recharge record present (no empty-hand burn record).
	if locks.source.sconces["134"].get("recharge") == null or locks.source.sconces["134"].get("empty_hand") != null: return fail("control134 records")
	museum.hand_item = CRYSTAL
	if not await view(locks.sconce_point(134)): return fail("No vantage control134")
	if locks.interaction_hint() != "E — Rekindle the fire crystal": return fail("control134 hint: " + locks.interaction_hint())
	press()
	if museum.item_effects.crystal_charges(CRYSTAL) != 1: return fail("control134 did not rekindle")
	if not "Fire crystal · 1 charges" in museum.item_effects.status(): return fail("Status: " + museum.item_effects.status())
	print("PASS museum_sconce_recharge (supplied crystal): unlit refused, lit sconce117 rekindles burnt 57b -> 57a property1 (hand cleared, no burn), charged crystal ignored, rekindled crystal fires once and burns out, control134 rekindles, status.")
	quit()
