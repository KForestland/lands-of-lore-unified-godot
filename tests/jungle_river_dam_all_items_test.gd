extends SceneTree
## Huline Jungle river rock / dam (tools/prepare_jungle_river_dam.py, jungle_river_dam.gd), in the production Jungle:
## loading leaves the quests untouched; ordinary left clicks with a weapon break the rock after its durability (every
## hit before that only sounds); the break grants 2 x 500 fighting experience once, turns the rock to its stump,
## removes the foam and drains the river (floors sink at speed3, settle as mud, walls follow); the prop2706 timer is
## 1140 ticks however the clock is subdivided and asks the curse for the lizard once (120..180 s); a human cannot pass
## the 20-unit burrow mouth, the lizard walks in and takes the burrow items with E; saves keep the drain mid-way and
## after; invalid states are refused.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
const KEY := "jungle_river_dam"
var scene
var dam
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL jungle_river_dam: ", message); quit(1); return false

func centroid(row: Dictionary) -> Vector2:
	var c := Vector2.ZERO
	for p in row.polygon: c += Vector2(p[0], p[1])
	return c / row.polygon.size()
func inside(row: Dictionary, p: Vector3) -> bool:
	var polygon := PackedVector2Array()
	for q in row.polygon: polygon.append(Vector2(q[0], q[1]))
	return Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polygon)
## Midpoint of the edge two route regions share (their common vertices).
func shared(a: Dictionary, b: Dictionary) -> Vector2:
	var common: Array = []
	for p in a.polygon:
		for q in b.polygon:
			if Vector2(p[0], p[1]).distance_to(Vector2(q[0], q[1])) < 0.01: common.append(Vector2(p[0], p[1]))
	return (common[0] + common[1]) / 2.0 if common.size() >= 2 else centroid(b)

func place(xz: Vector2, floor_y: float) -> void:
	scene.player.global_position = Vector3(xz.x, floor_y + Body.FOOT_OFFSET + 1.0, xz.y)
	scene.player.velocity = Vector3.ZERO
## Ordinary grounded movement (the same move_grounded the keyboard drives) toward a point; true when reached.
func walk(xz: Vector2, frames: int = 600) -> bool:
	for i in frames:
		var d := xz - Vector2(scene.player.global_position.x, scene.player.global_position.z)
		if d.length() < 4.0:
			return true
		scene.move_grounded(Vector3(d.x, 0, d.y).normalized(), 1.0 / 60.0)
		await physics_frame
	return false

func click() -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	scene.get_viewport().push_input(event)
func press_e() -> void:
	var event := InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	scene.get_viewport().push_input(event)

func broken_template(timer: float) -> Dictionary:
	return {"version":1,"durability":-6,"broken":true,"elapsed":0.0,"timer_left":timer,"fired":false}

