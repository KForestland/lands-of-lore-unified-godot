extends SceneTree
## Prop223 explosion (L1_DC groups2326/2732, tools/prepare_cave_prop223.py) in the production Cave: actual Q Spark on
## guard-pit tar from the owner report pose 11:04:34 (aimed by turning the view), actual floor walk into region969
## (stream0 group560), disk saves. Supplied: player poses (report pose, region969 approach point).
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL cave_prop223: ", message); quit(1); return false
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture"); root.get_texture().get_image().save_png("user://capture/"+name+".png")
func key(code: Key) -> void:
	var e:=InputEventKey.new(); e.keycode=code; e.pressed=true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	var r:=InputEventKey.new(); r.keycode=code; r.pressed=false
	Input.parse_input_event(r); Input.flush_buffered_events(); await process_frame
func owner_pose() -> void:
	scene.player.global_position=Vector3(-162.826+4,-232.992+430,-14738.32+12794); scene.player.velocity=Vector3.ZERO
	scene.player.rotation=Vector3(0,0.155,0); scene.camera.rotation=Vector3(-0.134,0,0)
	for i in 3: await physics_frame
func aim_at(point: Vector3) -> void:
	var d: Vector3=point-scene.camera.global_position
	scene.player.rotation.y=atan2(-d.x,-d.z); scene.camera.rotation.x=atan2(d.y,Vector2(d.x,d.z).length())
	for i in 2: await process_frame
func aim(id: String) -> void:
	var body: StaticBody3D=scene.tar_fires.bodies[id]
	await aim_at((body.get_child(0) as CollisionShape3D).global_position)
func cooled() -> void:
	var m: Dictionary=scene.starting_magic.magic_state().duplicate(true); m.cooldown=0.0; m.player.mana=maxi(int(m.player.mana),20); scene.starting_magic.commit(m)
func progress() -> Array:
	var m: Dictionary=scene.starting_magic.magic_state()
	return [int(m.player.level),int(m.player.experience)]
## Scene clocks advanced deterministically: tar timers/animation, scenic queue/effects.
func step(seconds: float) -> void:
	for i in int(seconds*60.0):
		scene.tar_fires.advance(1.0/60.0); scene.scenic_guard.advance(1.0/60.0)
func until_seen(group: String, seconds: float) -> bool:
	for i in int(seconds*60.0):
		if group in scene.scenic_guard.state.seen: return true
		scene.tar_fires.advance(1.0/60.0); scene.scenic_guard.advance(1.0/60.0)
	return group in scene.scenic_guard.state.seen
