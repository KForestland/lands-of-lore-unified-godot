extends SceneTree
## Continuous earned village-escape route (rendered; Codex acceptance gate). Input: the r12f standard-campaign save
## act1_broken_runes_monastery_return.json (sha256 af23a676c298df24e71aa129625eda0a302fd8faee6952b977672d8a9dae847d,
## AI_COMMS/act1_completion_20261017/r12f_qualification/campaign/userdata/), passed as LOL2_VILLAGE_ESCAPE_SAVE (or
## --earned-save=PATH). It is copied into user://tests and never modified; its earned state is shared38=1 (village
## admission possible), GV_LUTHER_KNOWS_ABOUT_DANIEL 0, GV_HULINE_ALERT 0, the runes not yet translated (not needed for
## the gate), the Fine Longsword equipped, standing in the open MENT room at the monastery. No flag is reset or written.
## One uninterrupted run on that host; nothing is placed:
## - creatures: a hostile dinosaur within 95 is fought with captured clicks (camera aim, no state writes) and the walk
##   rejoins where the fight began; a non-engaging creature in the way is stepped around (no teleport, no despawn);
## - movement: the production grounded mover along blocker-avoiding fixtures (weapon_shop_walk.to_shop,
##   village_escape_route.json from tools/build_village_escape_route.py, hive_quest_walk_routes.tavern_to_monastery),
##   the campaign-walk convention; aim by camera look_at (the campaign convention for strikes);
## - room/shop buttons and hotspots by GUI mouse clicks pushed into their own viewport; Enter skips spoken lines and
##   Escape leaves rooms (production keys), starting with leaving MENT; the Confidante kill by a basic Spark (Q) from region3409;
##   Force gate by E.
## Steps: Escape out of MENT -> heal to full -> shop door -> WPNEXT Enter -> intro (GV_LUTHER_KNOWS_ABOUT_DANIEL) -> village gate admission -> inside ->
## barrel sight while control123 idles (native idle window, region3408 not entered) -> Spark kill from region3409 (Killed_Confidante)
## -> tavern (the earned input has the farewell and departure) -> CAN_MAID (GV_HULINE_ALERT, return
## point) -> the alarm closes the gate on its own timer -> run to leaf78 -> Force gate (owner-approved modern binding,
## 2026-10-25) -> walk through the gap (save kept: user://tests/village_escape_gap.json) -> the monastery entrance (MENT),
## passing source relink region3896, which restores both leaves. The final save is written to
## user://tests/village_escape_final.json and kept for the separate-process jungle_village_escape_reload_test.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const FINAL:="user://tests/village_escape_final.json"
const GAP:="user://tests/village_escape_gap.json"
const INPUT_SHA256:="af23a676c298df24e71aa129625eda0a302fd8faee6952b977672d8a9dae847d"
var scene
var rooms
var failed:=false
var fixture: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func key(code: int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await process_frame
func click_control(c: Control) -> void:
	var at: Vector2=c.get_global_rect().get_center()
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=at;e.global_position=at
		c.get_viewport().push_input(e,true);await process_frame
func captured_click() -> void:
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;Input.parse_input_event(e);await process_frame
func step_toward(target: Vector2, sprint: bool=false) -> float:
	var off:=target-Vector2(scene.player.global_position.x,scene.player.global_position.z)
	var delta: float=scene.player.get_physics_process_delta_time()
	scene.move_grounded(Vector3(off.x,0,off.y).normalized()*minf(1,off.length()/(80*delta)),delta,sprint)
	await physics_frame
	return off.length()
## ---- creatures on the way (the Dark Halls detour driver's fight step plus d178a7c's rejoin) ---------------------
## Hostile = a living Jungle dinosaur within the radius, at about the same height, not idle beyond 70 units.
func threat(radius: float) -> String:
	var pop=scene.get("dino_population")
	if pop==null or not is_instance_valid(pop): return ""
	var best:="";var best_d:=radius;var me: Vector3=scene.player.global_position
	for id in pop.bodies:
		if int(pop.view().actors[id].health)<=0: continue
		var s: Vector3=pop.bodies[id].global_position-me
		if absf(s.y)>90: continue
		var d:=Vector2(s.x,s.z).length()
		if int(pop.view().live[id].mode)==preload("res://scripts/lol2/creature_live_rules.gd").IDLE and d>70: continue
		if d<best_d: best_d=d;best=id
	return best
## Fight the nearest engaged dinosaur until none is within the radius: camera aim at its body, step in while beyond 70,
## captured left click (the population's own strike input) when its strike ray is on it. No state writes.
func fight(radius: float, tag: String) -> bool:
	var pop=scene.dino_population
	for frame in 60*120:
		var id:=threat(radius)
		if id.is_empty(): return true
		if not check(scene.starting_magic.health()>0,"Player fell fighting dinosaur %s at %s"%[id,tag]): return false
		if scene.starting_magic.health()<=12 and int(scene.starting_magic.magic_state().player.mana)>=2:
			print("fight %s: health %d, healing"%[tag,scene.starting_magic.health()])
			await heal_up(24,tag+"/fight")
		var body: Node3D=pop.bodies[id]
		scene.camera.look_at(body.global_position+Vector3.UP*20.0)
		var s: Vector3=body.global_position-scene.player.global_position
		var d:=Vector2(s.x,s.z).length()
		var delta: float=scene.player.get_physics_process_delta_time()
		scene.move_grounded(Vector3(s.x,0,s.z).normalized() if d>70.0 else Vector3.ZERO,delta)
		await physics_frame
		if pop.aimed()==id and float(pop.strike_remaining)<=0.0: await captured_click()
	return check(false,"Fight did not end at %s"%tag)
## Healing spell by keys (2 selects it, Q casts, 1 returns to Spark) until the target health or no mana is left.
func heal_up(target: int, tag: String) -> bool:
	var magic=scene.starting_magic
	await key(KEY_2)
	for i in 12:
		if magic.health()>=target or int(magic.magic_state().player.mana)<2: break
		var before: int=magic.health()
		await key(KEY_Q)
		for f in 36: await physics_frame
		print("heal %s: %d -> %d (mana %d)"%[tag,before,magic.health(),int(magic.magic_state().player.mana)])
	await key(KEY_1)
	return check(magic.health()>=mini(target,30) or int(magic.magic_state().player.mana)<2,"Healing at %s stopped at %d"%[tag,magic.health()])
## A creature that stands in the way without engaging (idle or wandering): is one within reach of the walker?
func creature_near(radius: float) -> bool:
	var me: Vector3=scene.player.global_position
	for owner_name in ["dino_population","villager_population"]:
		var pop=scene.get(owner_name)
		if pop==null or not is_instance_valid(pop) or pop.get("bodies")==null: continue
		for id in pop.bodies:
			var b=pop.bodies[id]
			if is_instance_valid(b) and b.collision_layer!=0 and Vector2(b.global_position.x-me.x,b.global_position.z-me.z).length()<radius: return true
	return false
## Walk a point list; stops early (true) when stop_when returns true. A hostile creature within 95 is fought, then the
## walk rejoins where the fight began before going on (d178a7c). A stall beside a non-engaging creature steps around it
## (sideways, alternating) and, after three tries, re-paths to the next point. Fails on any other stall, a reset or death.
func walk(points: Array, tag: String, stop_when: Callable=func(): return false, sprint: bool=false) -> bool:
	if not tag.ends_with("/rejoin"): print("ROUTE segment %s: %d points from %s health %d"%[tag,points.size(),scene.player.position,scene.starting_magic.health()])
	var i:=0
	while i<points.size():
		var target:=Vector2(points[i][0],points[i][1]);var best:=INF;var since:=0;var sidesteps:=0
		while true:
			if stop_when.call(): return true
			if not threat(95.0).is_empty():
				var left:=Vector2(scene.player.global_position.x,scene.player.global_position.z)
				if not await fight(160.0,"%s point %d"%[tag,i]): return false
				if Vector2(scene.player.global_position.x,scene.player.global_position.z).distance_to(left)>8.0:
					if not await walk([[left.x,left.y]],tag+"/rejoin",stop_when,sprint): return false
				best=INF;since=0
				continue
			var d:=await step_toward(target,sprint)
			if d<4: break
			if d<best-0.5: best=d;since=0
			else: since+=1
			if since>=120 and creature_near(70.0) and sidesteps<3:
				var off:=target-Vector2(scene.player.global_position.x,scene.player.global_position.z)
				var side:=Vector3(-off.y,0,off.x).normalized()*(1.0 if sidesteps%2==0 else -1.0)
				for f in 40:
					scene.move_grounded(side,scene.player.get_physics_process_delta_time())
					await physics_frame
				sidesteps+=1;best=INF;since=0
				continue
			if since>=120 and creature_near(70.0) and i+1<points.size():
				print("re-path past a creature: %s point %d -> %d"%[tag,i,i+1])
				break
			if not check(since<300 and scene.resets==0 and scene.starting_magic.health()>0,"%s stuck/reset/dead before point %d at %s (health %d)"%[tag,i,scene.player.position,scene.starting_magic.health()]): return false
		i+=1
	if not tag.ends_with("/rejoin"): print("ROUTE segment %s done at %s health %d"%[tag,scene.player.position,scene.starting_magic.health()])
	return true
func from_nearest(points: Array, at: Vector2) -> Array:
	var best:=0
	for i in points.size():
		if Vector2(points[i][0],points[i][1]).distance_to(at)<Vector2(points[best][0],points[best][1]).distance_to(at): best=i
	return points.slice(best)
func skip_speech(owner_active: Callable, limit: int=600) -> void:
	for i in limit:
		if not owner_active.call(): return
		await key(KEY_ENTER)
		for f in 10: await process_frame
func run() -> void:
	var earned_source:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--earned-save="): earned_source=arg.trim_prefix("--earned-save=")
	if earned_source.is_empty(): earned_source=OS.get_environment("LOL2_VILLAGE_ESCAPE_SAVE") # run_regressions passes no user args
	if not check(not earned_source.is_empty() and FileAccess.file_exists(earned_source),"Requires LOL2_VILLAGE_ESCAPE_SAVE or --earned-save=PATH (r12f act1_broken_runes_monastery_return.json)"): return
	if not check(FileAccess.get_sha256(earned_source)==INPUT_SHA256,"Earned input is not the pinned r12f save (sha256 %s)"%FileAccess.get_sha256(earned_source)): return
	DirAccess.make_dir_recursive_absolute("user://tests")
	var earned:="user://tests/village_escape_route_input.json"
	var f:=FileAccess.open(earned,FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string(earned_source));f.close()
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.quickload(earned).is_empty(),"Earned save rejected"): return
	scene.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	rooms=scene.monastery
	fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/village_escape_route.json")).routes
	var globals: Dictionary=scene.quest_state.monastery.globals
	if not check(rooms.active() and rooms.state().room=="MENT" and int(scene.quest_state.get("shared_flag_38",0))==1 and int(globals.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0))==0 and int(scene.village_gate.state().shared29)==0 and not scene.confidante.killed(),"Input is not the expected r12f MENT save (room '%s')"%rooms.state().room): return
	# Leave MENT with production keys: finish any room speech with Enter, then Escape.
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await skip_speech(func(): return preload("res://scripts/lol2/monastery_conversation.gd").active(rooms.state().conversation))
	for i in 4:
		if not rooms.active(): break
		await key(KEY_ESCAPE)
		await skip_speech(func(): return preload("res://scripts/lol2/monastery_conversation.gd").active(rooms.state().conversation))
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(not rooms.active(),"Escape did not leave MENT"): return
	for i in 30: await physics_frame
	# The earned input stands at health 5 of 30 (mana 109): heal to full with the Healing spell first (2, then Q per cast,
	# +6 for 2 mana, 0.5 s cooldown), as a player would before crossing the Jungle; Spark (1) is reselected after.
	if not await heal_up(30,"start"): return
	# ---- Weapon shop intro ----------------------------------------------------------------------------------------
	var shop=scene.weapon_shop
	var to_shop: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/weapon_shop_walk.json")).to_shop.points
	if not check(await walk(from_nearest(to_shop,Vector2(scene.player.position.x,scene.player.position.z)),"to_shop",func(): return shop.active()),"Walk to the shop"): return
	for i in 120:
		if shop.active(): break
		await physics_frame
	if not check(shop.active() and shop.actions.has("enter"),"Shop door contact did not open WPNEXT"): return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await click_control(shop.actions["enter"])
	await skip_speech(func(): return shop.State.active(shop.state()))
	if not check(int(globals.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0))==1,"Shop intro did not earn Daniel knowledge"): return
	print("ROUTE milestone: Daniel knowledge earned")
	for i in 4:
		if not shop.active(): break
		await key(KEY_ESCAPE)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(not shop.active(),"Escape did not leave the shop"): return
	# ---- Village gate admission (gate villager speech plays through) ----------------------------------------------
	if not check(await walk(fixture.shop_to_gate.points,"shop_to_gate"),"Walk to the gate"): return
	for i in 60*240:
		if int(scene.village_gate.pose)>=100: break
		await skip_speech(func(): return is_instance_valid(scene.village_dialogue) and scene.village_dialogue.active(),20)
		await physics_frame
	if not check(int(scene.village_gate.pose)>=100,"Village gate did not open"): return
	print("ROUTE milestone: village gate open")
	if not check(await walk(fixture.gate_to_inside.points,"gate_to_inside"),"Walk inside"): return
	# ---- Confidante: barrel sight, idle window, click kill --------------------------------------------------------
	var k=scene.confidante
	if not check(await walk(fixture.inside_to_confidante.points,"inside_to_confidante"),"Walk to the Confidante"): return
	var barrel: Array=k.src.props["1465"].position
	scene.camera.look_at(Vector3(barrel[0],barrel[1]+40,barrel[2])+k.origin())
	for i in 30: await physics_frame
	if not check(int(k.state.controls["123"].segment)==3 and k.speaking()=="","Barrel sight did not start the idle (no meeting)"): return
	print("ROUTE milestone: Confidante idling after barrel sight")
	var at: Array=k.src.locations["123"].control.position
	scene.camera.look_at(Vector3(at[0],at[1]+18,at[2])+k.origin())
	var soul0: int=preload("res://scripts/lol2/shared_global_defaults.gd").read(globals,"GV_LUTHERS_SOUL")
	# From region3409 (route end) the Confidante is 163 units away, beyond melee reach; region3408 would start the
	# meeting. The idle-window kill is a basic Spark (Q), retried after its 0.5 s cooldown.
	for attempt in 8:
		if k.killed(): break
		scene.camera.look_at(Vector3(at[0],at[1]+18,at[2])+k.origin())
		await key(KEY_Q)
		for i in 40: await physics_frame
	if not check(k.killed() and preload("res://scripts/lol2/shared_global_defaults.gd").read(globals,"GV_LUTHERS_SOUL")==soul0-1,"Spark did not kill the Confidante"): return
	print("ROUTE milestone: Confidante killed (Killed_Confidante 1)")
	# ---- Tavern: the earned input already has the first visit, the farewell (flag34 1) and the departure through the
	# gate passage (Left_Village 3); the return entry (Bacatta57 sealing) opens VILLAGE and the CAN hotspot the maid.
	if not check(int(rooms.state().flags["34"])==1 and int(rooms.state().locals.Left_Village)==3,"Earned input lacks the farewell/departure"): return
	if not check(await walk(fixture.confidante_to_tavern.points,"confidante_to_tavern",func(): return rooms.active()),"Walk to the tavern"): return
	for i in 120:
		if rooms.active(): break
		await physics_frame
	if not check(rooms.active() and rooms.state().room=="VILLAGE","Tavern contact did not open VILLAGE"): return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var can: Control=rooms.hotspots.filter(func(h): return h.get_meta("room")=="VILLAGE" and h.position==Vector2(244,220))[0]
	await skip_speech(func(): return preload("res://scripts/lol2/monastery_conversation.gd").active(rooms.state().conversation))
	await click_control(can)
	if not check(rooms.state().room=="CAN" and rooms.state().conversation.sequence=="CAN_MAID","Maid sequence did not start"): return
	await skip_speech(func(): return rooms.state().room=="CAN")
	for i in 4:
		if not rooms.active(): break
		await key(KEY_ESCAPE)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(int(scene.village_gate.state().shared29)==1 and not rooms.active(),"Betrayal did not raise the alert"): return
	print("ROUTE milestone: Huline alert raised")
	# ---- The alarm closes the gate on its own timer; run to leaf78 ------------------------------------------------
	for i in 60*20:
		if scene.village_alarm.movable_target(78)==0 and int(scene.village_gate.pose)==0: break
		await physics_frame
	if not check(int(scene.village_gate.pose)==0,"Alarm did not close the gate"): return
	print("ROUTE milestone: alarm closed the gate, health %d"%scene.starting_magic.health())
	if not check(await walk(fixture.return_to_leaf.points,"return_to_leaf",func(): return false,true),"Run to the gate"): return
	scene.camera.look_at(Vector3(-1378,40,-5300)+k.origin());await physics_frame
	if not check(scene.gate_leaves.interaction_hint().begins_with("E — Force gate"),"Force gate not offered: '%s'"%scene.gate_leaves.interaction_hint()): return
	await key(KEY_E)
	if not check(scene.village_gate.leaf_removed(78),"Force gate did not break leaf78"): return
	print("ROUTE milestone: Force gate broke leaf78")
	var outside: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/village_escape_route.json")).points
	if not check(await walk([[-1300,-5300],outside.outside],"gap",func(): return false,true),"Walk through the gap"): return
	# Kept for the new-process reload: the broken leaf before any source relink region (588/3895/3896/3897).
	if not check(scene.quicksave(GAP).is_empty() and scene.village_gate.leaf_removed(78),"Gap save rejected"): return
	print("ROUTE milestone: gap save kept at ",GAP)
	# ---- To the monastery entrance --------------------------------------------------------------------------------
	# Continue from the route's first point outside the gate (admission region2443), not the nearest one: that is the
	# passage point (-1376,-5249) between the leaves, where unbroken leaf79's edge stands.
	var monastery_route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_quest_walk_routes.json")).tavern_to_monastery
	var outside_index: int=monastery_route.regions.map(func(r): return int(r)).find(2443)
	if not check(outside_index>=0,"Monastery route has no region2443 point"): return
	if not check(await walk(monastery_route.points.slice(outside_index),"to_monastery",func(): return rooms.active(),true),"Walk to the monastery"): return
	for i in 120:
		if rooms.active(): break
		await physics_frame
	if not check(rooms.active() and rooms.state().room=="MENT","Did not reach MENT: '%s'"%rooms.state().room): return
	# tavern_to_monastery crosses source relink region3896 (index 41): entering it relinks both leaves (kept per Codex).
	if not check(not scene.village_gate.leaf_removed(78) and not scene.gate_leaves.panels["81"].visible and 3896 not in scene.gate_leaves.inside,"Relink region3896 did not reset the gate on the way to MENT"): return
	print("ROUTE milestone: source region3896 relinked the leaves on the way to MENT")
	if not check(scene.quicksave(FINAL).is_empty(),"Final save rejected"): return
	DirAccess.remove_absolute(earned)
	print("PASS jungle_village_escape_route_test: continuous earned run from MENT: heal by keys, shop Daniel intro, gate admission, barrel sight idle window, Spark kill from region3409, maid alert, timed alarm, Force gate (owner-approved modern binding), gap (save kept at ",GAP,"), region3896 relink, MENT; final save kept at ",FINAL)
	quit()
