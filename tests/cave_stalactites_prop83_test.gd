extends SceneTree
## Playtest 2026-10-17 reports10:55:20/10:55:42/10:57:04 (water, alcove rocks, prop83 alcove). Production Cave,
## actual left click / E / Spark ray; SUPPLIED: player positions and camera aim (owner poses and nearby stand points).
const Facing := []
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL cave_stalactites_prop83: ", message); quit(1); return false
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture"); root.get_texture().get_image().save_png("user://capture/"+name+".png")
func click() -> void:
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	scene.roach.model.strike_remaining=0.0
func key_e() -> void:
	var e:=InputEventKey.new(); e.keycode=KEY_E; e.pressed=true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
func face(id: String, distance: float) -> void:
	var st=scene.stalactites
	var mesh: MeshInstance3D=st.sprites[id]
	var target: Vector3=mesh.global_position+Vector3(0,(mesh.mesh as QuadMesh).size.y*0.5,0)
	var flat:=Vector3(scene.camera.global_position.x-target.x,0,scene.camera.global_position.z-target.z)
	if flat.length()<1: flat=Vector3(0,0,1)
	scene.player.global_position=target+flat.normalized()*distance+Vector3(0,-30,0)
	scene.player.velocity=Vector3.ZERO
	for i in 3: await physics_frame
	scene.camera.look_at(target)
func fighting() -> Dictionary: return scene.quest_state.get("player_reward_state",{}).get("player",{"level":-1,"experience":-1})
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene=scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false); scene.curse.set_physics_process(false)
	var st=scene.stalactites
	if st==null or st.sprites.size()!=4: return fail("Stalactites not hosted")
	# Owner pose 10:55:42 now shows prop633 above the pool.
	scene.player.global_position=Vector3(326.7+4,-218.1+430,-10393.6+12794); scene.player.rotation=Vector3(0,-2.788,0); scene.camera.rotation=Vector3(-0.041,0,0)
	await capture("owner_1055_42")
	var weapon=preload("res://scripts/lol2/cave_stalagmite.gd")
	scene.stalagmites.restore([weapon.item_id(641,1)])
	if not scene.set_equipped_item(weapon.item_id(641,1)): return fail("Weapon fixture")
	# Melee on prop633: crack, break, then the one-shot fighting award (local10).
	await face("633",60.0)
	if st.aimed()!="633": return fail("Prop633 not aimed (%s)" % st.aimed())
	var xp0: int=int(fighting().experience); var lvl0: int=int(fighting().level)
	await click()
	if st.state.props["633"].selector!=1 or st.state.props["633"].state!=1: return fail("First hit did not crack: %s" % [st.state.props["633"]])
	if not st.players["633:718"].playing: return fail("Hit sound718 not playing")
	await click()
	if st.state.props["633"].selector!=2 or st.state.props["633"].state!=3: return fail("Second hit did not break: %s" % [st.state.props["633"]])
	await capture("prop633_broken")
	if st.state.local10: return fail("Local10 set before the award record")
	await click()
	if not st.state.local10 or (int(fighting().experience)==xp0 and int(fighting().level)==lvl0): return fail("Broken stalactite gave no fighting award")
	var after_award: Dictionary=fighting().duplicate()
	await click()
	if fighting()!=after_award: return fail("Second award given")
	# E (kind4 mode0): sound298 once.
	if not await_use(): return fail("E use refused")
	if not st.state.props["633"].used or not st.players["633:298"].playing: return fail("E did not play298/set local")
	st.players["633:298"].stop()
	await key_e()
	if st.players["633:298"].playing: return fail("E repeated")
	# Save/load and malformed rejection.
	var path:="user://tests/cave_stalactites.json"
	if not scene._quicksave(path).is_empty(): return fail("Save failed")
	var saved: Dictionary=st.checkpoint()
	st.restore(null)
	if not scene._quickload(path).is_empty() or st.checkpoint()!=saved: return fail("Load did not restore stalactites")
	var bad: Dictionary=saved.duplicate(true); bad.props["633"].state=1
	if st.validate(bad,st.source).is_empty(): return fail("Selector/state mismatch accepted")
	# Spark path on a fresh state: crack, break, then the one-shot magic award.
	st.restore(null)
	var magic0: Dictionary=scene.starting_magic.magic_state().duplicate(true)
	for i in 3:
		if not st.receive_hit("632",1,1,st.SPARK_DAMAGE): return fail("Spark hit refused")
	if st.state.props["632"].state!=3 or not st.state.local10: return fail("Spark chain wrong: %s" % [st.state])
	if scene.starting_magic.magic_state().player==magic0.player: return fail("No magic award")
	# Prop83 chain: selector2 art, props190/473 removed, event20 +1 fighting level (local11), rewind on load.
	var lift=scene.prop83_lift
	var pre:="user://tests/cave_prop83_pre.json"
	if not scene._quicksave(pre).is_empty(): return fail("Pre-chain save failed")
	var removed: Array=lift._removed_instances()
	if removed.size()!=2 or not removed.all(func(n): return n.visible): return fail("Props190/473 not present before the chain (%d)" % removed.size())
	scene.player.global_position=lift.body.global_position+Vector3(0,10,50); scene.player.velocity=Vector3.ZERO
	for i in 3: await physics_frame
	scene.camera.look_at(lift.body.global_position)
	var level_before: int=int(fighting().level)
	scene.scenic_guard.effects.packet().local11=false
	await click()
	if float(lift.state.sound)<=0.0: return fail("Prop83 strike did not start sound956")
	lift._physics_process(lift.sound_seconds+0.01)
	if int(lift.state.state)!=1: return fail("Prop83 chain did not complete")
	# Rule change 2026-10-28: the chain plays g146's FLOOD movie (op21 movie 29); skip it before the checks below.
	if not lift.skip_flood() or paused: return fail("FLOOD movie missing or did not release the world")
	if not lift.sprite.visible or lift.selector2_frames.is_empty(): return fail("Prop83 vanished instead of showing selector2")
	lift._process(0.15)
	if not lift.selector2_frames.has(lift.sprite.material_override.get_shader_parameter("indices")): return fail("Prop83 not showing descriptor897")
	if removed.any(func(n): return n.visible): return fail("Props190/473 still present")
	if int(fighting().level)!=level_before+1 or not scene.scenic_guard.effects.packet().local11: return fail("Event20 level reward missing: %d -> %d" % [level_before,int(fighting().level)])
	await capture("prop83_selector2")
	if not scene._quickload(pre).is_empty(): return fail("Pre-chain load failed")
	if int(lift.state.state)!=0 or not removed.all(func(n): return n.visible): return fail("Rewind did not restore prop83/props190/473")
	print("PASS cave_stalactites_prop83: 4 stalactites hosted; owner pose shows prop633; real clicks crack/break/award fighting once (local10); E sound once; disk round trip and mismatch rejection; Spark crack/break/magic award; prop83 click -> selector2 art kept, props190/473 removed, +1 fighting level (local11), rewind restores")
	scene.queue_free(); await process_frame; quit()
func await_use() -> bool:
	return scene.stalactites.use()
