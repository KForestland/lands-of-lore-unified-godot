extends SceneTree
## PT3-JUNGLE-PASSWORD-GUY (owner F10 2026-11-03 17:33:29 / 17:34:59 / 17:35:21; rendered, real Jungle host).
## The owner stood in region3408 (where the first Confidante meeting starts) and nobody came, so the den door had no
## password. His saves never entered Kit'yara's shop: GV_LUTHER_KNOWS_ABOUT_DANIEL is unset, and the original gate (barrel
## sight p96 and region3408 p198: Daniel known OR Kit'yara dead) keeps the Confidante away. That is native; the hintbook
## (Prima ch. 6) sends the player to the Armorer's Glen before the Hive. This test proves the route works from his state:
## for each input save (the owner's jungle_quicksave copy, LOL2_OWNER_JUNGLE_SAVE, and a pre-shop campaign save,
## LOL2_VILLAGE_ESCAPE_SAVE; either may be missing, one is required):
##  1. Repro: Daniel unknown, the barrel comes into view and region3408 is entered: no Confidante, no hold, and My
##     Journal records no_confidante_yet whose text now names the armorer's glen.
##  2. Kit'yara's shop through the production entrance contact and her intro: Daniel known.
##  3. Back at the alley: the barrel sight edge shows control123 idling (drawn, voice playing); region3408 holds Luther
##     and the conversation plays with its original voice; Met_Confidant=1 and Luther is released.
##  4. The den reads the password (thieves_den_rooms.context().met_confidant), the journal gets the den-yard note, and a
##     disk save/load keeps Met_Confidant.
## Supplied approach positions and the direct shop calls of jungle_village_escape_earned_test; the clocks are real.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const MyJournal=preload("res://scripts/lol2/my_journal.gd")
const APPROACH:=Vector2(-1269.5,-4390.5)
var scene
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error("FAIL: "+msg);quit(1)
	return ok
func boot() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func place(at: Vector2) -> void:
	var top:=Vector3(at.x,200,at.y)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	scene.player.global_position=Vector3(at.x,(hit.position.y if not hit.is_empty() else 0.0)+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y)
	scene.player.velocity=Vector3.ZERO
	await physics_frame
func live(seconds: float) -> void:
	for i in int(ceil(seconds*60.0)): await physics_frame
func centre(region_id: int) -> Vector2:
	var r: Dictionary=scene.confidante.src.regions.filter(func(x): return int(x.id)==region_id)[0]
	var v:=Vector2.ZERO
	for p in r.polygon: v+=Vector2(p[0],p[1])
	return v/float(r.polygon.size())
func daniel() -> int:
	var shop: Dictionary=scene.quest_state.get("weapon_shop",{}).get("globals",{})
	return maxi(int(scene.quest_state.monastery.globals.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0)),int(shop.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0)))
## Look away (a sight edge needs out-of-view first), then at barrel prop1465.
func sight_barrel() -> void:
	var barrel: Array=scene.confidante.src.props["1465"].position
	await place(APPROACH);scene.camera.look_at(Vector3(APPROACH.x,40,APPROACH.y-300));await physics_frame
	await live(0.1)
	scene.camera.look_at(Vector3(barrel[0],barrel[1]+40,barrel[2]));await physics_frame
	await live(0.2)

