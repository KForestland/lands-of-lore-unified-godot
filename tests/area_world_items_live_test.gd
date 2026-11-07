extends SceneTree
## The shared world-item controller live in its three hosts: Museum (row 0 Cocos Cap through the host's plain-item E chain),
## Dark Halls (rows 4/5/28) and Savage Jungle (rows 10-21, 28) through the controller's own E. Per host: the sprites stand at
## the native positions settled onto the floor, an aimed row within reach is the target with its hint, E takes it once into
## the carried pack and the saved history (quest key / Museum checkpoint), a full pack refuses, a restored history hides
## its rows, an absent history (older save) shows every row. Approach points are supplied (teleport); no walk is replayed.
## Owner F10 2026-11-02 12:25 (L8 at -2433/145, "cant pick up the eggs"): from that standing point, looking at row 20, E takes
## the eggs through this controller (the Act2 copy of the placement is left to it), a quicksave/quickload keeps the row taken
## and the pack holds one copy; a pre-fix save that took the Act2 twin keeps the placement hidden. Museum: E with an empty hand.
const S = preload("res://scripts/lol2/area_world_items_state.gd")
const C = preload("res://scripts/lol2/item_catalog.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func aim(scene: Node3D, point: Vector3) -> void:
	var direction: Vector3 = point - scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x, -direction.z)
	scene.camera.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
## A standing point near `row` from which the row is the aimed target (view geometry), or false.
func approach(scene: Node3D, items: Node3D, row: int) -> bool:
	var base: Vector3 = items.sprites[row].global_position
	for distance in [36.0, 48.0, 64.0, 80.0]:
		for step in 8:
			var angle := step * TAU / 8.0
			scene.player.global_position = base + Vector3(cos(angle) * distance, 34, sin(angle) * distance)
			await physics_frame
			aim(scene, items.aim_point(row))
			await physics_frame
			if items.aimed_row() == row: return true
	return false
func open(path: String) -> Node3D:
	Engine.set_meta("lol2_enhanced", false)
	var scene = load(path).instantiate()
	root.add_child(scene)
	for i in 4: await process_frame
	for i in 3: await physics_frame
	return scene
