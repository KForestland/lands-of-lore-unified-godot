extends "res://tests/jungle_aloe_use_test.gd"
## Real Jungle host. Default: explicitly supplied translated-runes and met-Bacatta prerequisites.
## Optional --earned-save=PATH loads a real pre-shop translated-runes continuation.
## Both modes supply local approach positions; the shop meeting and intro are production:
## - shop entrance contact → Enter → original intro: GV_LUTHER_KNOWS_ABOUT_DANIEL and the earned Met_Kityara;
## - with Daniel known and no knife, the exit-guard arm (region4437 g17748) is refused through the real host context;
## - her presence/start regions → conversation hold → the source 19 s timer grants her knife once (definition29) and
##   local41; mid-conversation disk save/load restores exactly and never duplicates the grant;
## - the exit arm now admits (and the Bacatta context carries local41); the segment end releases Luther;
## - completed save/load and Jungle→Hive→Jungle area handoff keep the knife, local41 and her state; malformed packets
##   are rejected.
const ExitState=preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
var k
func place(at: Vector2, host=null) -> void:
	host=scene if host==null else host
	var top: Vector3=Vector3(at.x,300,at.y)+k.origin()
	var hit: Dictionary=host.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*800,1,[host.player.get_rid()]))
	var y: float=hit.position.y if not hit.is_empty() else 0.0
	host.player.global_position=Vector3(at.x+k.origin().x,y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y+k.origin().z)
	host.player.velocity=Vector3.ZERO
	await physics_frame
func centre(region_id: int) -> Vector2:
	var r: Dictionary=k.src.regions.filter(func(x): return int(x.id)==region_id)[0]
	var c:=Vector2.ZERO
	for v in r.polygon: c+=Vector2(v[0],v[1])
	return c/float(r.polygon.size())
func step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		k.advance(1.0/30.0)
		if i%30==0: await process_frame
func exit_arm(host) -> Array:
	var st: Dictionary=host.exit_encounter.checkpoint().duplicate(true)
	var probe: Dictionary=ExitState.initial(host.exit_encounter.src)
	return ExitState.enter_region(probe,host.exit_encounter.src,4437,host._exit_context()).filter(func(e): return e.type=="group").map(func(e): return int(e.group))
func link_region() -> int:
	for r in k.src.records:
		if str(r.owner_kind)=="region" and "091000000300" in r.commands and r.predicate!=null and int(r.predicate)==151 and int(r.owner) in [1255,1353,1354,1355,1356]: return int(r.owner)
	return -1