func route(label: String, source: String) -> bool:
	var path:="user://tests/confidante_route_%s.json"%label
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string(source));f.close()
	var error: String=scene.quickload(path)
	if not check(error.is_empty(),"%s: save rejected: %s"%[label,error]): return false
	while scene.monastery.active(): scene.monastery.leave_room();scene.monastery.advance(1000.0)
	var c=scene.confidante
	if not check(daniel()==0 and int(c.state.locals["20"])==0 and int(c.state.locals["27"])==0 and not c.killed(),"%s: input is not a pre-shop, pre-meeting save"%label): return false
	# 1. The owner's report: no Confidante without Daniel knowledge.
	await sight_barrel()
	if not check(not c.state.controls["123"].present and not c.meshes["123"].visible,"%s: control123 shown without Daniel knowledge"%label): return false
	await place(centre(3408));await live(0.3)
	if not check(c.speaking()=="" and not scene.actor_input_locked(),"%s: region3408 held Luther without a speaker"%label): return false
	if not check("no_confidante_yet" in MyJournal.notes(scene),"%s: region3408 did not record no_confidante_yet"%label): return false
	if not check("armorer" in str(MyJournal.hints().no_confidante_yet),"%s: the note does not name the armorer: %s"%[label,MyJournal.hints().no_confidante_yet]): return false
	# 2. Kit'yara's shop (production entrance contact and intro).
	var shop=scene.weapon_shop
	var entrance: Array=shop.data.entrances[0];var mid:=Vector2.ZERO
	for p in entrance: mid+=Vector2(p[0],p[1])
	mid/=float(entrance.size())
	scene.player.position=Vector3(mid.x,32,mid.y);shop.was_inside=false;shop._process(0.016)
	if not check(shop.active() and shop.interact("enter"),"%s: shop entry failed"%label): return false
	for i in 4000:
		shop.advance(0.1)
		if not shop.State.active(shop.state()): break
	shop.leave_room();shop.leave_room()
	if not check(daniel()==1 and not shop.active(),"%s: shop intro did not earn Daniel knowledge"%label): return false
	# 3. The meeting.
	await sight_barrel()
	if not check(c.state.controls["123"].present and int(c.state.controls["123"].segment)==3 and c.meshes["123"].visible,"%s: barrel sight did not show control123 idling"%label): return false
	if not check(c.voices["123"].playing and c.voices["123"].stream!=null and c.voices["123"].stream.get_length()>1.0,"%s: idle control123 has no voice playing"%label): return false
	await place(centre(3408));await live(0.2)
	if not check(c.speaking()=="123" and scene.actor_input_locked() and int(c.state.locals["20"])==1,"%s: region3408 did not start the meeting"%label): return false
	var spoke:=false
	for i in 60*90:
		await physics_frame
		if int(c.state.controls["123"].segment)==0 and c.voices["123"].playing and not c.voices["123"].stream_paused: spoke=true
		if int(c.state.locals["27"])==1 and c.speaking()=="": break
	if not check(spoke,"%s: the conversation segment never played with its voice"%label): return false
	if not check(int(c.state.locals["27"])==1 and c.speaking()=="" and not scene.actor_input_locked(),"%s: meeting did not end with Met_Confidant (local27=%d, speaking '%s')"%[label,int(c.state.locals["27"]),c.speaking()]): return false
	# 4. The password reaches the den; save/load keeps it.
	if not check(bool(scene.thieves_den.context().met_confidant),"%s: the den does not read the password"%label): return false
	if not check("password_known_den_unfound" in MyJournal.notes(scene),"%s: no den-yard journal note"%label): return false
	var after:="user://tests/confidante_route_%s_after.json"%label
	if not check(scene.quicksave(after).is_empty() and scene.quickload(after).is_empty() and int(scene.confidante.state.locals["27"])==1 and bool(scene.thieves_den.context().met_confidant),"%s: save/load lost Met_Confidant"%label): return false
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(after)
	print("PASS route %s: no Confidante before Daniel knowledge (journal names the armorer), shop intro, barrel sight idle with voice, meeting with voice, Met_Confidant, den password, save/load"%label)
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	var inputs:={"owner":OS.get_environment("LOL2_OWNER_JUNGLE_SAVE"),"earned":OS.get_environment("LOL2_VILLAGE_ESCAPE_SAVE")}
	var used:=[]
	for k in inputs:
		if not str(inputs[k]).is_empty() and FileAccess.file_exists(inputs[k]): used.append(k)
	if not check(not used.is_empty(),"Needs LOL2_OWNER_JUNGLE_SAVE (owner jungle_quicksave copy) and/or LOL2_VILLAGE_ESCAPE_SAVE (pre-shop campaign save)"): return
	await boot()
	for k in used:
		if not await route(k,inputs[k]): return
	print("PASS jungle_confidante_owner_route_test: %s"%", ".join(used))
	quit()
