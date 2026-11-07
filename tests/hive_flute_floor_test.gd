extends SceneTree
## HIVE-FLUTE-FLOOR (owner Act 1 gap; Prima pp.78/81, Brady pp.160/170): in the real Hive scene the iron flute offered at
## the slot (control 122) through the mechanism transaction API commits once, the four Pit Covers (movables 68-71) end
## over every oil floor (regions 479-489) with walkable collision at the green-tile height, the slot shows the inserted
## flute, and save/reload restores it without replaying. A wrong item, fire, an out-of-reach offer and the lizard are
## refused with nothing changed; the flute is never duplicated (retrieve once, forged carried+slotted handoff rejected).
const Floor = preload("res://scripts/lol2/hive_flute_floor.gd")
const M = preload("res://scripts/lol2/mechanism_transaction.gd")
const FLUTE := "monastery:item94:Iron_Flute"
const WRONG := "hive:item0:Wax"
const SAVE := "user://tests/hive_flute_floor.json"
var hive
var owner
var failed := false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error("FAIL: " + message)
		quit(1)
	return ok

## Oil floor centres from the scene's own geometry pack.
func oil_centres() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(hive.geometry_file))
	var out := {}
	for face in data.faces:
		if face.kind == "floor" and int(face.region) in Floor.OIL_REGIONS:
			var c := Vector3.ZERO
			for p in face.points: c += Vector3(p[0], p[1], p[2])
			out[int(face.region)] = c / face.points.size()
	return out

## First collider straight down from 40 units above the oil floor at (x, z), player collision mask.
func down_hit(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at - Vector3(0, 10, 0), hive.player.collision_mask, [hive.player.get_rid()])
	return hive.get_world_3d().direct_space_state.intersect_ray(query)

## The body probe stands on the channel's centre line (x+z = -8183, between the pocket edge and the far wall) at the
## region's position along the channel: the thin oil strips 479-481 by the far wall are narrower than the body.
func stands_on_cover(at: Vector3) -> bool:
	var along := clampf(at.x - at.z, 3796.0 + 20.0, 4563.0 - 20.0)
	var across := -8183.0
	hive.player.global_position = Vector3((across + along) / 2.0, Floor.TOP + Floor.FOOT_OFFSET + 1.0, (across - along) / 2.0)
	await physics_frame
	var motion := KinematicCollision3D.new()
	if not hive.player.test_move(hive.player.global_transform, Vector3(0, -12, 0), motion): return false
	if absf(motion.get_position().y - Floor.TOP) >= 1.0 or not str(motion.get_collider().name).begins_with("PitCoverBody"): printerr("stand at %s: hit %s on %s (travel %s)" % [at, motion.get_position(), motion.get_collider().name, motion.get_travel()])
	return absf(motion.get_position().y - Floor.TOP) < 1.0 and str(motion.get_collider().name).begins_with("PitCoverBody")

func vantage() -> bool:
	# Corridor region 477 (floor -1659) in front of the slot niche.
	for p in [Vector2(-1790, -6430), Vector2(-1780, -6420), Vector2(-1800, -6440), Vector2(-1770, -6410), Vector2(-1810, -6445), Vector2(-1760, -6400)]:
		hive.player.global_position = Vector3(p.x, -1659.0 + 32.0, p.y)
		hive.player.velocity = Vector3.ZERO; hive.player.rotation = Vector3.ZERO; hive.camera.rotation = Vector3.ZERO
		await physics_frame
		hive.camera.look_at(Floor.SLOT_POINT)
		await physics_frame
		if owner.in_reach(): return true
	return false

func slot_mode() -> int: return int(hive.static_assemblies.modes.get(Floor.SLOT_CONTROL, 0))

func unchanged(before_state: Dictionary, before_items: Array, label: String) -> bool:
	return check(owner.checkpoint() == before_state and hive.carried_inventory.collected == before_items, "%s changed the slot or the inventory" % label)

