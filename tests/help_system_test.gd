extends SceneTree
## Original in-game help (owner reports 10:57:04 and 2026-10-20 11:11:50). Production Cave, headless: decoded original
## texts/art; native gate (enabled + one-time topic bit); banner "Press [icon] for help on ..."; F1 opens the page
## (world paused, '@' replaced by this version's keys), Esc closes, T toggles help messages; Cave triggers: region1077
## entry (topic 7), first sighting of prop1363 (topic 8), a crystal pickup (topic 1), no trigger from a restored
## load; the help packet survives quicksave/quickload, legacy saves start fresh, malformed packets are refused.
## Headless cannot capture the mouse: trigger polling is driven by cave_help.advance().
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL help_system: ", message); quit(1); return false
func key(code: Key) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	var r := InputEventKey.new(); r.keycode = code; r.pressed = false
	Input.parse_input_event(r); Input.flush_buffered_events(); await process_frame
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/help_system/texts.json"))
	if data.topics.size() != 8 or str(data.topics["1"].banner) != "Press for help on using your inventory." or not str(data.topics["8"].page).begins_with("^Targeting"): return fail("Decoded texts")
	if str(data.topics["6"].banner) != "Press for miscellaneous help." or data.subs["0x33"] != 8 or data.subs["0x32"] != 7: return fail("Banner/sub mapping")
	var page_img := Image.load_from_file("res://assets/lol2/generated/help_system/page.png")
	if page_img.get_size() != Vector2i(320, 200) or page_img.get_pixel(0, 0).a != 0.0 or page_img.get_pixel(160, 100).a != 1.0: return fail("Scroll page art")
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	scene.curse.set_physics_process(false)
	var help = scene.interface_hud.help
	var cave_help = scene.cave_help
	if help == null or cave_help == null: return fail("Help not hosted")
	cave_help.set_physics_process(false)
	for i in 3: await process_frame
	if int(help.state.seen) != 0 or not bool(help.state.enabled): return fail("Fresh state %s" % [help.state])
	# Native gate: one-time bit; disabled help shows nothing and does not consume the bit.
	if not help.request(4) or not help.banner.visible or help.banner_text.text != "for help on combat.": return fail("Banner")
	if help.request(4): return fail("Topic shown twice")
	help.state.enabled = false
	if help.request(6) or int(help.state.seen) & (1 << 5): return fail("Disabled help consumed topic 6")
	help.state.enabled = true
	# F1 opens the page for the shown topic: paused, keys substituted, native leave line; T toggles; Esc closes.
	help.show_banner(5)
	var was_paused: bool = paused
	await key(KEY_F1)
	if not help.page_open() or not paused: return fail("F1 did not open a paused page")
	if help.page_title.text != "Movement" or help.page_body.text.contains("@") or not help.page_body.text.contains("Press and hold the [key] key to run") or not help.page_body.text.contains("Shift runs"): return fail("Page text '%s'" % help.page_body.text.left(200))
	if not help.page_footer.text.begins_with("Press F1 to leave or enter the help system."): return fail("Footer '%s'" % help.page_footer.text)
	await key(KEY_T)
	if bool(help.state.enabled): return fail("T did not switch help off")
	await key(KEY_T)
	await key(KEY_ESCAPE)
	if help.page_open() or paused != was_paused: return fail("Esc did not close/unpause")
	# Codex review (help_reopen_review): with help messages switched off and the page closed, F1 still enters the help
	# system (last page viewed); a restored disabled state shows no stale banner.
	await key(KEY_F1)
	await key(KEY_T)
	if bool(help.state.enabled): return fail("T did not switch help off (reopen case)")
	await key(KEY_F1)
	if help.page_open(): return fail("F1 did not close the page")
	await key(KEY_F1)
	if not help.page_open() or help.page_title.text != "Movement": return fail("F1 cannot re-enter help with messages off")
	await key(KEY_T)
	await key(KEY_ESCAPE)
	# Grok/Codex help_unread_review: an expired or replaced banner is not lost. F1 opens the latest announced topic,
	# Left/Right browse all eight pages, and each page states this version's controls (1 = Spark, 2 = Healing, M = map).
	help.show_banner(2)
	help.banner_left = 0.0
	help._process(0.1)
	if help.banner.visible: return fail("Banner did not expire")
	await key(KEY_F1)
	if not help.page_open() or help.page_topic != 2: return fail("F1 after expiry did not open the announced topic (%d)" % help.page_topic)
	if not help.page_body.text.contains("M opens the map"): return fail("Automapper page lacks this version's map key")
	await key(KEY_RIGHT)
	if not help.page_open() or help.page_topic != 3 or not paused: return fail("Right did not browse to topic 3")
	if not help.page_body.text.contains("1 loads Spark, 2 loads Healing"): return fail("Magic page spell keys wrong")
	for i in 6: await key(KEY_RIGHT)
	if help.page_topic != 1: return fail("Topics do not wrap (%d)" % help.page_topic)
	await key(KEY_LEFT)
	if help.page_topic != 8 or help.page_body.text.contains("(none)"): return fail("Left/targeting page (%d)" % help.page_topic)
	await key(KEY_ESCAPE)
	if help.page_open() or paused != was_paused: return fail("Esc after browsing did not restore the pause state")
	help.show_banner(3)
	if not help.restore({"version":1,"enabled":false,"seen":4}).is_empty(): return fail("Disabled restore refused")
	if help.banner.visible or help.banner_topic != 0: return fail("Stale banner after restore (topic %d)" % help.banner_topic)
	help.restore({"version":1,"enabled":true,"seen":0})
	# Cave triggers. Region1077 (grounded entry) -> topic 7.
	cave_help.rebase()
	var r: Dictionary = cave_help.src.region
	var c := Vector2.ZERO
	for p in r.polygon: c += Vector2(p[0], p[1])
	c /= r.polygon.size()
	scene.player.global_position = scene.native_translation + Vector3(c.x, float(r.floor_min) + 40.0, c.y)
	scene.player.velocity = Vector3.ZERO
	# Headless: the Cave only moves the player with a captured mouse, so drop the body onto the floor here.
	for i in 40:
		scene.player.velocity = Vector3(0, -200, 0)
		scene.player.move_and_slide()
		await physics_frame
	cave_help.advance()
	# Region1077 lies in the crate room: prop1219 (topic 6) is in view there too and may take the banner.
	if not int(help.state.seen) & (1 << 6): return fail("Region1077 did not raise topic 7 (on floor %s)" % scene.player.is_on_floor())
	# First sighting of prop1363 -> topic 8: stand 300 units away, look at it.
	var s: Dictionary = cave_help.src.sighted["1363"]
	var target: Vector3 = scene.native_translation + Vector3(s.position[0], float(s.position[1]) + float(s.height) * 0.5, s.position[2])
	scene.player.global_position = target + Vector3(0, -40, 120)
	for i in 3: await physics_frame
	scene.camera.look_at(target)
	await process_frame
	if not cave_help.visible_point(target, []):
		# Geometry may hide the prop from this probe pose; look from straight above the floor instead.
		scene.player.global_position = target + Vector3(0, 60, 1)
		for i in 3: await physics_frame
		scene.camera.look_at(target)
		await process_frame
	cave_help.advance()
	if not int(help.state.seen) & (1 << 7): return fail("Sighting prop1363 did not raise topic 8")
	# Crystal pickup -> topic 1 (counted on the native trigger items only).
	var before: int = cave_help.trigger_items()
	scene.stalagmites.collected.append(scene.stalagmites.collected[0] if not scene.stalagmites.collected.is_empty() else preload("res://scripts/lol2/cave_stalagmite.gd").item_id(641, 1))
	cave_help.advance()
	if cave_help.trigger_items() != before + 1 or not int(help.state.seen) & 1: return fail("Pickup did not raise topic 1")
	# Disk round trip; a restored load is a new baseline, not a pickup.
	var path := "user://tests/help_system_save.json"
	if not scene._quicksave(path).is_empty(): return fail("Save")
	var saved_bits := int(help.state.seen)
	help.state.seen = 0
	if not scene._quickload(path).is_empty(): return fail("Load")
	for i in 3: await process_frame
	if int(help.state.seen) != saved_bits: return fail("Help bits not restored")
	cave_help.advance()
	if help.banner_topic == 1 and help.banner_left > help.BANNER_SECONDS - 0.01: return fail("Load counted as a pickup")
	if not help.restore(null).is_empty() or int(help.state.seen) != 0: return fail("Legacy restore")
	for bad in [{"version":1,"enabled":1,"seen":0}, {"version":1,"enabled":true,"seen":300}, {"version":2,"enabled":true,"seen":0}]:
		if help.validate(bad).is_empty(): return fail("Accepted %s" % [bad])
	print("PASS help_system: original helptext.trr topics 1-8 + banners, scroll page art; native gate (enabled + one-time bit); banner 'Press [icon] for help on ...'; F1 page paused with this version's keys and the native leave line, T toggles help, Esc closes, F1 re-enters with messages off, an expired banner's topic stays reachable, Left/Right browse all pages with this version's controls, restore clears a stale banner; Cave region1077 -> 7, prop1363 sighting -> 8, crystal pickup -> 1; save/load keeps the bits and is not a pickup; legacy/malformed packets")
	quit(0)
