extends SceneTree
## Owner F10 r12c report #15 (2026-10-24 17:55 "cant get the wax"): with a carried item in the hand, E at a beehive
## (and the Aloe plant) was silently refused, because their source records are empty-hand uses only (kind4 mode0).
## E now puts the held item back into the pack and harvests; the item stays carried. A hand item that is not carried
## is still refused, and the hand is restored when nothing is taken.
const BeeWax = preload("res://scripts/lol2/jungle_beehive_wax.gd")
const HELD := "monastery:item94:Iron_Flute"
var jungle
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_held_item_harvest: ", message); quit(1)

func view(owner, id: String) -> bool:
	var target: Vector3 = owner.aim_point(id)
	for distance in [70.0, 50.0, 90.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			jungle.player.global_position = target + d * distance - Vector3(0, jungle.camera.position.y, 0) + Vector3(0, 10, 0)
			jungle.player.rotation = Vector3.ZERO; jungle.camera.rotation = Vector3.ZERO
			jungle.camera.look_at(target); await physics_frame
			if owner.target() == id: return true
	return false

func run() -> void:
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 1500:
		await process_frame
		if jungle.get("ready_for_review"): break
	if not jungle.get("ready_for_review"): return fail("Jungle not ready")
	for room in [jungle.monastery, jungle.magic_shop, jungle.weapon_shop, jungle.departure]:
		if is_instance_valid(room): room.set_process(false)
	jungle.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var hives = jungle.beehives
	var harvest = jungle.harvest
	if not is_instance_valid(hives) or not is_instance_valid(harvest): return fail("Beehive/harvest owners missing")
	if not await view(hives, "251"): return fail("No vantage for hive251")
	# A hand item that is not carried stays refused (no stowing of something the pack does not hold).
	jungle.hand_item = HELD
	if hives.use() or jungle.carried_collected.count(BeeWax.POOL[0]) != 0: return fail("Uncarried hand item was stowed")
	jungle.carried_collected.append(HELD)
	jungle.hand_item = HELD
	if not "puts away" in hives.interaction_hint(): return fail("Hive hint: " + hives.interaction_hint())
	if not hives.use(): return fail("Held item refused at the hive")
	if jungle.carried_collected.count(BeeWax.POOL[0]) != 1 or jungle.hand_item != BeeWax.POOL[0] or not HELD in jungle.carried_collected or int(hives.state.hives["251"].fullness) != 1:
		return fail("Wax not taken with the held item put away: hand=%s" % jungle.hand_item)
	# Empty hive with a held item: refused with feedback, hand kept.
	hives.state.hives["251"].fullness = 2
	jungle.hand_item = HELD
	var before: Array = jungle.carried_collected.duplicate()
	hives.use()
	if jungle.hand_item != HELD or jungle.carried_collected != before: return fail("Empty hive changed hand/pack")
	if not await view(harvest, "254"): return fail("No vantage for plant254")
	jungle.hand_item = HELD
	if not "puts away" in harvest.interaction_hint(): return fail("Plant hint: " + harvest.interaction_hint())
	var aloe_before: int = jungle.carried_collected.size()
	if not harvest.use(): return fail("Held item refused at the Aloe plant")
	if jungle.carried_collected.size() != aloe_before + 1 or jungle.hand_item == HELD or jungle.hand_item == "" or not HELD in jungle.carried_collected:
		return fail("Aloe not taken with the held item put away: hand=%s" % jungle.hand_item)
	print("PASS jungle_held_item_harvest: hive251 and plant254 take with a carried item in hand (put away), uncarried hand refused, empty hive keeps the hand")
	quit(0)