func run() -> void:
	hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 6: await process_frame
	hive.set_development_mode(false)
	hive.set_physics_process(false)
	hive.get_node("Warriors").set_process(false)
	hive.elevator.set_physics_process(false)
	owner = hive.flute_floor
	if not check(is_instance_valid(owner) and owner.checkpoint() == Floor.initial(), "flute floor owner missing or not initial"): return
	if not check(Floor.FLUTE == FLUTE and is_instance_valid(hive.static_assemblies) and hive.static_assemblies.stateful_meshes.has(Floor.SLOT_CONTROL) and slot_mode() == 0, "slot control 122 hosted, empty mode"): return
	var oil := oil_centres()
	if not check(oil.size() == Floor.OIL_REGIONS.size(), "oil floors found: %s" % [oil.keys()]): return
	# Before: the oil keeps its present behaviour (plain floor at -1674).
	for region in oil:
		var hit := down_hit(oil[region])
		if not check(not hit.is_empty() and absf(hit.position.y - (-1674.0)) < 0.5, "before the flute, oil %d is the -1674 floor (%s)" % [region, hit]): return
	if not check(await vantage(), "no vantage for the flute slot"): return
	var items: Array = hive.carried_inventory.collected
	items.erase(FLUTE); items.erase(WRONG)
	items.append(FLUTE); items.append(WRONG)
	var before_state: Dictionary = owner.checkpoint()
	var before_items: Array = items.duplicate()
	# Refusals change nothing: wrong item (inventory Use path), fire (Spark receiver), lizard form, out of reach.
	if not check(not hive.use_inventory_item(WRONG), "a wrong item was accepted"): return
	if not unchanged(before_state, before_items, "wrong item"): return
	if not check(owner.slot_body.get_meta("spark_receiver").receive_spark(), "fire not answered"): return
	if not unchanged(before_state, before_items, "fire"): return
	hive.player_form = 2
	if not check(not owner.offer_item(FLUTE).ok, "the lizard put the flute in"): return
	hive.player_form = 0
	if not unchanged(before_state, before_items, "lizard"): return
	var at: Vector3 = hive.player.global_position
	hive.player.global_position = at + Vector3(400, 0, 0)
	await physics_frame
	if not check(not owner.in_reach() and not owner.offer_item(FLUTE).ok, "out of reach accepted"): return
	if not unchanged(before_state, before_items, "out of reach"): return
	if not check(await vantage(), "vantage lost"): return
	# Correct offer: inventory Use of the flute at the slot commits once.
	if not check(hive.use_inventory_item(FLUTE), "the flute was refused at the slot"): return
	var slot: Dictionary = owner.checkpoint().slot
	if not check(slot.occupied == FLUTE and slot.committed and slot.receipts == [Floor.EVENT] and not FLUTE in items and items.count(WRONG) == 1, "commit: %s / %s" % [slot, items]): return
	if not check(slot_mode() == 1, "the slot does not show the flute"): return
	for id in Floor.COVERS:
		if not check(owner.bodies[id].position == Floor.SLIDE, "cover %d body not slid" % id): return
	# Walkable: over every oil floor the player body comes to rest on a Pit Cover at the green-tile height (the plates'
	# own 4-unit seams, from the source placements, are bridged by the body).
	await physics_frame
	for region in oil:
		var covered := false
		for shift in [0.0, 4.0, -4.0]:  # a centre on one of the plates' source seams is checked beside it
			var hit := down_hit(oil[region] + Vector3(shift, 0, -shift))
			covered = covered or (not hit.is_empty() and absf(hit.position.y - Floor.TOP) < 0.5 and str(hit.collider.name).begins_with("PitCoverBody"))
		if not check(covered, "after the flute, oil %d is not under a Pit Cover" % region): return
		if not check(await stands_on_cover(oil[region]), "after the flute, the player sinks into oil %d" % region): return
	if not check(not M.commit(M.empty_snapshot(), Floor.RECIPE, "again").ok and not owner.offer_item(FLUTE).ok, "a second commit/offer was accepted"): return
	# Save/reload restores from "committed" without replaying.
	if not check(await vantage(), "vantage lost after commit"): return
	var error: String = hive.quicksave(SAVE)
	if not check(error.is_empty(), "save: " + error): return
	var saved: Dictionary = owner.checkpoint()
	owner.restore(null)
	if not check(slot_mode() == 0 and owner.bodies[68].position == Vector3.ZERO, "reset for reload"): return
	error = hive.quickload(SAVE)
	hive.set_physics_process(false)
	items = hive.carried_inventory.collected
	if not check(error.is_empty() and owner.checkpoint() == saved and owner.slide_progress == 1.0 and slot_mode() == 1 and owner.bodies[70].position == Floor.SLIDE and owner.plates[70].position == Floor.SLIDE and not FLUTE in items, "reload: %s %s" % [error, owner.checkpoint()]): return
	if not check(await stands_on_cover(oil[489]) and await stands_on_cover(oil[485]), "reloaded covers not walkable"): return
	# No duplicate: the flute comes back once; the floor stays; reload keeps it.
	if not check(owner.retrieve().ok and items.count(FLUTE) == 1 and owner.committed() and not owner.occupied() and slot_mode() == 0, "retrieve"): return
	if not check(not owner.retrieve().ok and items.count(FLUTE) == 1, "second retrieve"): return
	error = hive.quicksave(SAVE)
	error += hive.quickload(SAVE)
	hive.set_physics_process(false)
	items = hive.carried_inventory.collected
	if not check(error.is_empty() and items.count(FLUTE) == 1 and owner.committed() and owner.bodies[69].position == Floor.SLIDE, "reload after retrieve: " + error): return
	# Re-inserting does not commit again.
	if not check(await vantage() and owner.offer_item(FLUTE).ok and owner.checkpoint().slot.receipts == [Floor.EVENT] and items.count(FLUTE) == 0, "re-insert"): return
	# A forged handoff that carries the flute while it is in the slot is rejected; malformed states are rejected.
	var forged: Dictionary = hive.area_handoff()
	forged.inventory.collected.append(FLUTE)
	if not check(not hive.apply_area_handoff(JSON.parse_string(JSON.stringify(forged))).is_empty(), "carried + slotted flute accepted"): return
	if not check(not Floor.validate({"version": 1, "slot": {"occupied": FLUTE, "committed": false, "receipts": []}}).is_empty() and not Floor.validate({"version": 1, "slot": {"occupied": WRONG, "committed": true, "receipts": [Floor.EVENT]}}).is_empty() and Floor.validate(JSON.parse_string(JSON.stringify(owner.checkpoint()))).is_empty(), "state validation"): return
	if not check(not preload("res://scripts/lol2/act_one_quest_state.gd").validate({"hive_flute_floor": {"version": 2}}).is_empty(), "quest validation ignores the flute floor"): return
	print("PASS hive_flute_floor: flute commits once through the transaction API, covers 68-71 over oil 479-489 walkable at -1654, slot mode 1, save/reload without replay, wrong item/fire/lizard/out-of-reach refused unchanged, one flute (retrieve once, forged handoff rejected)")
	quit(0)
