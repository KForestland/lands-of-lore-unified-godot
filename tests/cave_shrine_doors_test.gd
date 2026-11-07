extends SceneTree
## Playtest 2026-10-20 report 18:53 ("should be able to move them, the pillars"). Production Cave: the shrine blocks
## (controls 0/1) are solid; the player's own contact never opens them (kind10 byte4 6 needs actor38); guard38,
## spawned by region1941, touching a block slides both into the niches (op18 targets); saves keep the state.
var scene: Node3D
var last_hit:=""
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL cave_shrine_doors: ", message); quit(1); return false
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture"); root.get_texture().get_image().save_png("user://capture/"+name+".png")
## Owner report pose: map X/Y/H -> Godot X+4, H+430, Y+12794.
func pose(x: float, y: float, h: float, yaw: float, pitch: float) -> void:
	scene.player.global_position=Vector3(x+4,h+430,y+12794); scene.player.velocity=Vector3.ZERO
	scene.player.rotation=Vector3(0,yaw,0); scene.camera.rotation=Vector3(pitch,0,0)
	for i in 4: await physics_frame
## Can the player body move from map (x, y) on the corridor floor 150 units south through the shrine?
func passes(x: float) -> bool:
	var from: Transform3D=scene.player.global_transform
	from.origin=scene.native_translation+Vector3(x,-187,-10690)  # body origin 32 above the feet (player_form_body)
	var hit:=KinematicCollision3D.new()
	if not scene.player.test_move(from,Vector3(0,0,-150),hit): return true
	last_hit="%s at %s" % [hit.get_collider().name if hit.get_collider()!=null else "?",hit.get_position()-scene.native_translation]
	return false
