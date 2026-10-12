extends SceneTree
## One normal-play HUD in Cave, Museum, Jungle and Hive (docs/classic-hud.md), run with --demo-interface. At window
## sizes 960x540 and 1280x720 each area checks:
## - the modern StartingMagic panel is hidden (the classic cluster replaces it); exactly one classic shell;
## - the coordinate overlay (PlaytestLocation, lead-owned), the cluster and the hint line are on screen and pairwise
##   non-overlapping;
## - a cast notice (Healing) appears on the shared hint line.
## Developer view (development_mode on) restores the modern panel. Screenshots go to user://tests/classic_hud_<area>_<w>.png.
## Supplied: health/mana values and Museum intro-complete; casts use the normal world path.
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func overlay_rect() -> Rect2:
	var overlay = root.get_node_or_null("PlaytestLocation")
	if overlay == null or not overlay.label.visible: return Rect2()
	return overlay.label.get_global_rect()
func area_checks(area, label: String, size: Vector2i) -> bool:
	get_root().size = size
	for i in 6: await process_frame
	var hud = area.interface_hud; var magic = area.starting_magic
	if not check(is_instance_valid(hud) and not magic.panel.visible and magic.classic_hud_present(),"%s %s: modern panel visible %s" % [label,size,magic.panel.visible]): return false
	var view: Rect2 = hud.get_viewport().get_visible_rect()
	var cluster: Rect2 = hud.cluster.get_global_rect(); var hint: Rect2 = hud.hint.get_global_rect(); var coords := overlay_rect()
	if not check(view.encloses(cluster) and view.encloses(hint),"%s %s: off screen %s %s in %s" % [label,size,cluster,hint,view]): return false
	if not check(not cluster.intersects(hint),"%s %s: cluster/hint overlap" % [label,size]): return false
	if area.has_node("Warriors"):
		var hl: String = area.get_node("Warriors").label.text
		if not check(not "Left click: strike" in hl and not hl.begins_with("Health"),"%s %s: Hive modern health label '%s'" % [label,size,hl]): return false
	if coords.has_area():
		if not check(view.encloses(coords) and not coords.intersects(cluster) and not coords.intersects(hint),"%s %s: coordinates overlap %s cluster %s hint %s" % [label,size,coords,cluster,hint]): return false
	# Cast notice on the hint line (normal world cast).
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; hud.set_cursor(false)
	hud.save_notice_remaining = 0.0
	magic.select_spell("heal"); magic.set_health(20)
	var saved: Dictionary = magic.magic_state().duplicate(true); saved.player.mana = 10; saved.cooldown = 0.0; magic.commit(saved)
	var cast_ok: bool = magic.cast()
	for i in 2: await process_frame
	if not check(cast_ok and "Healing" in hud.hint.text,"%s %s: notice not on hint (cast %s) '%s'" % [label,size,cast_ok,hud.hint.text]): return false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/classic_hud_%s_%d.png" % [label.to_lower(), size.x])
	magic.select_spell("spark")
	return true
