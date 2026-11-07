extends SceneTree
## Playtest 2026-10-17 reports10:59:16 (first tar pit) and11:04:34 (guard tar pit). Production Cave, actual Q Spark,
## left click and E; the owner poses are the report positions; aiming turns the player/camera toward a tar prop.
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL cave_tar_fires: ", message); quit(1); return false
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
func click() -> void:
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	scene.roach.model.strike_remaining=0.0
## Owner report pose: map X/Y/H -> Godot X+4, H+430, Y+12794.
func pose(x: float, y: float, h: float, yaw: float, pitch: float) -> void:
	scene.player.global_position=Vector3(x+4,h+430,y+12794); scene.player.velocity=Vector3.ZERO
	scene.player.rotation=Vector3(0,yaw,0); scene.camera.rotation=Vector3(pitch,0,0)
	for i in 3: await physics_frame
## Mouse-look equivalent: turn the body (yaw) and camera (pitch) toward the prop's hit-volume centre.
func aim(id: String) -> void:
	var body: StaticBody3D=scene.tar_fires.bodies[id]
	var shape: CollisionShape3D=body.get_child(0)
	var d: Vector3=shape.global_position-scene.camera.global_position
	scene.player.rotation.y=atan2(-d.x,-d.z)
	scene.camera.rotation.x=atan2(d.y,Vector2(d.x,d.z).length())
	for i in 2: await process_frame
func cooled() -> void:
	var m: Dictionary=scene.starting_magic.magic_state().duplicate(true); m.cooldown=0.0; m.player.mana=maxi(int(m.player.mana),20); scene.starting_magic.commit(m)
func step(tar, seconds: float) -> void:
	for i in int(seconds*60.0): tar.advance(1.0/60.0)