func run() -> void:
	# --- Dark Halls and Savage Jungle: the controller takes E itself; history lives in quest_state.
	for spec in [["res://scenes/lol2/dark_halls.tscn", "darkhalls", [4, 5, 28]], ["res://scenes/lol2/darker_jungle.tscn", "darkerjungle", [10, 14, 18, 28]]]:
		var scene := await open(str(spec[0]))
		var area: String = spec[1]
		if scene.has_method("set_development_mode"): scene.set_development_mode(false)
		scene.set_physics_process(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var items: Node3D = scene.area_world_items
		check(is_instance_valid(items) and items.sprites.size() == S.rows(area).size() and items.handles_input, "%s: controller attached with %d rows" % [area, S.rows(area).size()])
		if not is_instance_valid(items): scene.queue_free(); await process_frame; continue
		for i in S.rows(area).size():
			var row: int = S.rows(area)[i]
			var at: Vector3 = items.sprites[row].global_position
			var native: Vector3 = S.AREAS[area].positions[i]
			check(items.sprites[row].visible and at.x == native.x and at.z == native.z and absf(at.y - native.y) <= items.SETTLE, "%s row %d stands at the native x/z, settled within 80 of the region floor (%s vs %s)" % [area, row, at, native])
		check(not scene.quest_state.has(S.key(area)), "%s: no history before a pickup (older-save shape)" % area)
		if area == "darkerjungle":
			# Act2WorldItems leaves every twin placement to this controller.
			for row in S.rows(area):
				var twin: String = items.twin_of(row)
				check(not twin.is_empty() and items.hosts_twin(twin) and not scene.act2_items.sprites.has(twin), "darkerjungle row %d: Act2 twin %s left to this controller" % [row, twin])
			# The owner's standing point (report.json position, camera 10 above), first with the reported view, then turned to row 20.
			scene.player.global_position = Vector3(-2432.26684570312, 32.039478302002, 145.659561157227)
			scene.player.rotation.y = -1.63079655170441
			scene.camera.rotation.x = -0.341003745794296
			await physics_frame
			await physics_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			print("  owner spot: camera %s, reported view aims row %d" % [scene.camera.global_position, items.aimed_row()])
			aim(scene, items.aim_point(20))
			await physics_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			check(items.target() == 20 and scene.act2_items.target().is_empty(), "owner spot: row 20 is the E target, no Act2 copy competes (%d / %s)" % [items.target(), scene.act2_items.target()])
			await process_frame
			check(scene.interface_hud.hint.text == items.interaction_hint() and items.interaction_hint() == "E — Take " + C.label(items.id_of(20)), "owner spot: HUD shows the take prompt (%s)" % scene.interface_hud.hint.text)
			var pack_before: int = scene.carried_collected.size()
			key(KEY_E)
			await process_frame
			check(items.id_of(20) in scene.carried_collected and scene.carried_collected.size() == pack_before + 1 and not items.sprites[20].visible and 20 in scene.quest_state.get(S.key(area), {}).get("collected", []), "owner spot: E took the eggs of row 20 (%s)" % [scene.carried_collected])
			key(KEY_E)
			await process_frame
			check(scene.carried_collected.count(items.id_of(20)) == 1 and scene.carried_collected.size() == pack_before + 1, "owner spot: a second E takes nothing more")
			# Save / reload: the row stays taken, one carried copy, no respawn.
			scene.camera.rotation = Vector3.ZERO
			var path := "user://tests/area_world_items_live_darker.json"
			var expected: Array = scene.carried_collected.duplicate()
			check(scene.quicksave(path).is_empty(), "darkerjungle: quicksave after the pickup")
			scene.carried_collected.clear()
			scene.quest_state.erase(S.key(area))
			check(scene.quickload(path).is_empty(), "darkerjungle: quickload")
			await physics_frame
			await physics_frame
			check(scene.carried_collected.count(items.id_of(20)) == 1 and scene.carried_collected.size() == expected.size() and not items.sprites[20].visible and 20 in items.collected, "darkerjungle: row 20 stays taken after reload, one copy carried (%s)" % [items.collected])
			# A pre-fix save that took the Act2 twin: the placement stays hidden and is not offered again.
			scene.carried_collected.erase(items.id_of(20))
			scene.quest_state.erase(S.key(area))
			scene.quest_state["act2_items"] = {"version": 1, "carried": [items.twin_of(20)], "collected": [items.twin_of(20)]}
			scene.carried_collected.append(items.twin_of(20))
			items.restore()
			check(not items.sprites[20].visible and 20 in items.collected and items.id_of(20) not in scene.carried_collected, "darkerjungle: an Act2-twin pickup from an older save keeps row 20 taken")
			scene.carried_collected.erase(items.twin_of(20))
			scene.quest_state.erase("act2_items")
			scene.quest_state.erase(S.key(area))
			items.restore()
			check(items.sprites[20].visible and items.collected.is_empty(), "darkerjungle: cleared history shows row 20 again")
		for row in spec[2]:
			var ok := await approach(scene, items, row)
			check(ok, "%s row %d: a supplied point aims it" % [area, row])
			if not ok: continue
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			check(items.target() == row and items.interaction_hint() == "E — Take " + C.label(items.id_of(row)), "%s row %d: target + hint (%s)" % [area, row, items.interaction_hint()])
			if row == spec[2][0]:
				var pack: Array = scene.carried_collected.duplicate()
				while scene.carried_collected.size() < C.MAX_CARRIED: scene.carried_collected.append("filler:%d" % scene.carried_collected.size())
				var full: Array = scene.carried_collected.duplicate()
				check(items.collect() and items.sprites[row].visible and row not in items.collected and scene.carried_collected == full, "%s row %d: full pack refuses, row stays, pack unchanged" % [area, row])
				scene.carried_collected = pack
			key(KEY_E)
			await process_frame
			var id: String = items.id_of(row)
			check(id in scene.carried_collected and scene.carried_collected.count(id) == 1 and row in items.collected and not items.sprites[row].visible, "%s row %d: E took %s once" % [area, row, id])
			check(scene.quest_state.has(S.key(area)) and row in scene.quest_state.get(S.key(area), {}).get("collected", []), "%s row %d: history written under %s" % [area, row, S.key(area)])
			check(items.target() != row and not items.collect(), "%s row %d: gone after the pickup" % [area, row])
		check(S.validate(scene.quest_state.get(S.key(area)), area).is_empty() and scene.quest_state.get(S.key(area), {}).get("collected", []).size() == spec[2].size(), "%s: history valid with %d rows" % [area, spec[2].size()])
		# A restored history (quicksave shape) hides its rows; a carried id without history migrates into it.
		scene.quest_state[S.key(area)] = {"version": 1, "collected": [float(spec[2][0])]}
		for row in spec[2]: scene.carried_collected.erase(items.id_of(row))
		items.restore()
		check(not items.sprites[spec[2][0]].visible and items.sprites[spec[2][1]].visible and items.collected == [spec[2][0]], "%s: restored history hides row %d only" % [area, spec[2][0]])
		scene.quest_state.erase(S.key(area))
		scene.carried_collected.append(items.id_of(spec[2][1]))
		items.restore()
		check(scene.quest_state.has(S.key(area)) and items.collected == [spec[2][1]] and not items.sprites[spec[2][1]].visible and items.sprites[spec[2][0]].visible, "%s: a carried id migrates into a fresh history (%s)" % [area, items.collected])
		scene.queue_free(); await process_frame
	# --- Museum: the host's plain-item E chain calls use(); history is the checkpoint value museum_world_items.
	var museum := await open("res://scenes/lol2/museum_walkthrough.tscn")
	if museum.has_method("set_development_mode"): museum.set_development_mode(false)
	museum.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var cap: Node3D = museum.world_items
	check(is_instance_valid(cap) and cap.sprites.size() == 1 and not cap.handles_input and cap.sprites[0].visible, "museum: controller attached with row 0 visible")
	if is_instance_valid(cap):
		var ok := await approach(museum, cap, 0)
		check(ok, "museum row 0: a supplied point aims it (%s)" % cap.sprites[0].global_position)
		if ok:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			check(cap.target() == 0 and museum._plain_item_hint() == "E — Take Cocos Cap", "museum row 0: target + host hint (%s)" % museum._plain_item_hint())
			var before: int = museum.carried_collected.size()
			museum.hand_item = ""
			key(KEY_E)
			await process_frame
			check("museum:item0:Cocos_Cap" in museum.carried_collected and museum.carried_collected.size() == before + 1 and not cap.sprites[0].visible, "museum row 0: E took the cap (%s)" % [museum.carried_collected])
			check(cap.checkpoint() == {"version": 1, "collected": [0]}, "museum: checkpoint value %s" % [cap.checkpoint()])
			check(cap.target() != 0 and not cap.use(), "museum row 0: gone after the pickup")
		museum.carried_collected.erase("museum:item0:Cocos_Cap")
		check(cap.restore_checkpoint(null).is_empty() and cap.sprites[0].visible and cap.collected.is_empty(), "museum: absent checkpoint (older save) shows the row")
		check(cap.restore_checkpoint({"version": 1, "collected": [0]}).is_empty() and not cap.sprites[0].visible, "museum: restored checkpoint hides it")
		check(not cap.restore_checkpoint({"version": 1, "collected": [3]}).is_empty(), "museum: a foreign row is refused")
	museum.queue_free(); await process_frame
	print("Area world items live: %d failures" % failures)
	if failures == 0: print("PASS area world items live: owner L8 spot row 20 eggs taken by E and kept over quicksave/quickload, Act2 twins left to the controller, Dark Halls rows 4/5/28 and Savage Jungle rows 10/14/18/28 taken by E with quest-key history, Museum row 0 Cocos Cap through the plain-item chain with its checkpoint; full-pack refusal, restore, migration and older-save defaults")
	quit(0 if failures == 0 else 1)