func walk_region969() -> bool:
	var pop=scene.guard_population; var guard=scene.scenic_guard; var t: Vector3=scene.native_translation
	var region: Dictionary=pop.src.regions.filter(func(r):return int(r.region)==969)[0]
	var polygon:=PackedVector2Array(); var centre:=Vector2.ZERO
	for v in region.polygon: polygon.append(Vector2(v[0],v[1])); centre+=Vector2(v[0],v[1])
	centre/=region.polygon.size()
	var floor_hit: Dictionary={}
	for angle in range(0,360,15):
		var p:=centre+Vector2(cos(deg_to_rad(angle)),sin(deg_to_rad(angle)))*100
		if Geometry2D.is_point_in_polygon(p,polygon): continue
		var start:=Vector3(p.x,-220,p.y)+t
		floor_hit=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start-Vector3.UP*160,1))
		if not floor_hit.is_empty() and absf(floor_hit.position.y-t.y+265)<12: break
		floor_hit={}
	if floor_hit.is_empty(): return false
	var direction: Vector3=(Vector3(centre.x,0,centre.y)+Vector3(t.x,0,t.z)-Vector3(floor_hit.position.x,0,floor_hit.position.z)).normalized()
	scene.player.global_position=floor_hit.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	scene.flying=false
	await physics_frame
	for i in range(150):
		scene.player.velocity=direction*48+Vector3.DOWN*10; scene.player.move_and_slide()
		pop.advance(1.0/60.0); guard.advance(1.0/60.0)
		await physics_frame
		if 969 in pop.state.regions: return true
	return false
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene=scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false); scene.curse.set_physics_process(false)
	var guard=scene.scenic_guard; var fx=guard.effects; var tar=scene.tar_fires; var pop=scene.guard_population
	guard.set_physics_process(false); pop.set_physics_process(false); tar.set_process(false)
	scene.wild_roach_population.set_physics_process(false); scene.roach_population_live.set_process(false)
	if not guard.source.groups.has("2326") or not guard.source.groups.has("2732"): return fail("Prop223 groups not merged")
	# Initial source presence: prop223 absent (placement 0x5402 bit0x1000), no box, prop574/guard55 present.
	if guard.state.prop223_present or guard.prop_meshes["223"].visible or fx.target223.collision_layer!=0 or not guard.state.prop_present or not guard.state.present: return fail("Initial prop223/prop574 presence")
	var pre:="user://tests/cave_prop223_pre.json"
	if not scene._quicksave(pre).is_empty(): return fail("Pre save failed")
	# --- Before the sighting: Q on guard-pit tar prop584 (no op19 of its own); the spread's first op19 fire hit reaches
	# the absent prop223. Native delivery has no absence test, so group2326 runs; its movie is not updated (unlinked).
	await owner_pose(); var before: Array=progress()
	await cooled(); await aim("584"); await key(KEY_Q)
	if int(tar.state.props["584"].state)!=1: return fail("Pre-sighting tar did not ignite")
	if not until_seen("2326", 60.0): return fail("Pre-sighting fire hit did not reach prop223 (hits %d)" % tar.prop223_hits)
	step(1.0)
	if not guard.state.pending.is_empty(): return fail("Group2326 blocked: %s" % [guard.state.pending])
	await capture("presighting_burning")
	if int(guard.state.local0)!=1 or guard.state.prop223_present or int(guard.state.prop223_state)!=0: return fail("Absent prop223 state after 2326: %s" % [guard.state])
	if float(fx.packet().prop223.movie_time)!=0.0 or fx.packet().prop223.movie_done or "2732" in guard.state.seen or fx.overlay.visible: return fail("Absent prop223 movie advanced: %s" % [fx.packet().prop223])
	if fx.packet().started or "5926" in guard.state.seen or fx.packet().reward_issued or progress()!=before: return fail("Pre-sighting 2326 touched prop574/reward")
	if not fx.packet().sounds.has("411") or fx.packet().sounds.has("426"): return fail("2326 sound set wrong: %s" % [fx.packet().sounds])
	if fx.fire_meshes.keys().any(func(id): return int(fx.packet().selectors.get(id,0))!=2): return fail("2326 did not select the fires")
	# local0 now blocks region969's group560: guard55 and prop574 stay, guard54 is not spawned.
	if not await walk_region969(): return fail("Region969 walk (pre-sighting branch)")
	if "560" in guard.state.seen or not guard.state.present or not guard.state.prop_present or pop.state.actors["54"].present: return fail("local0 did not gate group560")
	# --- Sighting branch from the pre-ignition save: actual walk into region969 runs group560.
	if not scene._quickload(pre).is_empty(): return fail("Pre load failed")
	scene.set_physics_process(false); scene.curse.set_physics_process(false)
	if "2326" in guard.state.seen or int(guard.state.local0)!=0 or int(tar.state.props["584"].state)!=0: return fail("Pre load did not restore")
	if not await walk_region969(): return fail("Region969 walk")
	if not guard.state.prop223_present or guard.state.prop_present or guard.state.present or not pop.state.actors["54"].present: return fail("Group560 sighting branch: %s" % [guard.state])
	if not guard.prop_meshes["223"].visible: return fail("Prop223 helper not shown after sighting")
	guard.advance(1.0/60.0)
	if fx.target223.collision_layer!=2 or fx.target.collision_layer!=0: return fail("Spark boxes after sighting")
	var sighted:="user://tests/cave_prop223_sighted.json"
	if not scene._quicksave(sighted).is_empty(): return fail("Sighted save failed")
	var sighted_state: Dictionary=guard.checkpoint()
	# Actual Q on tar prop584 from the owner pose -> spread -> op19 fire hit -> prop223 group2326.
	await owner_pose(); before=progress()
	await cooled(); await aim("584"); await key(KEY_Q)
	if not until_seen("2326", 60.0): return fail("Sighted fire hit did not start 2326")
	step(0.2)
	var q: Dictionary=fx.packet().prop223
	if not q.movie_loaded or float(q.movie_time)<=0.0 or int(q.durability)!=0: return fail("Prop223 movie did not start: %s" % [q])
	await aim_at(fx.target223.global_position+Vector3.UP*79.5); fx.present()
	if not fx.overlay.visible: return fail("Prop223 explode.vqa overlay not shown at prop223")
	await capture("prop223_explosion")
	step(2.5)
	var mid:="user://tests/cave_prop223_mid.json"
	if not scene._quicksave(mid).is_empty(): return fail("Mid-movie save failed")
	var mid_state: Dictionary=guard.checkpoint()
	if float(mid_state.effects.prop223.movie_time)<2.0 or float(mid_state.effects.prop223.movie_time)>=6.0: return fail("Mid-movie clock %s" % mid_state.effects.prop223.movie_time)
	step(4.0)
	if not "2732" in guard.state.seen or guard.state.prop223_present or int(guard.state.prop223_state)!=1 or guard.prop_meshes["223"].visible or fx.target223.collision_layer!=0: return fail("Group2732 completion: %s" % [guard.state])
	if not guard.state.pending.is_empty(): return fail("Completion blocked: %s" % [guard.state.pending])
	if fx.packet().reward_issued or progress()!=before or fx.packet().sounds.has("426") or fx.packet().started: return fail("Prop223 explosion gave a guard reward/sound426/prop574 start")
	# Mid-movie disk rollback continues to the same completion; the next tar hit cannot repeat the one-shot record.
	if not scene._quickload(mid).is_empty() or guard.checkpoint()!=mid_state: return fail("Mid-movie load did not restore")
	scene.set_physics_process(false); scene.curse.set_physics_process(false)
	step(4.0)
	if not "2732" in guard.state.seen or guard.state.prop223_present: return fail("Restored movie did not complete")
	var hits: int=tar.prop223_hits
	if guard.receive_prop223_hit(0x10,0,5): return fail("Prop223 record repeated")
	# Backward restore to the sighted (pre-explosion) save; a direct Spark on the prop223 box also runs 2326.
	if not scene._quickload(sighted).is_empty() or guard.checkpoint()!=sighted_state or "2326" in guard.state.seen: return fail("Sighted load did not restore")
	scene.set_physics_process(false); scene.curse.set_physics_process(false)
	if not guard.state.prop223_present or not guard.prop_meshes["223"].visible: return fail("Backward restore lost prop223")
	await owner_pose(); guard.advance(1.0/60.0)
	await cooled(); await aim_at(fx.target223.global_position+Vector3.UP*79.5)
	var ray:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.camera.global_position-scene.camera.global_basis.z*384,3,[scene.player.get_rid()]))
	var direct: bool=not ray.is_empty() and ray.collider==fx.target223
	if direct:
		await key(KEY_Q)
		if not "2326" in guard.state.seen: return fail("Direct Spark on prop223 did not start 2326")
	elif not guard.receive_damage("prop223",8,false,20) or not "2326" in guard.state.seen: return fail("Prop223 Spark entry refused")
	# Malformed and legacy packets.
	var bad: Dictionary=guard.checkpoint(); bad.effects.prop223.movie_done=true; bad.effects.prop223.movie_time=1.0
	if guard.State.validate(bad,guard.source).is_empty(): return fail("Done-before-end prop223 movie accepted")
	bad=guard.checkpoint(); bad.prop223_state=2
	if guard.State.validate(bad,guard.source).is_empty(): return fail("prop223_state 2 accepted")
	var legacy: Dictionary=guard.State.initial(); legacy.erase("prop223_state"); legacy.effects.erase("prop223")
	if not guard.State.validate(legacy,guard.source).is_empty() or guard.State.canonical(legacy).prop223_state!=0 or not guard.State.canonical(legacy).effects.has("prop223"): return fail("Legacy scenic packet without prop223 rejected")
	print("PASS cave_prop223: groups2326/2732 merged; prop223 absent at start; pre-sighting Q tar fire reaches absent prop223 -> 2326 (fires, sound411 only, local0=1, no reward, movie frozen, no 2732) and local0 gates region969; actual walk into region969 links prop223 and removes guard55/prop574; Q tar -> op19 -> 2326 explode.vqa at prop223 -> mid-movie disk save -> 2732 unlink/state1, no guard55 reward or sound426; mid-movie rollback completes; one-shot record; backward restore to the sighted save; Spark on prop223 (direct=%s) starts 2326; malformed/legacy packets" % direct)
	scene.queue_free(); await process_frame; quit()
