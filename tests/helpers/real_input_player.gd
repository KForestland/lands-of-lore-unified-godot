extends SceneTree
## Input/navigation helpers adapted from Fable's BJ14 bot (2026-11-10).
## Only engine-dispatched keys/buttons/mouse change gameplay. No top-up, revival, teleport or direct action path.
var scene:Node
var area:=""
var stops:Array=[]
var last_floor:=Vector3.ZERO
var no_fight:Array=["76","115","20","113"]
var fight_radius:=85.0
var avoid_fights:=false
var guard_tick:=0
var use_guard:=true
var broken:=false
var deaths:=0
func stop(step:String,detail:String):
	stops.append({"step":step,"detail":detail,"area":area})
	print("STOP B ",area," ",step,": ",detail," [sol]")
	broken=true
func setup_f10():pass
func say(text: String) -> void: print("BJ14 ", text)

func key_event(code: int, down: bool, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down; e.ctrl_pressed = ctrl; e.shift_pressed = shift
	Input.parse_input_event(e); Input.flush_buffered_events()

func tap(code: int, ctrl := false, shift := false) -> void:
	key_event(code, true, ctrl, shift); await process_frame
	key_event(code, false, ctrl, shift); await process_frame

func mouse_rel(v: Vector2) -> void:
	var m := InputEventMouseMotion.new(); m.relative = v; m.position = Vector2(640, 360); m.global_position = m.position
	Input.parse_input_event(m); Input.flush_buffered_events()

func button(index: int, at := Vector2(640, 360)) -> void:
	for down in [true, false]:
		var c := InputEventMouseButton.new(); c.button_index = index; c.pressed = down; c.position = at; c.global_position = at
		Input.parse_input_event(c); Input.flush_buffered_events()
		await process_frame

func lclick() -> void: await button(MOUSE_BUTTON_LEFT)

func rclick() -> void: await button(MOUSE_BUTTON_RIGHT)

func captured() -> bool: return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func frames(n: int) -> void:
	for i in n: await process_frame

func ticks(n: int) -> void:
	for i in n: await physics_frame

func hp() -> int: return int(scene.starting_magic.health())

func pos() -> Vector3: return scene.player.global_position

func hud() -> String:
	var h = scene.get("interface_hud")
	return str(h.hint.text) if is_instance_valid(h) and h.get("hint") != null else ""

func prompts() -> String:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is Label and n.is_visible_in_tree() and not n.text.is_empty() and ("—" in n.text) and n.text.length() < 240 and not ("Mana" in n.text): out.append(n.text.replace("\n", " / "))
	var line := hud()
	if not line.is_empty() and line not in out: out.append("HUD: " + line)
	return " | ".join(out)

func buttons_text() -> String:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is Button and n.is_visible_in_tree() and not n.text.is_empty(): out.append(("[%s]" if not n.disabled else "[%s (off)]") % n.text)
	return " ".join(out)

func find_button(part: String) -> Button:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is Button and n.is_visible_in_tree() and not n.disabled and part in n.text: return n
	return null

func click_button(part: String) -> bool:
	var b := find_button(part)
	if b == null: return false
	var at: Vector2 = b.get_global_transform_with_canvas() * (b.size * 0.5)
	var move := InputEventMouseMotion.new(); move.position = at; move.global_position = at; root.push_input(move)
	await process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down; e.position = at; e.global_position = at
		root.push_input(e); await process_frame
	await process_frame
	return true

func yaw_error(point: Vector3) -> float:
	var d: Vector3 = point - scene.camera.global_position
	return wrapf(atan2(-d.x, -d.z) - scene.player.global_rotation.y, -PI, PI)

func pitch_error(point: Vector3) -> float:
	var d: Vector3 = point - scene.camera.global_position
	return atan2(d.y, Vector2(d.x, d.z).length()) - scene.camera.rotation.x

func aim_dot(point: Vector3) -> float:
	return (-scene.camera.global_basis.z).dot((point - scene.camera.global_position).normalized())

func turn_step(point: Vector3, with_pitch := true) -> void:
	var rel := Vector2(-yaw_error(point) / 0.003, (-pitch_error(point) / 0.003) if with_pitch else 0.0)
	rel = rel.clamp(Vector2(-300, -300), Vector2(300, 300))
	if rel.length() > 0.2: mouse_rel(rel)

func look(point: Vector3) -> bool:
	if not captured(): return false
	for i in 40:
		turn_step(point)
		await process_frame
		if aim_dot(point) > 0.9995: return true
	return aim_dot(point) > 0.995

func hostile(id: String) -> bool:
	var pop = scene.get("act2_creatures")
	if id in no_fight or not pop.state.actors[id].present or pop.state.actors[id].health <= 0: return false
	if pop.has_method("peaceful_actor") and pop.peaceful_actor(id): return false
	var definition: int = int(pop.State.actor_row(pop.src, id).definition)
	return not bool(pop.src.definitions[str(definition)].get("peaceful_adapter", false))

func nearest_hostile(radius: float) -> String:
	var pop = scene.get("act2_creatures")
	if not is_instance_valid(pop): return ""
	var best := ""; var distance := radius
	for id in pop.bodies:
		if not hostile(id): continue
		var d: float = pop.bodies[id].global_position.distance_to(pos())
		if d < distance: distance = d; best = id
	return best

func guard() -> void:
	if not use_guard: return
	guard_tick += 1
	if guard_tick % 20 != 0 or hp() <= 0: return
	if scene.starting_magic.protected() or nearest_hostile(230.0).is_empty(): return
	await tap(KEY_1)
	await tap(KEY_Q, false, true)
	say("guard: Shift+Q near %s, protected %s, health %d" % [nearest_hostile(230.0), str(scene.starting_magic.protected()), hp()])

func pack_use(id: String, button_part: String, step: String) -> bool:
	await tap(KEY_I); await frames(8)
	var inv = scene.get("inventory")
	if not is_instance_valid(inv): stop(step, "I did not open the pack. Screen: " + prompts()); return false
	var index := -1
	for i in inv.item_list.item_count:
		if str(inv.item_list.get_item_metadata(i)) == id: index = i
	if index < 0: stop(step, "the pack does not show " + id); await tap(KEY_I); return false
	# A player scrolls the list with the wheel until the item is in view, then clicks it.
	var local := Vector2(-1, -1)
	var over: Vector2 = inv.item_list.get_global_transform_with_canvas() * (inv.item_list.size * 0.5)
	for turn in 40:
		for x in range(4, int(inv.item_list.size.x), 6):
			for y in range(4, int(inv.item_list.size.y), 6):
				if local.x < 0 and inv.item_list.get_item_at_position(Vector2(x, y), true) == index and inv.item_list.get_item_at_position(Vector2(x + 6, y + 6), true) == index: local = Vector2(x + 3, y + 3)
		if local.x >= 0: break
		var hover := InputEventMouseMotion.new(); hover.position = over; hover.global_position = over; root.push_input(hover)
		for down in [true, false]:
			var w := InputEventMouseButton.new(); w.button_index = MOUSE_BUTTON_WHEEL_DOWN; w.pressed = down; w.position = over; w.global_position = over
			root.push_input(w); await process_frame
		await frames(2)
		if turn == 0: say("PACK the item is below the visible rows; scrolling the list with the wheel")
	if local.x < 0: stop(step, "the wheel did not bring %s into view in the pack" % id); await tap(KEY_I); return false
	var at: Vector2 = inv.item_list.get_global_transform_with_canvas() * local
	var move := InputEventMouseMotion.new(); move.position = at; move.global_position = at; root.push_input(move)
	await process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down; e.position = at; e.global_position = at
		root.push_input(e); await process_frame
	await frames(4)
	var picked: Array = inv.item_list.get_selected_items()
	if picked.is_empty() or str(inv.item_list.get_item_metadata(picked[0])) != id: say("PACK click missed %s (selected %s)" % [id, str(picked)])
	var seen := buttons_text()
	var ok := await click_button(button_part)
	await frames(6)
	say("PACK %s -> '%s': clicked %s; buttons were %s; after: '%s'" % [id, button_part, str(ok), seen, hud()])
	if is_instance_valid(scene.get("inventory")): await tap(KEY_I); await frames(4)
	if is_instance_valid(scene.get("inventory")): await tap(KEY_ESCAPE); await frames(4)
	if not captured(): await lclick(); await frames(4)
	if not ok: stop(step, "the pack has no '%s' button for %s (buttons: %s)" % [button_part, id, seen])
	return ok

func heal_to(want: int) -> void:
	if hp() <= 0 or hp() >= want: return
	await tap(KEY_2)
	var nl: Array = scene.progression.native_log if scene.get("progression") != null else []
	var n0 := nl.size()
	for i in 40:
		if hp() >= want or hp() <= 0: break
		await tap(KEY_Q)
		if not is_instance_valid(scene) or current_scene != scene:
			say("NOTE the level changed while Luther stood still healing (tap %d); native log had %d rows, now %d; tail %s" % [i, n0, nl.size(), str(nl.slice(-40))]); await adopt(); return
		await ticks(35)
	await tap(KEY_1)

func fight(step: String) -> bool:
	var pop = scene.get("act2_creatures")
	if not is_instance_valid(pop): return true
	var began := false
	for tick in 9000:
		var id := nearest_hostile(fight_radius)
		if id.is_empty():
			if began: await heal_to(24)
			return true
		if not began: began = true; key_event(KEY_W, false); key_event(KEY_SHIFT, false); say("fight %s hp %d at %s (Luther %d)" % [id, pop.state.actors[id].health, str(pop.bodies[id].global_position.round()), hp()])
		if hp() <= 0:stop(step,"Luther died during the earned sitting");return false
		if hp() < 14 and not scene.starting_magic.protected(): await heal_to(24)
		await guard()
		var point: Vector3 = pop.bodies[id].global_position + Vector3.UP * 24
		turn_step(point)
		if tick % 240 == 0: say("  fighting %s: its health %d, Luther %d, distance %d, dot %.3f, aimed '%s', mana %s" % [id, pop.state.actors[id].health, hp(), int(pop.bodies[id].global_position.distance_to(pos())), aim_dot(point), str(pop.aimed()), str(scene.starting_magic.get("mana"))])
		if deaths > 6: stop(step, "gave up the fight with %s after %d deaths" % [id, deaths]); return false
		if tick % 8 == 0 and aim_dot(point) > 0.97:
			await lclick()
		else: await physics_frame
	stop(step, "fight not finished in time near " + str(pos().round()))
	return false

func walk(points: Array, step: String, opts: Dictionary = {}) -> bool:
	if not captured():
		stop(step, "the mouse is not captured, so W and the view do nothing. Screen: " + prompts())
		return false
	if area == "L10_DC":
		# F10: old fixture routes run 4 units from the south-exit corridor wall that OF9 made solid; keep 16 units off it.
		points = points.duplicate(true)
		for p in points:
			if absf(p[0] + 68.75) < 1.0 and p[1] > -400.0: p[0] = -85.0
	var jumps: Array = opts.get("jumps", [])
	var done_jumps: Array = []
	var until: Callable = opts.get("until", Callable())
	var ok := true
	var deaths_before := deaths
	var avoiding: bool = bool(opts.get("no_fight", avoid_fights))
	for index in points.size():
		if not ok: break
		var goal := Vector3(points[index][0], 0, points[index][1])
		var prior: Vector3 = pos(); var stalled := 0; var hops := 0; var reached := false
		var reach: float = float(opts.get("final_reach", 8.0)) if index == points.size() - 1 else float(opts.get("reach", 8.0))
		var budget: int = maxi(600, int(Vector2(prior.x - goal.x, prior.z - goal.z).length() * 2.0) + 600)
		var resets_before = scene.get("resets")
		if index % 10 == 0: say("walk %s %d/%d at %s" % [step, index, points.size(), str(pos().round())])
		for tick in budget:
			if until.is_valid() and until.call(): key_event(KEY_W, false); key_event(KEY_SHIFT, false); return true
			if current_scene != scene: key_event(KEY_W, false); key_event(KEY_SHIFT, false); return true
			if hp() <= 0:stop(step,"Luther died during the earned sitting");key_event(KEY_W,false);return false
			if deaths - deaths_before > 5: stop(step, "gave up this walk after %d deaths" % (deaths - deaths_before)); ok = false; break
			if not avoiding and not nearest_hostile(fight_radius).is_empty():
				if not await fight(step): ok = false; break
				prior = pos(); stalled = 0
			var d: Vector3 = goal - pos(); d.y = 0
			if d.length() < reach: reached = true; break
			await guard()
			if not is_instance_valid(scene) or current_scene != scene:
				key_event(KEY_W, false); key_event(KEY_SHIFT, false); return true
			var steer: Vector3 = d.normalized()
			var threatened := false
			if avoiding:
				var pop = scene.get("act2_creatures")
				if is_instance_valid(pop):
					for id in pop.bodies:
						if not hostile(id): continue
						var away: Vector3 = pos() - pop.bodies[id].global_position; away.y = 0
						if away.length() < 160.0: threatened = true
						if away.length() < 90.0 and away.length() > 0.01:
							var side := Vector3(-d.z, 0, d.x).normalized()
							if side.dot(away) < 0: side = -side
							steer += (away.normalized() * 0.6 + side * 1.2) * (1.0 - away.length() / 90.0)
				if hp() < 16 and not threatened and not scene.starting_magic.protected(): key_event(KEY_W, false); key_event(KEY_SHIFT, false); await heal_to(28)
			var aim: Vector3 = Vector3(pos().x + steer.x * 200.0, scene.camera.global_position.y, pos().z + steer.z * 200.0)
			var error: float = absf(yaw_error(aim))
			turn_step(aim, false)
			key_event(KEY_W, error < 0.6)
			key_event(KEY_SHIFT, (bool(opts.get("sprint", false)) or threatened) and error < 0.6)
			for j in jumps.size():
				if j in done_jumps: continue
				if Vector2(pos().x - jumps[j][0], pos().z - jumps[j][1]).length() < 12.0: done_jumps.append(j); key_event(KEY_SPACE, true); await physics_frame; key_event(KEY_SPACE, false)
			await physics_frame
			# Native travel may replace/free the area during this physics frame.
			# Release input before inspecting the abandoned body's pose or contacts.
			if not is_instance_valid(scene) or current_scene != scene:
				key_event(KEY_W, false); key_event(KEY_SHIFT, false); return true
			if pos().distance_to(prior) < 0.05 and error < 0.6: stalled += 1
			else: stalled = 0
			prior = pos()
			if stalled == 25 and hops < 12: hops += 1; stalled = 0; key_event(KEY_SPACE, true); await physics_frame; key_event(KEY_SPACE, false)
			if stalled > 240: break
			if scene.player.is_on_floor(): last_floor = pos()
			if scene.get("resets") != resets_before:
				stop(step, "the game's fall recovery moved Luther (resets %s -> %s) on the way to waypoint %d %s; last stood on a floor at %s; he is now at %s" % [str(resets_before), str(scene.get("resets")), index, str(goal), str(last_floor.round()), str(pos().round())])
				key_event(KEY_W,false);key_event(KEY_SHIFT,false);return false
		if not reached:
			var contact := ""
			for hit in scene.player.get_slide_collision_count():
				var c = scene.player.get_slide_collision(hit)
				contact += " %s n%s" % [str(c.get_collider().get_path()).get_file(), str(c.get_normal().snapped(Vector3.ONE * 0.1))]
			broken = true
			stop(step, "walk stopped at waypoint %d/%d, goal %s, contacts:%s; screen: %s" % [index, points.size(), str(goal), contact, prompts()])
			ok = false; break
	key_event(KEY_W, false); key_event(KEY_SHIFT, false)
	return ok

func act(aim: Vector3, step: String, code: int = KEY_E, ctrl := false) -> Dictionary:
	var looked := await look(aim)
	await frames(4)
	var before := prompts()
	await tap(code, ctrl)
	await frames(6)
	var out := {"looked": looked, "before": before, "after": hud(), "distance": snappedf(scene.camera.global_position.distance_to(aim), 1.0), "dot": snappedf(aim_dot(aim), 0.001)}
	say("ACT %s: prompt before '%s' -> after '%s' (distance %s, dot %s, looked %s)" % [step, before, out.after, str(out.distance), str(out.dot), str(looked)])
	return out

func adopt() -> void:
	key_event(KEY_W, false); key_event(KEY_SHIFT, false)
	scene = current_scene
	for i in 3000:
		await process_frame
		scene = current_scene
		if is_instance_valid(scene) and bool(scene.get("ready_for_review")): break
	area = str(scene.get("area_id")) if scene.get("area_id") != null else ""
	if scene.scene_file_path.ends_with("darker_jungle.tscn"): area = "L8_SJ"
	elif scene.scene_file_path.ends_with("dragon_level.tscn"): area = "L9_DR"
	await frames(20)
	say("ARRIVED %s at %s, health %d, mouse captured %s; screen: %s" % [area, str(pos().round()), hp(), str(captured()), prompts()])

func travelled(step: String, wait_frames := 600) -> bool:
	var old := scene
	for i in wait_frames:
		if current_scene != old and current_scene != null: await adopt(); return true
		await process_frame
	stop(step, "no level change happened. Screen: " + prompts())
	return false

func fixture(file: String) -> Variant: return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/" + file))

func pack_spot(inv, id: String) -> Vector2:
	for x in range(4, int(inv.item_list.size.x), 6):
		for y in range(4, int(inv.item_list.size.y), 6):
			var i: int = inv.item_list.get_item_at_position(Vector2(x, y), true)
			if i >= 0 and str(inv.item_list.get_item_metadata(i)) == id and inv.item_list.get_item_at_position(Vector2(x + 6, y + 6), true) == i: return Vector2(x + 3, y + 3)
	return Vector2(-1, -1)

func pack_drag(from_id: String, to_ids: Array, step: String) -> bool:
	await tap(KEY_I); await frames(8)
	var inv = scene.get("inventory")
	if not is_instance_valid(inv): stop(step, "I did not open the pack"); return false
	var over: Vector2 = inv.item_list.get_global_transform_with_canvas() * (inv.item_list.size * 0.5)
	var a := Vector2(-1, -1); var b := Vector2(-1, -1)
	# F10: bring the X pointer over the list first (the earlier build always scrolled here, which did this).
	OS.execute("xdotool", ["mousemove", str(int(root.position.x + over.x)), str(int(root.position.y + over.y))]); await frames(6)
	OS.execute("xdotool", ["click", "5"]); await frames(8)
	for turn in 40:
		a = pack_spot(inv, from_id); b = Vector2(-1, -1)
		for id in to_ids:
			if b.x < 0: b = pack_spot(inv, id)
		if a.x >= 0 and b.x >= 0: break
		OS.execute("xdotool", ["mousemove", str(int(root.position.x + over.x)), str(int(root.position.y + over.y))]); await frames(4)
		OS.execute("xdotool", ["click", "5"]); await frames(6)
	if a.x < 0 or b.x < 0: stop(step, "the pack never shows both items in one view (from %s, to %s)" % [str(a), str(b)]); await tap(KEY_I); return false
	var t: Transform2D = inv.item_list.get_global_transform_with_canvas()
	var pa: Vector2 = t * a; var pb: Vector2 = t * b
	# Godot performs a drop only for pointer events that come through the window, so the drag goes through X11 (xdotool).
	var wp := Vector2(root.position)
	OS.execute("xdotool", ["mousemove", str(int(wp.x + pa.x)), str(int(wp.y + pa.y))]); await frames(4)
	OS.execute("xdotool", ["mousedown", "1"]); await frames(4)
	for k in 12:
		var q: Vector2 = wp + pa.lerp(pb, float(k + 1) / 12.0)
		OS.execute("xdotool", ["mousemove", str(int(q.x)), str(int(q.y))]); await frames(4)
	say("PACK dragging: viewport says dragging %s; from %s to %s; scroll %s; window at %s; mouse %s" % [str(root.gui_is_dragging()), str(pa), str(pb), str(inv.item_list.get_v_scroll_bar().value), str(root.position), str(root.get_mouse_position())])
	OS.execute("xdotool", ["mouseup", "1"]); await frames(4)
	await frames(10)
	say("PACK drag %s -> %s done; screen '%s'" % [from_id, str(to_ids.slice(0, 1)), hud()])
	if is_instance_valid(scene.get("inventory")): await tap(KEY_I); await frames(4)
	if is_instance_valid(scene.get("inventory")): await tap(KEY_ESCAPE); await frames(4)
	if not captured(): await lclick(); await frames(4)
	return true