func run() -> void:
	var path:="user://tests/opus_kityara_live.json"
	var earned:="user://tests/opus_kityara_earned.json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	var earned_source:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--earned-save="): earned_source=arg.trim_prefix("--earned-save=")
	if not earned_source.is_empty():
		if not check(FileAccess.file_exists(earned_source),"Explicit earned campaign save missing"): return
		var f:=FileAccess.open(earned,FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string(earned_source));f.close()
	set_meta("lol2_jungle_handoff",{"collected":[],"equipped_item":"","equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	freeze(scene)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	k=scene.kityara
	if not check(k!=null and is_instance_valid(k),"Kityara owner missing"): return
	k.set_physics_process(false)
	if not earned_source.is_empty():
		var load_error: String=scene.quickload(earned)
		if not check(load_error.is_empty(),"Earned save rejected: "+load_error): return
	else:
		# Focused fixture only; the separate full campaign must earn both prerequisites.
		scene.quest_state.monastery.globals["GV_RUNES_TRANSLATED"]=1
		scene.quest_state.monastery.globals["GV_MET_BACATTA"]=1 # Exit-arm predicate138 also requires shared18.
	# The earned save was made inside the monastery rooms: leave them as the player would (Escape → leave_room).
	for i in 6000:
		if not scene.weapon_shop.other_room_active(): break
		for key in ["monastery","magic_shop"]:
			var room=scene.get(key)
			if is_instance_valid(room) and room.active():
				room.advance(0.1)
				room.leave_room()
		if i%200==0: await process_frame
	if not check(not scene.weapon_shop.other_room_active(),"Could not leave the saved monastery room"): return
	var globals: Dictionary=scene.quest_state.monastery.globals
	if not check(int(globals.get("GV_RUNES_TRANSLATED",0))==1 and scene._shop_local("Met_Kityara")==0 and int(globals.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0))==0,"Input is not the expected pre-shop state"): return
	# Unmet: no conversation can start (presence only).
	await place(centre(1257));k._regions()
	if not check(k.speaking()=="" and int(k.state.locals["21"])==0,"Unmet Kityara started a conversation"): return
	await place(centre(1174));k._regions() # leave her area again (unlink region)
	# Production shop entrance contact → Enter → original intro to its end.
	var shop=scene.weapon_shop
	var entrance: Array=shop.data.entrances[0];var c:=Vector2.ZERO
	for p in entrance: c+=Vector2(p[0],p[1])
	c/=float(entrance.size())
	scene.player.position=Vector3(c.x,32,c.y);shop.was_inside=false;shop._process(0.016)
	if not check(shop.active() and shop.state().room=="WPNEXT" and shop.interact("enter"),"Shop entry failed"): return
	for i in 4000:
		shop.advance(0.1)
		if not shop.State.active(shop.state()): break
	if not check(scene._shop_local("Met_Kityara")==1 and int(globals.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0))==1,"Shop intro did not earn the meeting/Daniel knowledge"): return
	shop.leave_room();shop.leave_room()
	if not check(not shop.active(),"Shop did not close"): return
	if not check(exit_arm(scene).is_empty(),"Exit arm must be refused with Daniel known and no knife"): return
	# Her presence region, then a start region (production region edges).
	var link:=link_region()
	if not check(link>0,"No p151 link region"): return
	await place(centre(link));k._regions()
	if not check(k.state.controls["0"].present,"Kityara not linked"): return
	await place(centre(1257));k._regions()
	if not check(k.speaking()=="0" and scene.actor_input_locked() and int(k.state.locals["21"])==1,"Conversation did not start"): return
	await step(10)
	if not check(scene.quicksave(path).is_empty(),"Mid-conversation save rejected"): return
	var saved: Dictionary=k.checkpoint()
	await step(12)
	if not check(scene.kityara.src.item.catalog_id in scene.carried_collected and scene._shop_local("kityara_gave_knife")==1,"Knife not granted by the 19 s timer"): return
	if not check(scene.quickload(path).is_empty() and k.checkpoint()==saved and scene.kityara.src.item.catalog_id not in scene.carried_collected and scene._shop_local("kityara_gave_knife")==0,"Mid-conversation rollback differs"): return
	await step(12)
	var copies: int=scene.carried_collected.count(scene.kityara.src.item.catalog_id)
	if not check(copies==1 and scene._shop_local("kityara_gave_knife")==1,"Knife after reload: %d copies"%copies): return
	if not check(exit_arm(scene)==[17748] and int(scene._bacatta_context().locals["41"])==1,"Exit arm/Bacatta context not restored by the knife"): return
	await step(14)
	if not check(k.speaking()=="" and not scene.actor_input_locked() and int(scene.quest_state.monastery.globals.get("GV_LUTHER_HAS_WARBLADE",0))==1,"Segment end did not release Luther: speaking=%s"%k.speaking()): return
	await step(40)
	if not check(scene.carried_collected.count(scene.kityara.src.item.catalog_id)==1,"Knife granted twice"): return
	# Equip the actual reward through the production inventory UI.
	if not check(scene.open_inventory(),"Blade inventory did not open"): return
	await process_frame
	var blade: String=scene.kityara.src.item.catalog_id
	var blade_index:=-1
	for i in scene.inventory.item_list.item_count:
		if str(scene.inventory.item_list.get_item_metadata(i))==blade: blade_index=i
	if not check(blade_index>=0,"Blade missing from inventory UI"): return
	scene.inventory.select_item(blade_index)
	if not check(not scene.inventory.equip_button.disabled,"Blade cannot be equipped"): return
	scene.inventory.equip_button.pressed.emit()
	if not check(scene.equipped_item==blade,"Inventory did not equip the blade"): return
	scene.inventory.close()
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	# Completed save/load, malformed packets.
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and scene.carried_collected.count(blade)==1 and scene.equipped_item==blade and int(k.state.locals["21"])==1,"Completed reload differs"): return
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var bad: Dictionary=disk.duplicate(true);bad.quests.jungle_kityara.state.controls["0"].segment=9
	if not check(not Save.validate(bad).is_empty(),"Bad clip segment accepted"): return
	bad=disk.duplicate(true);bad.quests.jungle_kityara.inside=[99999]
	if not check(not Save.validate(bad).is_empty(),"Bad region history accepted"): return
	# Area handoff Jungle → Hive → Jungle.
	var handoff: Dictionary=scene.area_handoff()
	await finish(scene)
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(hive);current_scene=hive
	await process_frame
	hive.item_effects.set_process(false);hive.set_physics_process(false)
	var hive_error: String=hive.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff,"",true,true)))
	if not check(hive_error.is_empty(),"Hive rejected Kityara state: "+hive_error): return
	var back: Dictionary=hive.area_handoff()
	await finish(hive)
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	freeze(scene);k=scene.kityara;k.set_physics_process(false)
	if not check(scene.apply_area_handoff(JSON.parse_string(JSON.stringify(back,"",true,true))).is_empty(),"Jungle rejected returning state"): return
	if not check(blade in scene.carried_collected and scene.equipped_item==blade and scene._shop_local("kityara_gave_knife")==1 and int(k.state.locals["21"])==1 and exit_arm(scene)==[17748],"Kityara state lost on travel"): return
	await finish(scene)
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(earned)
	print("PASS jungle_kityara_live_test: ","explicit earned save" if not earned_source.is_empty() else "supplied translated-runes/met-Bacatta fixture", " → production shop entry/intro → gated exit → regions/hold/knife once → rollback → release → inventory equip → saved Jungle/Hive/Jungle transport. Approach positions supplied; not a fresh campaign.")
	quit()