func fx_started() -> bool: return bool(scene.scenic_guard.effects.packet().started)
func lit(tar, ids: Array) -> int:
	return ids.filter(func(id): return int(tar.state.props[id].selector)==2).size()
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene=scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false); scene.curse.set_physics_process(false)
	var tar=scene.tar_fires
	if tar==null or tar.sprites.size()!=27: return fail("Tar fires not hosted")
	tar.set_process(false)
	var first: Array=["465","466","467","468","469","470","471","640"]
	var guard: Array=tar.source.props.keys().filter(func(id): return int(tar.source.props[id].pit)==439)
	if guard.size()!=19: return fail("Guard pit size %d" % guard.size())
	# Owner pose 10:59:16: the first pit now shows the original bubbling tar (selector0) on its eight props.
	await pose(-653.634,-11726.51,-178.712,0.515,-0.230)
	if first.any(func(id): return not tar.sprites[id].visible or int(tar.state.props[id].selector)!=0): return fail("First pit tar not shown")
	await capture("owner_1059_16")
	var pre:="user://tests/cave_tar_pre.json"
	if not scene._quicksave(pre).is_empty(): return fail("Pre save failed")
	# Melee (context 2/4) is refused by the source masks 0x0011/0x0000.
	var weapon=preload("res://scripts/lol2/cave_stalagmite.gd")
	scene.stalagmites.restore([weapon.item_id(641,1)])
	if not scene.set_equipped_item(weapon.item_id(641,1)): return fail("Weapon fixture")
	if not tar.receive_hit("467",2,4,8) or int(tar.state.props["467"].state)!=0: return fail("Melee context ignited tar")
	# Beast form cannot cast (manual p42): Q from the owner pose leaves the tar unlit.
	scene.player_form=1; await cooled(); await aim("467"); await key(KEY_Q)
	if int(tar.state.props["467"].state)!=0: return fail("Beast Spark ignited tar")
	scene.player_form=0; scene.set_equipped_item("")
	# Human Q Spark from the owner pose, aimed at prop467 (150 units into the pit).
	await cooled(); await aim("467"); await key(KEY_Q)
	var p467: Dictionary=tar.state.props["467"]
	if int(p467.selector)!=1 or int(p467.state)!=1 or int(p467.durability)!=9: return fail("Spark did not ignite prop467: %s" % [p467])
	if not tar.voices["467"].playing: return fail("Ignition sound462 not playing")
	var s464: Dictionary=tar.state.sequencers["464"]
	if int(s464.selector)!=1 or int(s464.state)!=1 or not s464.enabled: return fail("Sequencer464 not started: %s" % [s464])
	if int(tar.state.props["465"].selector)!=0: return fail("Neighbour lit instantly")
	tar.present(); await capture("prop467_ignition")
	# Ignition animation end (35 frames) -> burning loop; the timer spreads the fire prop by prop.
	step(tar, 3.6)
	if int(tar.state.props["467"].selector)!=2: return fail("Prop467 did not reach the burning loop")
	step(tar, 2.0)
	var mid:="user://tests/cave_tar_mid.json"
	var partial: int=lit(tar, first)+first.filter(func(id): return int(tar.state.props[id].selector)==1).size()
	if partial<2 or partial>=8: return fail("Spread not progressive: %d" % partial)
	if not scene._quicksave(mid).is_empty(): return fail("Mid save failed")
	var saved: Dictionary=tar.checkpoint()
	step(tar, 40.0)
	if lit(tar, first)!=8: return fail("First pit not fully lit: %d" % lit(tar, first))
	if tar.state.sequencers["464"].enabled or int(tar.state.sequencers["464"].selector)!=10: return fail("Sequencer464 did not stop at selector10: %s" % [tar.state.sequencers["464"]])
	if lit(tar, guard)!=0: return fail("Guard pit lit by the first pit")
	await pose(-653.634,-11726.51,-178.712,0.515,-0.230); tar.present(); await capture("first_pit_burning")
	# Disk rollback to the mid-spread save and the unlit pre-ignition save; malformed packets are rejected.
	if not scene._quickload(mid).is_empty() or tar.checkpoint()!=saved: return fail("Mid-spread load did not restore")
	var bad: Dictionary=saved.duplicate(true); bad.props["467"].state=0
	if tar.validate(bad,tar.source).is_empty(): return fail("Selector/state mismatch accepted")
	bad=saved.duplicate(true); bad.sequencers["464"].selector=11
	if tar.validate(bad,tar.source).is_empty(): return fail("Sequencer selector out of range accepted")
	if not scene._quickload(pre).is_empty() or first.any(func(id): return int(tar.state.props[id].selector)!=0) or tar.state.sequencers["464"].enabled: return fail("Pre-ignition load did not restore")
	# Owner pose 11:04:34 (Beast, guard pit): Beast Q is refused; the guard target prop574 is untouched.
	await pose(-162.826,-14738.32,-232.992,0.155,-0.134)
	await capture("owner_1104_34")
	scene.player_form=1; await cooled(); await key(KEY_Q)
	if scene.scenic_guard.effects.packet().started: return fail("Beast Spark started the scenic explosion")
	scene.player_form=0
	# From this side the prop574 target box (255 wide) covers the tar behind it, so a Spark aimed at prop582 strikes
	# prop574 as the native projectile would. Prop584 lies in front of it: its record has no op19, sequencer439 then
	# spreads the fire to all 19 props, whose own records send prop223 the op19 fire hits.
	await cooled(); await aim("584"); await key(KEY_Q)
	if int(tar.state.props["584"].state)!=1 or tar.prop223_hits!=0 or not tar.state.sequencers["439"].enabled: return fail("Guard tar did not ignite: %s hits %d" % [tar.state.props["584"], tar.prop223_hits])
	if fx_started(): return fail("Prop584 Spark reached prop574")
	step(tar, 90.0)
	if lit(tar, guard)!=19: return fail("Guard pit not fully lit: %d" % lit(tar, guard))
	if tar.prop223_hits!=17: return fail("Prop223 fire hits %d (expected 17: every guard record but props583/584 has op19)" % tar.prop223_hits)
	var fx=scene.scenic_guard.effects
	if guard.any(func(id): return int(fx.packet().selectors.get(id,0))!=2 or tar.sprites[id].visible): return fail("Guard selector2 not handed to the scenic fire meshes")
	if fx.packet().started: return fail("Tar ignition started the prop574 explosion")
	fx.present(); tar.present(); await capture("guard_pit_burning")
	# The guard itself still burns only through the hosted prop574 Spark (actual Q from the owner pose, human form).
	await pose(-162.826,-14738.32,-232.992,0.155,-0.134); await cooled(); await key(KEY_Q)
	if not fx.packet().started: return fail("Prop574 Spark no longer starts the explosion")
	print("PASS cave_tar_fires: 27 tar props/2 sequencers hosted; owner10:59 pose shows tar; melee and Beast refused; human Q from the owner pose ignites prop467 (sound462, durability9, sequencer464 start); ignition->burning loop; fire spreads prop by prop to all 8 and the timer stops at selector10; mid-spread and pre-ignition disk loads restore; malformed packets rejected; owner11:04 Beast Q refused; guard tar Q -> prop223 fire hit + 19-prop spread drawn by the scenic fire meshes without the prop574 explosion; prop574 Q still starts it")
	scene.queue_free(); await process_frame; quit()
