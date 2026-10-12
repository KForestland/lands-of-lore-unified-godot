extends SceneTree
## Actual Cave host. After the prop83 chain opens the wall regions, a grounded walk (host walk step) from prop83's
## floor into the opened wall regions 1031/1032 on the -192 floor (the 18-unit sliver 1033 toward corridor
## 1822 is not walked: the port capsule jams there); the main chamber stays sealed
## by its source edge slopes (walking toward 1023 cannot enter). Animated props (139-143 loop, 557-564 splash) are
## indexed layer-2 billboards mirrored into the mask pass; a main-cave splash (558) is seen playing; loops advance; the
## prop1362 1 s sequencer (seeded) triggers splashes that play once and return to frame0; the world gate freezes them.
const Lift = preload("res://scripts/lol2/cave_prop83_lift_state.gd")
const ROUTE := [[374.5, -11048.0], [379.0, -11078.0], [384.2, -11109.2], [389.5, -11140.5], [392.0, -11184.8], [418.5, -11184.5], [437.2, -11176.5]]
const CHAMBER := [397.2, -11349.8]
var cave
var chamber
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); quit(1)
func host_point(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) + cave.native_translation
func step(dir: Vector3, frames: int, jump := false) -> void:
	for i in frames:
		cave.player.velocity.x = dir.x * cave.WALK_SPEED
		cave.player.velocity.z = dir.z * cave.WALK_SPEED
		cave.player.velocity.y = cave.JUMP_SPEED if jump and cave.player.is_on_floor() else (0.0 if cave.player.is_on_floor() else cave.player.velocity.y - 128.0 / 60.0)
		cave.player.move_and_slide()
		await physics_frame
func walk(points: Array) -> bool:
	for wp in points:
		var target := host_point(float(wp[0]), 0.0, float(wp[1]))
		var frames := 0; var best := INF; var stalled := 0
		while true:
			var d: Vector3 = target - cave.player.global_position; d.y = 0
			if d.length() < 5.0: break
			frames += 1
			if frames > 240: fail("Stuck walking to %s at %s" % [wp, cave.player.global_position - cave.native_translation]); return false
			if d.length() < best - 0.5: best = d.length(); stalled = 0
			else: stalled += 1
			var hop := stalled > 12
			if hop: stalled = 0
			await step(d.normalized(), 1, hop)
	return true
func floor_native() -> float:
	var p: Vector3 = cave.player.global_position
	var ray := PhysicsRayQueryParameters3D.create(p, p - Vector3(0, 2000, 0), 1, [cave.player.get_rid()])
	var hit: Dictionary = cave.get_world_3d().direct_space_state.intersect_ray(ray)
	return (hit.position.y - cave.native_translation.y) if not hit.is_empty() else -INF
func index_of(key: String) -> int:
	var tex = chamber.meshes[key].material_override.get_shader_parameter("indices")
	return chamber.textures[key].find(tex)
func run() -> void:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	cave.set_physics_process(false); cave.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chamber = cave.side_chamber
	if chamber == null or chamber.meshes.size() != 13: return fail("Side chamber owner missing")
	for key in chamber.meshes:
		var m: MeshInstance3D = chamber.meshes[key]
		if m.layers != 2 or not m.material_override is ShaderMaterial or not chamber.mirrored.has(key): return fail("Prop %s not on the indexed layer-2 path" % key)
	# Open the chamber through the prop83 chain state (the chain itself is covered by cave_prop83_lift_live_test).
	var opened := Lift.initial(); opened.state = 1; opened.opened = true; opened.shaft = Lift.SHAFT_TOP
	if not cave.prop83_lift.restore(opened).is_empty(): return fail("Opened lift state rejected")
	cave.player.global_position = host_point(370.0, -192.0 + 40.0, -11018.0); cave.player.velocity = Vector3.ZERO
	await step(Vector3.ZERO, 60)
	# Walk waypoint by waypoint, checking the floor actually stood on (ray) stays the flat source -192 floor.
	for wp in ROUTE:
		if not await walk([wp]): return
		if absf(floor_native() - (-192.0)) > 1.5: return fail("Off the -192 floor at %s: %f (player y %f)" % [wp, floor_native(), cave.player.global_position.y - cave.native_translation.y])
	await step(Vector3.ZERO, 30)
	if absf(floor_native() - (-192.0)) > 1.5: return fail("Not standing on the chamber floor: %f" % floor_native())
	# Sealed main chamber: from the opened region1031 the player walks toward 1026/1023 and cannot enter.
	cave.player.global_position = host_point(392.0, -192.0 + 40.0, -11184.8); cave.player.velocity = Vector3.ZERO
	await step(Vector3.ZERO, 40)
	var toward: Vector3 = host_point(CHAMBER[0], 0.0, CHAMBER[1]) - cave.player.global_position; toward.y = 0
	for i in 6: await step(toward.normalized(), 40, true)
	var p: Vector3 = cave.player.global_position - cave.native_translation
	if Vector2(p.x - CHAMBER[0], p.z - CHAMBER[1]).length() < 40.0: return fail("Entered the sealed chamber at %s" % p)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/cave_side_chamber_sealed.png")
	# A main-cave splash (558, region995): supplied vantage, play it and capture mid-splash.
	chamber.set_process(false)
	var s558: Vector3 = chamber.meshes["558"].global_position
	cave.player.global_position = s558 + Vector3(-45, 34, 0); cave.player.velocity = Vector3.ZERO
	cave.camera.rotation = Vector3.ZERO; cave.player.rotation = Vector3.ZERO; await physics_frame
	cave.camera.look_at(s558 + Vector3(0, 6, 0)); await physics_frame
	chamber.trigger(558); chamber.advance(0.45)
	if index_of("558") != 4: return fail("Splash 558 frame %d" % index_of("558"))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/cave_splash_558.png")
	# Loops advance; splashes play once then hold frame0 (deterministic: drive advance directly).
	chamber.set_process(false)
	chamber.splash.clear(); chamber.clock = 0.0; chamber.sequencer = 0.0
	chamber.advance(0.25)
	if index_of("139") != 2 or index_of("142") != 2: return fail("Loop frames: %d %d" % [index_of("139"), index_of("142")])
	chamber.trigger(560)
	chamber.advance(0.55)
	if index_of("560") != 5: return fail("Splash mid-play frame %d" % index_of("560"))
	chamber.advance(1.2)
	if index_of("560") != 0 or chamber.splash.has("560"): return fail("Splash did not return to frame0")
	var before: int = chamber.triggers
	for i in 100: chamber.advance(0.1)
	if chamber.triggers - before < 5: return fail("Sequencer triggered %d splashes in 10 s" % (chamber.triggers - before))
	# World gate: with the cursor released the owner's own clock does not advance.
	chamber.set_process(true)
	var c0: float = chamber.clock
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20: await process_frame
	if chamber.clock != c0: return fail("Ambient props advanced while the world was inactive")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 20: await process_frame
	if chamber.clock == c0: return fail("Ambient props did not resume")
	print("PASS cave_side_chamber_live: grounded walk into the opened wall regions 1031/1032, sealed main chamber not entered, 13 animated props on the indexed layer-2 path with mask mirrors, main-cave splash 558 plays, loop frames, one-shot splash, seeded 1 s sequencer, world gate.")
	quit()