func run() -> void:
	change_scene_to_file("res://scenes/lol2/jungle_walkthrough.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Jungle not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false)
	dam = scene.river_dam
	if dam == null: return fail("River dam host missing")
	if scene.quest_state.has(KEY): return fail("Loading the Jungle created dam state")
	# The static scene leaves out exactly the dam's walls and the causeway's (g17352 host), which never overlap.
	var left_out: Array = dam.src.walls_before.duplicate()
	if scene.get("causeway") != null: left_out.append_array(scene.causeway.src.walls_before)
	if scene.excluded_faces.size() != left_out.size() or not dam.src.walls_before.all(func(i): return scene.excluded_faces.has(int(i))): return fail("Static scene still draws the river walls")
	if not dam.walls_before.visible or dam.walls_after.visible or dam.walls_after.collision_layer != 0: return fail("Initial walls wrong")
	for node in dam.foam:
		if not node.visible: return fail("Foam hidden before the break")
	var water_region := str(int(dam.src.objects.rock.region))
	if not dam.floors.has(water_region) or dam.floors[water_region].offset != 0.0: return fail("Rock region floor not at its source height")
	# A weapon in hand, standing in the river beside the rock, looking at it.
	var weapon := "jungle:weapon_shop:Short_Sword"
	scene.carried_collected.append(weapon)
	if not scene.set_equipped_item(weapon): return fail("Could not equip the short sword")
	var rock_xz := Vector2(dam.rock.global_position.x, dam.rock.global_position.z)
	var placed := false
	for angle in range(0, 360, 20):
		var xz := rock_xz + Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle))) * 70.0
		place(xz, -20.0)
		for k in 6: await physics_frame
		scene.camera.look_at(dam.rock.global_position + Vector3.UP * 70.0)
		await physics_frame
		if dam.aimed(): placed = true; break
	if not placed: return fail("No standing spot that aims at the rock")
	var reward_before = scene.quest_state.get("player_reward_state", {}).duplicate(true)
	var hits := 0
	while not dam.broken() and hits < 20:
		click(); hits += 1
		await process_frame
		if not dam.broken() and int(dam.state().durability) != 50 - 8 * hits: return fail("Hit %d left durability %d" % [hits, int(dam.state().durability)])
	if not dam.broken(): return fail("Rock never broke")
	if hits != 7: return fail("Expected 7 armed hits (durability 50, damage 8), got %d" % hits)
	var reward_after = scene.quest_state.get("player_reward_state", {})
	if reward_after.is_empty() or reward_after == reward_before: return fail("Break granted no fighting experience")
	# The drain/timer clock runs in physics; hold it so the comparison sees only what the extra hit does.
	dam.set_physics_process(false); scene.curse.set_physics_process(false)
	var rewarded: Dictionary = scene.quest_state.duplicate(true)
	click(); await process_frame
	if scene.quest_state != rewarded: return fail("A hit after the break changed the quests")
	if dam.rock_sprite.get_meta("selector").selector != 2: return fail("Rock did not turn into the stump")
	for node in dam.foam:
		if node.visible: return fail("Foam still shown after the break")
	if dam.walls_before.visible or not dam.walls_after.visible or dam.walls_after.collision_layer != 1: return fail("Drained walls not active")
	# Timer independence from clock subdivision (Codex review): 10 s and 19 s at 30/60/120/144 steps per second.
	dam.set_physics_process(false); scene.curse.set_physics_process(false)
	var curse_before: Dictionary = scene.curse.snapshot()
	var live: Dictionary = scene.quest_state[KEY].duplicate(true)
	for rate in [30, 60, 120, 144]:
		scene.quest_state[KEY] = broken_template(1140.0)
		for i in 10 * rate: dam.advance(1.0 / rate)
		if absf(float(dam.state().timer_left) - 540.0) > 0.001 or dam.state().fired: return fail("10 s at %d/s left %s" % [rate, str(dam.state().timer_left)])
		for i in int(8.99 * rate): dam.advance(1.0 / rate)
		if dam.state().fired: return fail("Timer fired early at %d/s" % rate)
		scene.curse.restore(curse_before)
		for i in rate: dam.advance(1.0 / rate)
		if not dam.state().fired or float(dam.state().timer_left) != 0.0: return fail("Timer did not fire by 19 s at %d/s" % rate)
		var requested: Dictionary = scene.curse.snapshot()
		if int(requested.phase) != 1 or int(requested.target) != 2 or float(requested.duration) < 120 or float(requested.duration) > 180: return fail("Lizard request wrong: %s" % str(requested))
		for i in rate: dam.advance(1.0 / rate)
		if scene.curse.snapshot() != requested: return fail("Lizard requested twice")
	scene.curse.restore(curse_before)
	scene.quest_state[KEY] = live
	dam.present()
	# Save in the middle of the drain (and mid-tick): reload restores the same heights and fractional timer.
	scene.quest_state[KEY].elapsed = 3.0
	scene.quest_state[KEY].timer_left = 700.25
	dam.present()
	var mid: float = dam.offset(water_region, 3.0)
	if dam.floors[water_region].offset != mid or mid >= 0.0 or mid <= -50.0: return fail("Mid-drain floor offset %s" % str(dam.floors[water_region].offset))
	var path := "user://tests/jungle_river_dam_mid.json"
	if not scene.quicksave(path).is_empty(): return fail("Mid-drain quicksave failed")
	scene.quest_state.erase(KEY); dam.present()
	if dam.floors[water_region].offset != 0.0 or dam.walls_before.visible == false: return fail("Erased state did not restore the river")
	var saved := Save.read_save(path)
	if not str(saved.error).is_empty() or not scene.apply_save(saved.state).is_empty(): return fail("Mid-drain reload failed")
	if dam.floors[water_region].offset != mid or float(dam.state().timer_left) != 700.25: return fail("Reload lost the mid-drain state")
	# Let the drain finish: every channel floor settles at its target with the mud material; stones go down with it.
	for i in 480: dam.advance(1.0 / 60.0)
	for region in dam.movers:
		if not is_equal_approx(dam.floors[region].offset, float(dam.movers[region].delta)): return fail("Region %s did not settle" % region)
		if region != str(int(dam.src.burrow.mouth.id)) and not dam.floors[region].final: return fail("Region %s not mud" % region)
	var stone: Dictionary = dam.stones[0]
	var stone_region := str(int(stone.row.region))
	if dam.movers.has(stone_region) and not is_equal_approx(stone.node.position.y, float(stone.row.position[1]) + float(dam.movers[stone_region].delta)): return fail("Stone did not settle with its floor")
	var cover: Array = dam.src.cover[0]
	var placed_cover: Array = scene.props.placements[int(cover[0])]
	var cover_y: float = placed_cover[0].get_instance_transform(placed_cover[1]).origin.y
	if not is_equal_approx(cover_y, placed_cover[2].y + float(dam.movers[str(int(cover[1]))].delta)): return fail("River ground cover did not settle")
	# The burrow: region2413 is the one-unit doorway strip in front of the mouth. A human walks the drained bed up to
	# it but is stopped by the wall above the 20-unit opening (-50..0).
	var route: Array = dam.src.burrow.route
	scene.player_form = 0; Body.apply(scene.player, scene.camera, 0, false)
	place(centroid(route[0]), float(dam.floors[str(int(route[0].id))].offset) + float(route[0].floor))
	for k in 10: await physics_frame
	var door := shared(route[1], route[2])
	await walk(centroid(route[2]), 300)
	var human_at := Vector2(scene.player.global_position.x, scene.player.global_position.z)
	if human_at.distance_to(door) > 24.0: return fail("Human did not reach the burrow mouth across the drained bed (%s from %s)" % [str(human_at), str(door)])
	if inside(route[2], scene.player.global_position) or inside(route[3], scene.player.global_position): return fail("A human passed the burrow mouth")
	# The timer's lizard (the curse's own morph), then an ordinary walk to the item room.
	scene.quest_state[KEY].timer_left = 0.5; scene.quest_state[KEY].fired = false
	scene.curse.set_requests_enabled(true)
	dam.advance(1.0 / 60.0)
	if not dam.state().fired or int(scene.curse.state.target) != 2: return fail("Timer did not request the lizard")
	scene.curse.advance(10.0)
	if scene.player_form != 2: return fail("Lizard morph did not happen (%d)" % scene.player_form)
	for i in range(2, route.size()):
		if not await walk(shared(route[i - 1], route[i])) or not await walk(centroid(route[i])): return fail("Lizard stuck before region %d" % int(route[i].id))
	var room: Dictionary = route[-1]
	var taken := await collect_room(room)
	if taken != 2: return fail("Initial room pickups failed")
	var tours: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dam_all_items_routes.json"))
	for tour in tours:
		for i in range(1, tour.size()):
			if not await walk(shared(tour[i - 1], tour[i]), 900) or not await walk(centroid(tour[i]), 900): return fail("All-item tour blocked before region %d" % int(tour[i].id))
		var count: int = await collect_room(tour[-1])
		if count < 0: return fail("All-item room pickup failed")
		taken += count
	if taken != 7: return fail("Expected all seven pickups, got %d" % taken)
	# Save after the drain: the bed, the stump and the taken items come back.
	var after := "user://tests/jungle_river_dam_after.json"
	if not scene.quicksave(after).is_empty(): return fail("Quicksave after drain failed")
	var final_state: Dictionary = scene.quest_state[KEY].duplicate(true)
	scene.quest_state.erase(KEY); scene.quest_state.erase("jungle_world_items"); dam.present()
	var reread := Save.read_save(after)
	if not str(reread.error).is_empty() or not scene.apply_save(reread.state).is_empty(): return fail("Reload after drain failed")
	if scene.quest_state[KEY] != final_state or dam.walls_before.visible or dam.rock_sprite.get_meta("selector").selector != 2: return fail("Reload lost the drained river")
	for row in dam.src.items:
		if dam.items[int(row.row)].visible: return fail("Taken burrow item came back")
	# Lizard expiry: the timed form ends while the lizard is in the 20-unit burrow, so the curse waits for room; walked
	# back out to the drained bed (ceiling 127) it turns human.
	if scene.player_form != 2 or int(scene.curse.state.phase) != 2: return fail("Not a timed lizard after reload (%d, %s)" % [scene.player_form, str(scene.curse.state)])
	scene.curse.advance(float(scene.curse.state.remaining) + 0.1)
	if scene.player_form != 2 or int(scene.curse.state.phase) != 3: return fail("Lizard changed back inside the burrow")
	for i in range(route.size() - 2, -1, -1):
		if not await walk(shared(route[i + 1], route[i]), 900) or not await walk(centroid(route[i]), 900): return fail("Lizard could not walk back out to region %d" % int(route[i].id))
	for k in 5: await physics_frame
	scene.curse.advance(0.1)
	if scene.player_form != 0 or int(scene.curse.state.phase) != 0: return fail("Lizard did not turn human outside the burrow (%d)" % scene.player_form)
	# Return continuity: the area hand-off carries the drained river and the taken items into a fresh Jungle.
	var handoff: Dictionary = scene.area_handoff()
	change_scene_to_file("res://scenes/lol2/jungle_walkthrough.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene != scene and current_scene.get("ready_for_review"): break
	if current_scene == scene or not current_scene.get("ready_for_review"): return fail("Second Jungle not ready")
	scene = current_scene; dam = scene.river_dam
	if not scene.apply_area_handoff(handoff).is_empty(): return fail("Hand-off refused")
	if not dam.broken() or dam.walls_before.visible or not dam.walls_after.visible or not dam.floors[water_region].final: return fail("Hand-off lost the drained river")
	for row in dam.src.items:
		if dam.items[int(row.row)].visible: return fail("Hand-off brought a taken item back")
	# Refusals.
	var Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
	for bad in [{"version":1,"durability":40,"broken":true,"elapsed":0.0,"timer_left":0.0,"fired":true},
			{"version":1,"durability":50,"broken":false,"elapsed":1.0,"timer_left":0.0,"fired":false},
			{"version":1,"durability":-6,"broken":true,"elapsed":0.0,"timer_left":10.0,"fired":true},
			{"version":1,"durability":-6,"broken":true,"elapsed":0.0,"timer_left":-1.0,"fired":false},
			{"version":1,"durability":-6,"broken":true,"elapsed":0.0,"timer_left":0.0,"fired":false,"extra":1}]:
		var quests: Dictionary = reread.state.quests.duplicate(true)
		quests[KEY] = bad
		if Quests.validate(quests).is_empty(): return fail("Invalid dam state accepted: %s" % str(bad))
	print("PASS jungle_river_dam: 7 ordinary hits break the rock (stump, foam gone, 2x500 fighting XP once), drain settles to mud with the walls and stones, timer 540 ticks after 10 s and fires once at 19 s for 30/60/120/144 steps, lizard 120..180 s, human stopped at the mouth, lizard walked in and took %d items with E, mid-drain and drained saves restore, expiry waits for room then human, hand-off into a fresh Jungle keeps it, bad states refused" % taken)
	quit(0)

func collect_room(room: Dictionary) -> int:
	var taken := 0
	for row in dam.src.items:
		if int(row.region) != int(room.id): continue
		var sprite: Sprite3D = dam.items[int(row.row)]
		if not sprite.visible: continue
		var spot := Vector2(sprite.global_position.x, sprite.global_position.z)
		if not await walk(spot + (centroid(room) - spot).normalized() * 20.0, 300): return -1
		scene.camera.look_at(sprite.global_position + Vector3.UP * 4.0)
		await physics_frame
		press_e(); await process_frame
		var id: String = preload("res://scripts/lol2/jungle_world_items_catalog.gd").id_of(int(row.row))
		if not id in scene.carried_collected or sprite.visible: return -1
		taken += 1
	return taken