func guard_at(doors, x: float, z: float) -> void:
	var g: Dictionary=doors._guard()
	g.body.global_position=scene.native_translation+Vector3(x,-220,z); g.body.velocity=Vector3.ZERO
	doors.advance(1.0/60.0)
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene=scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.curse.set_physics_process(false)
	var doors=scene.get("shrine_doors")
	if doors==null: return fail("Shrine doors not hosted")
	doors.set_physics_process(false)
	var trap=scene.get("pillar_trap")
	if trap!=null: trap.set_process(false)
	if scene.guard_population==null: return fail("No guard population")
	if not scene.static_assemblies.stateful_meshes.has(0) or not scene.static_assemblies.stateful_meshes.has(1): return fail("Blocks not separately drawn")
	# Owner pose 18:53:28 (north of the shrine, looking south at both blocks): closed, solid, no gap wide enough.
	await pose(-487.005,-10695.118,-177.959,-0.212,-0.159)
	await capture("owner_1853_28_closed")
	if int(doors.state)!=0: return fail("Not closed at start")
	for x in [-477.0,-442.0,-512.0,-425.0,-528.0]:
		if passes(x): return fail("Player passes the closed shrine at x %s" % x)
		if not last_hit.begins_with("Block"): return fail("Closed probe at x %s hit %s, not a block" % [x,last_hit])
	var pre:="user://tests/cave_shrine_pre.json"
	if not scene._quicksave(pre).is_empty(): return fail("Pre save failed")
	# Modern adapter: the human player pressing into block0's north face (16 units, reach 15+2) parts the blocks.
	scene.player.global_position=scene.native_translation+Vector3(-442,-187,-10717)
	doors.advance(1.0/60.0)
	if int(doors.state)!=1 or int(doors.group)!=9666: return fail("Player contact did not run control0's group: %s" % [doors.checkpoint()])
	for i in 120: doors.advance(1.0/60.0)
	for i in 2: await physics_frame
	if int(doors.state)!=2 or not passes(-477.0): return fail("Player-opened shrine still blocks: "+last_hit)
	if not scene._quickload(pre).is_empty(): return fail("Pre reload failed")
	for i in 3: await physics_frame
	if int(doors.state)!=0 or passes(-477.0): return fail("Pre reload did not close the shrine")
	# Standing clear (43 units) does not open them.
	scene.player.global_position=scene.native_translation+Vector3(-442,-187,-10690)
	for i in 30: doors.advance(1.0/60.0)
	if int(doors.state)!=0: return fail("Opened without contact")
	# Guard38 absent: nothing. Region1941 (player entry, g2328) links him at his post north of the shrine.
	if not doors._guard().is_empty(): return fail("Guard38 present before region1941")
	if trap==null: return fail("Pillar trap (region1941 owner) missing")
	await pose(-476,-11144,-180,0,0)
	for i in 30:
		await physics_frame
		if scene.player.is_on_floor(): break
	trap.advance(1.0/60.0)
	for i in 3: await physics_frame
	if doors._guard().is_empty(): return fail("Guard38 not spawned by region1941")
	# Guard38 well clear of the blocks: no contact. Pressed against block1's north face: control1 g9708 runs.
	await guard_at(doors,-512,-10650)
	if int(doors.state)!=0: return fail("Contact at 83 units")
	await guard_at(doors,-512,-10718)
	if int(doors.state)!=1 or int(doors.group)!=9708: return fail("Guard contact did not run control1's group: %s" % [doors.checkpoint()])
	for i in 120: doors.advance(1.0/60.0)
	if int(doors.state)!=2: return fail("Slide did not finish")
	var o0: Vector3=doors.bodies[0].position; var o1: Vector3=doors.bodies[1].position
	if not o0.is_equal_approx(Vector3(-396+442,0,-(10761-10758))) or not o1.is_equal_approx(Vector3(-561+512,0,-(10754-10759))): return fail("Targets %s %s" % [o0,o1])
	if not scene.static_assemblies.stateful_meshes[0][0].position.is_equal_approx(o0): return fail("Block0 mesh not moved")
	for i in 2: await physics_frame
	if not passes(-477.0): return fail("Corridor still blocked after the slide: "+last_hit)
	await pose(-487.005,-10695.118,-177.959,-0.212,-0.159)
	await capture("owner_1853_28_open")
	# One-shot: further contact changes nothing.
	await guard_at(doors,-442,-10718)
	if int(doors.group)!=9708 or int(doors.state)!=2: return fail("Re-ran")
	var post:="user://tests/cave_shrine_post.json"
	if not scene._quicksave(post).is_empty(): return fail("Post save failed")
	if not scene._quickload(pre).is_empty(): return fail("Pre load failed")
	for i in 3: await physics_frame
	if int(doors.state)!=0 or passes(-477.0) or not doors.bodies[0].position.is_zero_approx(): return fail("Pre load did not close")
	if not scene._quickload(post).is_empty(): return fail("Post load failed")
	for i in 3: await physics_frame
	if int(doors.state)!=2 or not passes(-477.0): return fail("Post load did not open")
	# Control0 contact runs g9666 (its own targets).
	doors.restore(null)
	await guard_at(doors,-442,-10718)
	if int(doors.group)!=9666: return fail("Control0 group")
	# Legacy saves start closed; malformed packets are refused.
	if not doors.restore(null).is_empty() or int(doors.state)!=0: return fail("Legacy restore")
	var src: Dictionary=doors.src
	for bad in [{"version":1,"state":2,"group":0,"clock":0.0},{"version":1,"state":0,"group":9666,"clock":0.0},
			{"version":1,"state":1,"group":9666,"clock":9.0},{"version":1,"state":2,"group":1234,"clock":0.0},{"version":2,"state":0,"group":0,"clock":0.0}]:
		if doors.validate(bad,src).is_empty(): return fail("Accepted %s" % [bad])
	print("PASS cave_shrine_doors: controls 0/1 drawn separately at the owner pose 18:53:28; closed blocks stop the player at every gap; human contact parts them (g9666) and the corridor passes, no contact from 43 units; guard38 linked by region1941; no contact at 83 units; guard touching block1 runs g9708 (block0 to x -396, block1 to x -561), slide finishes, corridor passes; one-shot; pre/post disk loads; block0 contact runs g9666; legacy/malformed packets")
	quit(0)
