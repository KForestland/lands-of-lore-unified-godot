extends SceneTree
## Drowning per form in the water regions (owner 2026-10-31: Luther can drown in the Cave river, the Lizard drowns in water
## everywhere). Jungle (L4_HJ pack): on a stream (depth 9..46) the Human stands dry while the Lizard is submerged; in the
## river (depth > 69) every form is; 15 simulated seconds under (the oracle-measured limit) drown the player (health 0 + notice) and R-style health
## restore resets the clock; the river-dam regions stop being water once the dam is broken. Savage Jungle (L8_SJ) and the
## Museum pool (L3_DH): the controller is attached and its deepest region submerges the Lizard. Cave: river_region_query's
## per-form rule against the authored plane. Headless: the controller is driven by tick(), not the frame clock.
const Liquid := preload("res://scripts/lol2/liquid_drowning.gd")
const Form := preload("res://scripts/lol2/player_form_body.gd")
const Query := preload("res://scripts/lol2/river_region_query.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func centroid(region: Dictionary) -> Vector2:
	var c := Vector2.ZERO
	for p in region.polygon: c += p
	return c / region.polygon.size()
func place(scene, liquid, region: Dictionary, form: int) -> void:
	var c := centroid(region)
	scene.player_form = form
	Form.apply(scene.player, scene.camera, form, false)
	scene.player.global_position = Vector3(c.x, float(region.floor) + Form.FOOT_OFFSET, c.y)
	scene.player.velocity = Vector3.ZERO
func pick(liquid, low: float, high: float) -> Dictionary:
	var best := {}
	for r in liquid.regions:
		var depth: float = r.surface - r.floor
		if depth >= low and depth <= high and not r.bit0:
			if best.is_empty() or r.polygon.size() == 4: best = r
	return best
func open(path: String) -> Node3D:
	Engine.set_meta("lol2_enhanced", false)
	var scene = load(path).instantiate()
	root.add_child(scene)
	for i in 4: await process_frame
	for i in 3: await physics_frame
	if scene.has_method("set_development_mode"): scene.set_development_mode(false)
	scene.set_physics_process(false)
	return scene
func run() -> void:
	# --- Cave rule (no scene): the authored plane -295, feet 32 under the origin, heads 46 / 69.
	var q := Query.new()
	var bed := Vector3(-1100, -395 + Form.FOOT_OFFSET, -17150)  # region 6 centre, standing on the bed (depth 100)
	check(q.submerged_form(bed, 0) and q.submerged_form(bed, 1) and q.submerged_form(bed, 2), "Cave bed: every form submerged")
	var wade := Vector3(-1100, -295 - 20 + Form.FOOT_OFFSET, -17150)  # feet 20 under the plane
	check(q.submerged_form(wade, 2) and not q.submerged_form(wade, 0) and not q.submerged_form(wade, 1), "Cave 20 deep: only the Lizard")
	var chest := Vector3(-1100, -295 - 50 + Form.FOOT_OFFSET, -17150)
	check(q.submerged_form(chest, 0) and not q.submerged_form(chest, 1), "Cave 50 deep: Human yes, Beast no")
	# --- Jungle.
	var scene := await open("res://scenes/lol2/jungle_walkthrough.tscn")
	var liquid = scene.liquid_drowning
	check(is_instance_valid(liquid) and liquid.regions.size() == 810 and liquid.area == "L4_HJ", "Jungle: controller with 810 water regions (%s)" % [liquid.regions.size() if is_instance_valid(liquid) else -1])
	# Owner F10 2026-11-04 23:05:28 "cant drown" mid-river at (4582,-2539): bank-less region 4311 takes its bed's common bank.
	var mid: Array = liquid.regions.filter(func(r): return int(r.id) == 4311) if is_instance_valid(liquid) else []
	check(mid.size() == 1 and float(mid[0].surface) - float(mid[0].floor) > 46.0, "Jungle mid-river region 4311 deeper than a Human (%s)" % [mid])
	if mid.size() == 1:
		place(scene, liquid, mid[0], 0)
		check(liquid.submerged(scene.player.global_position, 0), "mid-river region 4311: the Human is submerged")
	if not is_instance_valid(liquid): quit(1); return
	liquid.set_physics_process(false)
	var stream: Dictionary = pick(liquid, 12, 40)
	var river: Dictionary = pick(liquid, 70, 10000)
	check(not stream.is_empty() and not river.is_empty(), "a stream (12..40 deep) and a river (>69) region exist")
	place(scene, liquid, stream, 0)
	check(not liquid.submerged(scene.player.global_position, 0) and liquid.last_region == stream.id, "stream region %d (depth %.0f): the Human stands dry" % [stream.id, stream.surface - stream.floor])
	place(scene, liquid, stream, 2)
	check(liquid.submerged(scene.player.global_position, 2), "stream: the Lizard is submerged")
	for form in 3:
		place(scene, liquid, river, form)
		check(liquid.submerged(scene.player.global_position, form), "river region %d (depth %.0f): form %d submerged" % [river.id, river.surface - river.floor, form])
	# Drowning clock: 15 simulated seconds under as the Lizard (river_drowning_state.LIMIT, oracle 2026-10-31) -> health 0,
	# notice, no walking; health restored -> reset.
	place(scene, liquid, stream, 2)
	scene.starting_magic.set_health(30)
	for i in 14: liquid.tick(1.0, 1)
	check(liquid.drowning.active and not liquid.drowning.dead and scene.starting_magic.health() == 30, "14 s under: active, alive")
	liquid.tick(1.5, 1)
	check(liquid.drowning.dead and scene.starting_magic.health() == 0 and scene.player_fallen(), "15.5 s under: drowned, health 0, fallen (%s)" % liquid.drowning.message())
	scene.starting_magic.set_health(30)
	liquid.tick(0.1, 1)
	check(not liquid.drowning.dead and liquid.drowning.elapsed == 0.0, "health restored (R / F9): the clock resets")
	# Owner r16: jump, fall back into the river, jump again. The 15 s clock keeps running.
	# Standing on a shallow bed, head above the surface, resets it.
	var jump_river: Dictionary = {}
	for r in liquid.regions:
		var depth: float = float(r.surface) - float(r.floor)
		if depth >= 70.0 and depth <= 84.0 and not r.bit0 and (r.polygon as PackedVector2Array).size() >= 3:
			if jump_river.is_empty() or (r.polygon as PackedVector2Array).size() == 4: jump_river = r
	check(not jump_river.is_empty(), "a river 70..84 deep exists so a jump can clear the head")
	if not jump_river.is_empty():
		place(scene, liquid, jump_river, 0)
		scene.starting_magic.set_health(30)
		liquid.drowning.reset()
		var body: CharacterBody3D = scene.player
		body.floor_snap_length = 0.0
		body.set_physics_process(false)
		var floor_y := float(jump_river.floor)
		var jump_bed := Vector3(body.global_position.x, floor_y + Form.FOOT_OFFSET, body.global_position.z)
		body.global_position = jump_bed + Vector3(0, 8, 0)
		body.velocity = Vector3(0, 96, 0)
		body.move_and_slide()
		body.global_position = jump_bed + Vector3(0, 8, 0)
		body.velocity = Vector3(0, 96, 0)
		var jumps := 1
		var cleared := false
		var returned := false
		var dt := 1.0 / 60.0
		var guard := 0
		while not liquid.drowning.dead and guard < 2400:
			guard += 1
			var feet := body.global_position.y - Form.FOOT_OFFSET
			var on_bed := absf(feet - floor_y) <= 2.0
			if on_bed and absf(body.velocity.y) < 1.0:
				jumps += 1
				body.global_position = jump_bed + Vector3(0, 8, 0)
				body.velocity = Vector3(0, 96, 0)
				body.move_and_slide()
				body.global_position = jump_bed + Vector3(0, 8, 0)
				body.velocity = Vector3(0, 96, 0)
			else:
				body.velocity.y -= 128.0 * dt
				body.global_position.y += body.velocity.y * dt
				if body.global_position.y - Form.FOOT_OFFSET <= floor_y:
					body.global_position = jump_bed
					body.velocity = Vector3.ZERO
					returned = true
			if not liquid._under_surface(jump_river, body.global_position, 0): cleared = true
			var clock_before: float = liquid.drowning.elapsed
			liquid.tick(dt, 1)
			if not liquid.drowning.dead and liquid.drowning.elapsed + 0.001 < clock_before:
				check(false, "jump clock reset mid-river at %.2f -> %.2f" % [clock_before, liquid.drowning.elapsed])
				break
		check(jumps >= 2, "jump loop left the bed and jumped again (%d)" % jumps)
		check(cleared and returned, "a jump cleared the surface and the body fell back into the river")
		check(liquid.drowning.dead, "jump loop in mid-river still drowns at 15 s (%.2f, %d jumps)" % [liquid.drowning.elapsed, jumps])
		check(is_equal_approx(liquid.overlay.shown_ratio, 1.0), "overlay is full at death")
		scene.starting_magic.set_health(30)
		liquid.tick(0.1, 1)
		check(liquid.drowning.elapsed == 0.0 and is_equal_approx(liquid.overlay.shown_ratio, 0.0), "recovery clears the overlay")
		place(scene, liquid, jump_river, 0)
		scene.starting_magic.set_health(30)
		liquid.drowning.reset()
		for i in 4: liquid.tick(1.0, 1)
		check(liquid.drowning.elapsed >= 4.0, "clock runs while standing under in the river")
		place(scene, liquid, stream, 0)
		scene.player.velocity = Vector3.ZERO
		var stood: Dictionary = liquid.polygon_at(scene.player.global_position)
		check(not stood.is_empty() and not liquid._under_surface(stood, scene.player.global_position, 0), "stream stand is inside the polygon and above the surface")
		liquid.tick(1.0, 1)
		check(liquid.drowning.elapsed == 0.0, "standing above the surface resets the clock")
		place(scene, liquid, jump_river, 2)
		scene.starting_magic.set_health(30)
		liquid.drowning.reset()
		for i in 6: liquid.tick(1.0, 1)
		check(is_equal_approx(liquid.overlay.shown_ratio, liquid.drowning.elapsed / liquid.drowning.LIMIT), "overlay height follows elapsed/LIMIT")
	# Out of the water the clock does not run; flying never drowns.
	place(scene, liquid, stream, 0)
	for i in 20: liquid.tick(1.0, 1)
	check(not liquid.drowning.active and scene.starting_magic.health() == 30, "the Human on the stream never drowns")
	place(scene, liquid, stream, 2); scene.flying = true
	for i in 20: liquid.tick(1.0)
	check(not liquid.drowning.dead and not liquid.running(), "flying: the world gate refuses, no drowning"); scene.flying = false
	# River dam: its regions are water while the dam stands and dry once broken.
	var dam_ids: Array = preload("res://scripts/lol2/jungle_river_dam.gd").dynamic_regions()
	var dam_region := {}
	for r in liquid.regions: if int(r.id) in dam_ids: dam_region = r; break
	check(not dam_region.is_empty() and liquid.dam_regions.size() == dam_ids.size(), "the dam's %d regions are known to the controller (%d)" % [dam_ids.size(), liquid.dam_regions.size()])
	if not dam_region.is_empty():
		place(scene, liquid, dam_region, 2)
		scene.player.global_position.y = float(dam_region.surface) - 1.0 + Form.FOOT_OFFSET
		var before: bool = liquid.region_at(scene.player.global_position).get("id", -1) == dam_region.id
		var state: Dictionary = preload("res://scripts/lol2/jungle_river_dam.gd").initial()
		state.broken = true; state.durability = 0; state.fired = true; state.timer_left = 0
		scene.quest_state[preload("res://scripts/lol2/jungle_river_dam.gd").KEY] = state
		var after: bool = liquid.region_at(scene.player.global_position).is_empty()
		check(before and after, "dam region %d: water while standing, dry once broken (%s / %s)" % [dam_region.id, before, after])
		scene.quest_state.erase(preload("res://scripts/lol2/jungle_river_dam.gd").KEY)
	scene.queue_free(); await process_frame
	# --- Savage Jungle and the Museum pool: attached, deepest region submerges the Lizard.
	for spec in [["res://scenes/lol2/darker_jungle.tscn", "L8_SJ", 40], ["res://scenes/lol2/museum_walkthrough.tscn", "L3_DH", 19]]:
		var host := await open(str(spec[0]))
		var node = host.liquid_drowning
		check(is_instance_valid(node) and node.area == str(spec[1]) and node.regions.size() == int(spec[2]), "%s: controller with %d water regions (%s)" % [spec[1], spec[2], node.regions.size() if is_instance_valid(node) else -1])
		if is_instance_valid(node):
			node.set_physics_process(false)
			var deepest := {}
			for r in node.regions:
				if not r.bit0 and (deepest.is_empty() or r.surface - r.floor > deepest.surface - deepest.floor): deepest = r
			place(host, node, deepest, 2)
			check(node.submerged(host.player.global_position, 2), "%s: the Lizard is submerged in region %d (depth %.0f)" % [spec[1], deepest.id, deepest.surface - deepest.floor])
		host.queue_free(); await process_frame
	print("Liquid drowning: %d failures" % failures)
	if failures == 0: print("PASS liquid drowning: Cave per-form plane; Jungle streams drown the Lizard and the river every form, 15 s clock (oracle-measured) -> health 0 + reset on recovery, dam regions dry when broken; Savage Jungle and Museum pool attached")
	quit(0 if failures == 0 else 1)
