extends SceneTree
## Headless half of the shared world-item controller (area_world_items.gd) in its three hosts: attached with the area's rows,
## sprites at the native x/z settled onto the floor within 80 units of the region floor, every row aimed from a supplied
## standing point (view geometry: reach, aim cone, layer-1 occlusion), hint text, history restore / migration / checkpoint
## and the older-save default. The E press and the capture gate need a display (area_world_items_live_test, rendered).
const S = preload("res://scripts/lol2/area_world_items_state.gd")
const C = preload("res://scripts/lol2/item_catalog.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func aim(scene: Node3D, point: Vector3) -> void:
	var direction: Vector3 = point - scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x, -direction.z)
	scene.camera.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
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
	for spec in [["res://scenes/lol2/dark_halls.tscn", "darkhalls", "area_world_items", true], ["res://scenes/lol2/darker_jungle.tscn", "darkerjungle", "area_world_items", true], ["res://scenes/lol2/museum_walkthrough.tscn", "museum", "world_items", false]]:
		var scene := await open(str(spec[0]))
		var area: String = spec[1]
		if scene.has_method("set_development_mode"): scene.set_development_mode(false)
		scene.set_physics_process(false)
		var items: Node3D = scene.get(str(spec[2]))
		check(is_instance_valid(items) and items.sprites.size() == S.rows(area).size() and items.handles_input == bool(spec[3]) and items.area == area, "%s: controller attached with %d rows, self-input %s" % [area, S.rows(area).size(), spec[3]])
		if not is_instance_valid(items): scene.queue_free(); await process_frame; continue
		var aimed := 0
		for i in S.rows(area).size():
			var row: int = S.rows(area)[i]
			var at: Vector3 = items.sprites[row].global_position
			var native: Vector3 = S.AREAS[area].positions[i]
			check(items.sprites[row].visible and at.x == native.x and at.z == native.z and absf(at.y - native.y) <= items.SETTLE and items.settled.has(row), "%s row %d at the native x/z, settled within 80 of the region floor (%s vs %s)" % [area, row, at, native])
			if await approach(scene, items, row): aimed += 1
			else: print("  %s row %d: no supplied point within 80 units aims it (%s)" % [area, row, at])
		check(aimed == S.rows(area).size(), "%s: every row aimed from a supplied standing point (%d/%d)" % [area, aimed, S.rows(area).size()])
		if area == "darkerjungle":
			# Owner F10 2026-11-02 12:25 (report.json: player -2432.27/32.04/145.66, "cant pick up the eggs"): one sprite and one
			# E owner per placement; from that standing point, turned to the eggs, row 20 is the aimed row.
			var shared := 0
			for row in S.rows(area):
				if not items.twin_of(row).is_empty() and items.hosts_twin(items.twin_of(row)) and not scene.act2_items.sprites.has(items.twin_of(row)) and not scene.act2_items.available(items.twin_of(row)): shared += 1
			check(shared == S.rows(area).size(), "darkerjungle: every row's Act2 twin left to this controller (%d/%d)" % [shared, S.rows(area).size()])
			scene.player.global_position = Vector3(-2432.26684570312, 32.039478302002, 145.659561157227)
			scene.player.rotation.y = -1.63079655170441
			scene.camera.rotation.x = -0.341003745794296
			await physics_frame
			await physics_frame
			aim(scene, items.aim_point(20))
			await physics_frame
			check(items.aimed_row() == 20 and scene.act2_items.target().is_empty(), "darkerjungle owner spot: row 20 aimed, no Act2 copy competes (%d / %s)" % [items.aimed_row(), scene.act2_items.target()])
			scene.quest_state["act2_items"] = {"version": 1, "carried": [], "collected": [items.twin_of(20)]}
			items.restore()
			check(not items.sprites[20].visible and 20 in items.collected, "darkerjungle: an Act2-twin pickup from an older save keeps row 20 taken")
			scene.quest_state.erase("act2_items")
			scene.quest_state.erase(S.key(area))
			items.restore()
			check(items.sprites[20].visible and items.collected.is_empty(), "darkerjungle: cleared history shows row 20 again")
		var first: int = S.rows(area)[0]
		var second: int = S.rows(area)[1] if S.rows(area).size() > 1 else first
		check(items.id_of(first) == S.id_of(area, first) and C.label(items.id_of(first)) != "", "%s: ids resolve (%s)" % [area, items.id_of(first)])
		if bool(spec[3]):
			check(not scene.quest_state.has(S.key(area)) and items.collected.is_empty(), "%s: no history before a pickup" % area)
			scene.quest_state[S.key(area)] = {"version": 1, "collected": [float(first)]}
			items.restore()
			check(items.collected == [first] and not items.sprites[first].visible and (first == second or items.sprites[second].visible), "%s: restored history hides row %d only" % [area, first])
			scene.quest_state.erase(S.key(area))
			scene.carried_collected.append(items.id_of(second))
			items.restore()
			check(scene.quest_state.has(S.key(area)) and items.collected == [second] and not items.sprites[second].visible and (first == second or items.sprites[first].visible), "%s: a carried id migrates into a fresh history (%s)" % [area, items.collected])
			scene.carried_collected.erase(items.id_of(second))
			scene.quest_state.erase(S.key(area))
			items.restore()
			check(items.collected.is_empty() and items.sprites[first].visible and items.sprites[second].visible, "%s: cleared history shows every row again" % area)
		else:
			check(items.checkpoint() == {"version": 1, "collected": []}, "museum: empty checkpoint value")
			check(items.restore_checkpoint({"version": 1, "collected": [0]}).is_empty() and not items.sprites[0].visible and items.collected == [0], "museum: restored checkpoint hides row 0")
			check(items.checkpoint() == {"version": 1, "collected": [0]}, "museum: checkpoint reproduces the restored history")
			check(items.restore_checkpoint(null).is_empty() and items.sprites[0].visible and items.collected.is_empty(), "museum: absent checkpoint (older save) shows the row")
			check(not items.restore_checkpoint({"version": 1, "collected": [3]}).is_empty() and not items.restore_checkpoint({"version": 2, "collected": []}).is_empty(), "museum: foreign row / version refused")
			scene.carried_collected.append("museum:item0:Cocos_Cap")
			items.restore()
			check(items.collected == [0] and not items.sprites[0].visible, "museum: a carried cap counts as taken")
			scene.carried_collected.erase("museum:item0:Cocos_Cap")
		scene.queue_free(); await process_frame
	print("Area world items headless: %d failures" % failures)
	if failures == 0: print("PASS area world items headless: 17 rows attached in Dark Halls / Savage Jungle / Museum at settled native positions, every row aimable from a supplied point, history restore / migration / checkpoint and older-save defaults")
	quit(0 if failures == 0 else 1)
