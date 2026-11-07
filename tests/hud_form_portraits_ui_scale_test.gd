extends SceneTree
## Owner request 2026-10-21: lizard/beast portraits with the transformations, and a 150-200% UI. Production Museum
## HUD: the portrait follows player_form (original P_LUTHER / P_BEAST / P_LIZARD frame 0) and the human blink stops
## in the other forms; the UI starts at 150%, F6 switches to 200% and back, the cluster grows from its bottom-right
## corner and stays on screen, the hint line stops left of it, the Character sheet always fits the window, and the
## choice persists in user://lol2_settings.cfg. Screenshots: user://tests/hud_ui_<pct>.png.
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); print("FAIL hud_form_portraits_ui_scale: ", message); quit(1)
	return ok
func key(code: Key) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	var r := InputEventKey.new(); r.keycode = code; r.pressed = false
	Input.parse_input_event(r); Input.flush_buffered_events(); await process_frame
## Screen rect including Control.scale/pivot.
func rect(c: Control) -> Rect2: return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
func layout(hud, pct: int) -> bool:
	for i in 3: await process_frame
	var view: Rect2 = hud.get_viewport().get_visible_rect()
	var cluster: Rect2 = rect(hud.cluster); var hint: Rect2 = rect(hud.hint)
	var expected := minf(pct / 100.0 * maxf(1.0, view.size.y / 720.0), minf(view.size.y * 0.45 / hud.cluster_size.y, view.size.x * 0.3 / hud.cluster_size.x))
	if not check(is_equal_approx(hud.cluster.scale.x, expected), "cluster scale %s for %d%% (expected %.3f)" % [hud.cluster.scale, pct, expected]): return false
	if not check(view.grow(0.5).encloses(cluster), "%d%%: cluster off screen %s in %s" % [pct, cluster, view]): return false
	if not check(absf(cluster.end.x - (view.end.x - 12)) < 1 and absf(cluster.end.y - (view.end.y - 12)) < 1, "%d%%: cluster not anchored bottom-right %s" % [pct, cluster]): return false
	if not check(not cluster.intersects(hint), "%d%%: hint under cluster" % pct): return false
	hud.set_cursor(true); hud.open_page("character")
	for i in 3: await process_frame
	var sheet: Rect2 = rect(hud.sheet)
	if not check(view.grow(0.5).encloses(sheet), "%d%%: sheet off screen %s" % [pct, sheet]): return false
	# At 300%/350% a 720-high window has no room left beside the capped cluster; the sheet then only has to fit.
	if not check(pct > 200 or hud.sheet.scale.x > 1.0, "%d%%: sheet not enlarged" % pct): return false
	if not check(not sheet.intersects(cluster), "%d%%: sheet covers the cluster %s %s" % [pct, sheet, cluster]): return false
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests")
	root.get_texture().get_image().save_png("user://tests/hud_ui_%d.png" % pct)
	hud.close_sheet(); hud.set_cursor(false)
	return true
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lol2_settings.cfg"))
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene); current_scene = scene
	for i in 30: await process_frame
	var hud = scene.interface_hud
	if not check(is_instance_valid(hud) and hud.portrait_textures.size() == 3 and not hud.portrait_textures.has(null), "Form portraits not loaded"): return
	# Portrait per form (human -> beast -> lizard -> human); blink only on the human face.
	for form in [0, 1, 0, 2, 0]:
		var before: int = hud.shown_form
		scene.player_form = form
		await process_frame
		if before != form:
			# The original morph (22 frames) plays first, then the form portrait.
			if not check(hud.morph_sequence.size() == 22 and hud.face.texture in hud.morph_sequence, "No morph %d->%d" % [before, form]): return
			hud.advance_morph(2.0)
		if not check(hud.morph_sequence.is_empty() and hud.face.texture == hud.portrait_textures[form], "Form %d portrait not shown" % form): return
		if form != 0:
			for i in 20: hud.advance_blink(0.25)
			if not check(not hud.blink.visible, "Blink shown on form %d" % form): return
	var human: Image = hud.portrait_textures[0].get_image(); var beast: Image = hud.portrait_textures[1].get_image(); var lizard: Image = hud.portrait_textures[2].get_image()
	if not check(human.get_size() == Vector2i(38, 52) and beast.get_size() == human.get_size() and lizard.get_size() == human.get_size(), "Portrait sizes"): return
	if not check(human.get_data() != beast.get_data() and beast.get_data() != lizard.get_data(), "Portraits identical"): return
	# UI size: 150% default, F6 -> 200% (persisted), F6 -> 150%.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not await layout(hud, 150): return
	await key(KEY_F6)
	if not check("200%" in hud.hint.text, "F6 notice '%s'" % hud.hint.text): return
	if not await layout(hud, 200): return
	var config := ConfigFile.new()
	if not check(config.load("user://lol2_settings.cfg") == OK and int(config.get_value("ui", "scale_index", -1)) == 1, "200% not persisted"): return
	# Owner r12h 2026-10-26: 300% and 350% steps, then back to 150%.
	for pct in [300, 350]:
		await key(KEY_F6)
		if not check(("%d%%" % pct) in hud.hint.text, "F6 notice '%s'" % hud.hint.text): return
		if not await layout(hud, pct): return
	if not check(config.load("user://lol2_settings.cfg") == OK and int(config.get_value("ui", "scale_index", -1)) == 3, "350% not persisted"): return
	await key(KEY_F6)
	if not await layout(hud, 150): return
	# Window multiplier: an unstretched 6144x3312 window (the owner's, after the Cave turns content scaling off)
	# multiplies the step by 3312/720; the cluster stays within 45% of the height and 30% of the width.
	var UiScale := preload("res://scripts/lol2/ui_scale.gd")
	var big := Vector2(6144, 3312)
	if not check(is_equal_approx(UiScale.resolution(big), 3312.0 / 720.0) and is_equal_approx(UiScale.resolution(Vector2(1280, 720)), 1.0) and is_equal_approx(UiScale.resolution(Vector2(800, 450)), 1.0), "Window multiplier"): return
	if not check(is_equal_approx(UiScale.cluster_scale(big, hud.cluster_size), 1.5 * 3312.0 / 720.0), "150%% at 6144x3312 not %.3f" % (1.5 * 3312.0 / 720.0)): return
	if not check(UiScale.cluster_scale(big, hud.cluster_size) * hud.cluster_size.y <= 3312 * 0.45 + 0.01, "Cluster cap"): return
	scene.queue_free()
	print("PASS hud_form_portraits_ui_scale: human/beast/lizard original portraits follow player_form through the original morphs (human<->beast, human<->lizard), blink human-only; UI 150% default, F6 200%/300%/350% (persisted) and back, window multiplier height/720 with cluster cap; cluster bottom-right on screen, hint clear of it, Character sheet enlarged, inside the window and clear of the cluster at both sizes")
	quit(0)
