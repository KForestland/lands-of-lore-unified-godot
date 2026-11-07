extends SceneTree
## Playtest 2026-10-17 reports11:02:43 (old orc speaking to Luther) and11:03:19 (lava chamber). Production Cave host,
## actual region walk (physics frames), E and left click; SUPPLIED: player positions and camera aim.
const Orc := preload("res://scripts/lol2/cave_old_orc.gd")
const FOOT := preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL cave_old_orc_lava: ", message); quit(1); return false
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture"); root.get_texture().get_image().save_png("user://capture/"+name+".png")
func key_e() -> void:
	var e:=InputEventKey.new(); e.keycode=KEY_E; e.pressed=true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
func click() -> void:
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	if scene.roach!=null: scene.roach.model.strike_remaining=0.0
func stand(x: float, h: float, y: float) -> void:
	scene.player.global_position=Vector3(x,h,y)+scene.native_translation+Vector3.UP*FOOT; scene.player.velocity=Vector3.ZERO
	for i in 3: await physics_frame
func face_orc(distance: float) -> void:
	var orc=scene.old_orc
	var a: Vector3=orc.anchor()
	# Source op18 viewpoint (1396,-12236) side of the orc.
	var from:=Vector3(1396,0,-12236)+Vector3(scene.native_translation.x,0,scene.native_translation.z)
	var flat:=Vector3(from.x-a.x,0,from.z-a.z).normalized()
	await stand(a.x-scene.native_translation.x+flat.x*distance,-215,a.z-scene.native_translation.z+flat.z*distance)
	scene.player.look_at(Vector3(a.x,scene.player.global_position.y,a.z)); scene.camera.rotation=Vector3.ZERO
	scene.camera.look_at(a+Vector3.UP*float(orc.source.dimensions[1])*0.4)