## Hive with a targeted return warrior (rescue-return fixture as net_exile_onhit_hive_test, supplied): the target label
## (y48 in normal play) shows the warrior and stays clear of the coordinates and the cluster at both sizes; the Hive
## Character page carries the aura status once the Lightning aura is up.
func hive_enemy(scene) -> bool:
	scene.set_physics_process(false); scene.curse.set_physics_process(false); scene.hive_curse.set_physics_process(false)
	var guards = scene.get_node("Warriors"); var pop = scene.return_population; pop.set_physics_process(false)
	var fixture: Dictionary = scene.area_handoff()
	fixture.quests.shared_flag_38 = 1; fixture.quests.hive_room_entered = true
	fixture.quests.conversation = {"started":true,"completed":true,"section_cursor":3,"elapsed":5.0}
	if not check(scene.apply_area_handoff(fixture).is_empty(),"Hive return fixture"): return false
	scene.set_physics_process(false); pop.set_physics_process(false)
	var target: CharacterBody3D = pop.bodies["27"]; var clear := false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; scene.interface_hud.set_cursor(false)
	for offset in [Vector3(0,32,65),Vector3(0,32,-65),Vector3(65,32,0),Vector3(-65,32,0)]:
		scene.player.position = pop.State.SPAWNS[27] + offset
		scene.camera.look_at(target.global_position)
		for i in range(2): await physics_frame
		var hit: Dictionary = guards.aimed_hit()
		if not hit.is_empty() and hit.collider == target: clear = true; break
	if not check(clear,"No warrior vantage"): return false
	for size in [Vector2i(960,540), Vector2i(1280,720)]:
		get_root().size = size
		for i in 6: await process_frame
		var lab: Label = guards.label; var coords := overlay_rect(); var cluster: Rect2 = scene.interface_hud.cluster.get_global_rect()
		if not check("Hive Warrior" in lab.text and not lab.text.begins_with(" ·") and not "Left click" in lab.text,"Hive target label '%s'" % lab.text): return false
		if not check(not lab.get_global_rect().intersects(coords) and not lab.get_global_rect().intersects(cluster),"Hive target label %s overlaps coords %s / cluster %s" % [lab.get_global_rect(),coords,cluster]): return false
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://tests/classic_hud_hive_enemy_%d.png" % size.x)
	var magic = scene.starting_magic
	magic.aura.start()
	await process_frame
	var page: String = scene.interface_hud.character_text()
	if not check(magic.status_lines().size() > 0 and magic.status_lines().all(func(l): return l in page),"Hive Character page lacks status %s: '%s'" % [magic.status_lines(), page]): return false
	return true
func open(path: String):
	var area = load(path).instantiate()
	root.add_child(area); current_scene = area
	for i in range(600):
		await process_frame
		if area.get("walkthrough_ready") == null or area.walkthrough_ready: break
	for i in 4: await process_frame
	area.set_physics_process(false)
	if area.has_method("set_development_mode") and path.find("cave") < 0: area.set_development_mode(false)
	if area.get("introduction_state") != null:
		area.introduction_state = "complete"
		if is_instance_valid(area.get("introduction")): area.introduction.close()
	await process_frame
	return area
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	set_meta("lol2_cave_completion", {"collected": [], "equipped_item": "", "health": 30})
	for entry in [["Cave","res://scenes/lol2/cave_walkthrough.tscn"],["Museum","res://scenes/lol2/museum_walkthrough.tscn"],["Jungle","res://scenes/lol2/jungle_walkthrough.tscn"],["Hive","res://scenes/lol2/hive_review.tscn"]]:
		var area = await open(entry[1])
		if not check(is_instance_valid(area.get("interface_hud")),"%s: no classic shell" % entry[0]): return
		for size in [Vector2i(960,540), Vector2i(1280,720)]:
			if not await area_checks(area, entry[0], size): return
		if entry[0] == "Museum":
			area.set_development_mode(true); await process_frame; await process_frame
			if not check(area.starting_magic.panel.visible,"Developer view lost the modern panel"): return
			area.set_development_mode(false); await process_frame; await process_frame
			if not check(not area.starting_magic.panel.visible,"Panel back after developer view"): return
		if entry[0] == "Hive":
			if not await hive_enemy(area): return
		area.queue_free(); await process_frame; await process_frame
	remove_meta("lol2_cave_completion")
	get_root().size = Vector2i(1280,720)
	print("PASS classic_hud_layout: Cave/Museum/Jungle/Hive at 960x540 and 1280x720 — modern panel hidden with the classic shell, cluster/hint/coordinates on screen without overlap, Healing notice on the shared hint; Hive targeted-warrior label clear of coordinates/cluster and aura status on the Hive Character page; developer view restores the panel.")
	quit()