func seconds(t: float) -> void:
	var orc=scene.old_orc
	var left:=t
	while left>0:
		var d:=minf(0.25,left); orc.apply(Orc.tick(orc.state,orc.source,d)); left-=d
	await process_frame
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene=scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false); scene.curse.set_physics_process(false)
	# --- Lava flames: 48 ambient props, three sizes, animated.
	var lava=scene.lava_flames
	if lava==null or lava.sprites.size()!=48: return fail("Lava flames not hosted")
	var sizes:={}
	for id in lava.sprites: sizes[(lava.sprites[id].mesh as QuadMesh).size]=true
	if sizes.size()!=3 or not sizes.has(Vector2(88,250)) or not sizes.has(Vector2(40,150)) or not sizes.has(Vector2(20,75)): return fail("Flame sizes %s" % [sizes.keys()])
	var f0: int=lava.frame_of("281")
	lava._process(0.11)
	if lava.frame_of("281")==f0: return fail("Flames do not animate")
	if lava.frame_of("299")!=(11+int(lava.clock*10.0))%7: return fail("Placement phase not applied")
	scene.player.global_position=Vector3(584.98+4,-232.96+430,-12848.32+12794); scene.player.rotation=Vector3(0,0.884,0); scene.camera.rotation=Vector3(-0.242,0,0)
	await capture("owner_1103_19_flames")
	# --- Old orc: nothing shown before the source entry regions.
	var orc=scene.old_orc
	if orc==null: return fail("Old orc not hosted")
	if Orc.shown(orc.state) or orc.picture.visible: return fail("Orc shown before region entry")
	await face_orc(90.0)
	await key_e()
	if int(orc.state.state)!=0: return fail("E before the clip is loaded changed state")
	# Walk 811 -> 838 (clear) -> 1859 (load: loop0 repeating).
	await stand(1000,-215,-11880)
	if Orc.shown(orc.state): return fail("Region838 loaded the clip")
	await stand(1040,-215,-11930)
	if not orc.state.inside["1859"] or int(orc.state.clip.segment)!=0 or not orc.state.clip.repeat: return fail("Region1859 entry did not loop Loiter: %s" % [orc.state.clip])
	# Owner pose 11:02:43 now shows the orc.
	scene.player.global_position=Vector3(1353.87+4,-182.95+430,-12229.30+12794); scene.player.rotation=Vector3(0,-1.303,0); scene.camera.rotation=Vector3(-0.023,0,0)
	for i in 3: await physics_frame
	orc.present()
	if not orc.picture.visible: return fail("Orc not visible from the owner pose")
	await capture("owner_1102_43_orc")
	# Looking away: E refused.
	await face_orc(90.0)
	scene.camera.rotation=Vector3(0,PI,0)
	await key_e()
	if int(orc.state.state)!=0: return fail("E while looking away talked")
	# First talk: viewpoint, segment1 once, lock.
	await face_orc(90.0)
	if not orc.aimed(): return fail("Orc not aimed from the viewpoint side")
	await key_e()
	if int(orc.state.state)!=1 or int(orc.state.clip.segment)!=1 or orc.state.clip.repeat or not orc.locked() or int(orc.state.local51)!=1: return fail("First talk wrong: %s" % [orc.state])
	if not orc.effects.any(func(e): return str(e.type)=="view"): return fail("No op18 viewpoint")
	var view: Vector3=scene.player.global_position-scene.native_translation
	if Vector2(view.x,view.z).distance_to(Vector2(1396,-12236))>1.0: return fail("Viewpoint not applied: %s" % view)
	if not orc.voice.playing: return fail("Voice not playing")
	await capture("talk1")
	# Mid-talk save round trip (JSON) and host save validation.
	await seconds(5.0)
	var path:="user://old_orc_mid_talk.json"
	var saved: Dictionary=orc.checkpoint()
	var write_error: String=scene._quicksave_unrecorded(path)
	if not write_error.is_empty(): return fail("Host save mid-talk: %s" % write_error)
	await seconds(3.0)
	var load_error: String=scene._quickload_unrecorded(path)
	if not load_error.is_empty(): return fail("Host load mid-talk: %s" % load_error)
	for i in 2: await process_frame
	# Physics frames keep the clip clock running after the load; it must restart from the saved time, not 8 s.
	if int(orc.state.clip.segment)!=1 or int(orc.state.state)!=1 or not orc.locked() or absf(float(orc.state.clip.elapsed)-float(saved.clip.elapsed))>0.25: return fail("Host load did not restore the talk: %s vs %s" % [orc.state.clip, saved.clip])
	if not orc.voice.playing: return fail("Restore lost the voice")
	# Segment1 end (frames 20..278 = 259/15 s) -> kind6 state1 -> Loiter loop2, released.
	await seconds(259.0/15.0)
	if int(orc.state.state)!=2 or int(orc.state.clip.segment)!=2 or not orc.state.clip.repeat or orc.locked(): return fail("Segment1 end wrong: %s" % [orc.state])
	# Second talk -> segment3 -> loop4.
	await face_orc(90.0)
	await key_e()
	if int(orc.state.state)!=3 or int(orc.state.clip.segment)!=3: return fail("Second talk wrong: %s" % [orc.state])
	await seconds(451.0/15.0+0.1)
	if int(orc.state.state)!=4 or int(orc.state.clip.segment)!=4: return fail("Segment3 end wrong: %s" % [orc.state])
	# A hit (idle, local51==0: g11068) jumps to the last line, one-shot.
	var weapon=preload("res://scripts/lol2/cave_stalagmite.gd")
	scene.stalagmites.restore([weapon.item_id(641,1)])
	if not scene.set_equipped_item(weapon.item_id(641,1)): return fail("Weapon fixture")
	await face_orc(70.0)
	await click()
	if int(orc.state.state)!=7 or int(orc.state.clip.segment)!=5 or int(orc.state.local3)!=1 or not 11068 in orc.state.spent: return fail("Hit did not run g11068: %s" % [orc.state])
	await capture("hit_last_line")
	var before: Dictionary=orc.checkpoint()
	await click()
	if orc.checkpoint().spent!=before.spent: return fail("Second hit ran another record")
	# Last line end: local3==1 -> clear (gone).
	await seconds(68.0/15.0+0.1)
	if Orc.shown(orc.state) or int(orc.state.state)!=7: return fail("Final clip not cleared: %s" % [orc.state])
	orc.present()
	if orc.picture.visible: return fail("Orc still drawn after the scene")
	# Re-entry: predicate16 (local3==0) keeps it gone.
	await stand(1000,-215,-11880); await stand(1040,-215,-11930)
	if Orc.shown(orc.state): return fail("Region re-entry reloaded a finished scene")
	# Invalid saves refused.
	var bad: Dictionary=orc.checkpoint().duplicate(true); bad.state=5
	if Orc.validate(bad,orc.source).is_empty(): return fail("State5 accepted")
	bad=orc.checkpoint().duplicate(true); bad.clip.elapsed=NAN
	if Orc.validate(bad,orc.source).is_empty(): return fail("NaN clock accepted")
	bad=orc.checkpoint().duplicate(true); bad.spent=[1]
	if Orc.validate(bad,orc.source).is_empty(): return fail("Foreign spent record accepted")
	var full: Dictionary=scene._save_state(); full.cave_old_orc=orc.checkpoint().duplicate(true); full.cave_old_orc.erase("timer")
	if preload("res://scripts/lol2/walkthrough_save.gd").validate(full,scene._checkpoint_count()).is_empty(): return fail("Host save accepted a broken orc packet")
	full.cave_old_orc=orc.checkpoint()
	var ok: String=preload("res://scripts/lol2/walkthrough_save.gd").validate(full,scene._checkpoint_count())
	if not ok.is_empty(): return fail("Host save refused a good orc packet: %s" % ok)
	print("PASS cave_old_orc_lava: 48 flames (3 sizes, phased), orc regions/E/view/talk1-3/hit/clear, save and refusals")
	quit(0)
