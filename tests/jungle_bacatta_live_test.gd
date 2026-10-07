extends SceneTree
## Live Bacatta branch on the real Jungle host and its real exit encounter (fixture, not an earned route):
## story flags are written into the host's named globals; region1921 links prop552 and
## actual camera/frustum/world-ray visibility admits the guards; the use is a real E key event through a real camera raycast at prop552.
const Controller=preload("res://scripts/lol2/jungle_bacatta.gd")
const State=preload("res://scripts/lol2/jungle_bacatta_state.gd")
const Save=preload("res://scripts/lol2/jungle_save.gd")
const FOOT:=32.0
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var on:=true
	func world_active() -> bool: return on
var scene
var ctrl
var exit
var spells
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func globals() -> Dictionary:
	if not scene.quest_state.has("monastery"): scene.quest_state.monastery={}
	if not scene.quest_state.monastery.has("globals"): scene.quest_state.monastery.globals={}
	return scene.quest_state.monastery.globals
func logged(type: String, key: String="", value: Variant=null) -> int:
	var n:=0
	for e in ctrl.effect_log:
		if e.type==type and (key=="" or e.get(key)==value): n+=1
	return n
func step_until(cond: Callable, seconds: float) -> bool:
	for i in range(roundi(seconds*30)):
		ctrl.advance(1.0/30.0)
		if i%30==0: await physics_frame
		if cond.call(): return true
	return false
func region_point(region: int) -> Vector3:
	for r in ctrl.src.regions:
		if int(r.region)!=region: continue
		var c:=Vector2.ZERO
		for v in r.polygon: c+=Vector2(v[0],v[1])
		c/=r.polygon.size()
		return Vector3(c.x,float(r.floor_min)+FOOT,c.y)+ctrl.origin()
	return Vector3.ZERO
## Fresh Bacatta packet, prop552 linked through region1921 and sighted by the production camera.
func linked_and_sighted() -> void:
	exit.restore(exit.initial())
	if not check(ctrl.restore(ctrl.initial()).is_empty(),"Initial restore failed"):return
	scene.player.global_position=region_point(1921);ctrl.advance(1.0/30.0)
	scene.player.global_position=Vector3(3300,0,-3700)+ctrl.origin();ctrl.advance(1.0/30.0)
	await face_prop()
	exit._visible_spawn();ctrl.advance(1.0/30.0)
## Stand in front of prop552 and look at it through the real camera.
func face_prop() -> void:
	var p: Vector3=ctrl.prop_body.global_position
	scene.player.global_position=p+Vector3(0,FOOT+10,70)
	await physics_frame
	scene.camera.look_at(p+Vector3.UP*45)
	await physics_frame
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	exit=scene.exit_encounter
	if not check(exit!=null,"Host has no exit encounter"):return
	exit.set_physics_process(false)
	for pop in [scene.villager_population,scene.dino_population]:
		if pop!=null: pop.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	spells=TestMagic.new();spells.host=scene;scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	var g:=globals();g.GV_RUNES_TRANSLATED=1;g.GV_MET_BACATTA=1;g.GV_BACATTA_RELATIONSHIP=1;g.GV_LUTHERS_SOUL=4;g.GV_DAWN_RELATIONSHIP=3
	ctrl=scene.bacatta
	var error: String=""
	if not check(is_instance_valid(ctrl),"Production Bacatta setup failed"):return
	ctrl.set_physics_process(false)
	if not check(not ctrl.state.prop552.present and not ctrl.population.bodies["61"].visible,"prop552/Bacatta present at load"):return
	# Knowledge earned at the weapon shop participates in the same source admission predicate.
	scene.quest_state.weapon_shop.globals["GV_LUTHER_KNOWS_ABOUT_DANIEL"]=1
	scene.player.global_position=region_point(1921);ctrl.advance(1.0/30.0)
	if not check(not ctrl.state.prop552.present and ctrl.context().shared["47"]==1,"Bacatta ignored shop Daniel knowledge"):return
	scene.quest_state.weapon_shop.globals["GV_LUTHER_KNOWS_ABOUT_DANIEL"]=0
	# Region1921 edge links prop552 (predicate119) and tells the exit its presence; the exit's kind5 starts the sleeping loop.
	await linked_and_sighted()
	if not check(ctrl.state.prop552.present and bool(exit.visibility.present) and ctrl.sighted and ctrl.state.prop552.clip.segment==4 and ctrl.meshes.prop552.visible,"Link/sighting differs"):return
	# Real E key through a real camera raycast.
	await face_prop()
	if not check(ctrl.can_use(),"prop552 not reachable/aimed"):return
	var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
	ctrl._unhandled_input(key)
	if not check(ctrl.state.prop552.state==1 and int(g.GV_LUTHERS_SOUL)==5 and int(g.GV_BACATTA_RELATIONSHIP)==2 and ctrl.state.locals["51"]==1,"Friendly use differs"):return
	var moved: Vector3=scene.player.global_position-ctrl.origin()
	if not check(absf(moved.x-3466)<1 and absf(moved.z+4182)<1,"Use reposition differs"):return
	ctrl._unhandled_input(key)
	if not check(int(g.GV_LUTHERS_SOUL)==5,"Repeated use re-applied shared writes"):return
	# Wake segment then the twelve selector clips; Bacatta replaces the prop.
	if not check(await step_until(func():return ctrl.state.bacatta.present,75.0),"Bacatta never appeared"):return
	if not check(not ctrl.state.prop552.present and not bool(exit.visibility.present) and ctrl.population.bodies["61"].visible and logged("clip","owner","prop552")==14,"Handover differs (sleep loop + wake segment + 12 selectors = 14 clip starts)"):return
	# Property22 escort: input locked, the player follows Bacatta along path1.
	if not check(await step_until(func():return ctrl.input_locked(),3.0),"Escort did not start"):return
	await step_until(func():return false,8.0)
	var gap: float=Vector2(scene.player.global_position.x,scene.player.global_position.z).distance_to(Vector2(ctrl.population.bodies["61"].global_position.x,ctrl.population.bodies["61"].global_position.z))
	if not check(gap<160.0 and ctrl.state.bacatta.walking,"Player did not follow the escort (gap %.1f)"%gap):return
	# Mid-voice disk rollback.
	if not check(await step_until(func():return not ctrl.state.sounds.is_empty(),20.0),"No escort sound started"):return
	var mid: Dictionary=ctrl.checkpoint()
	var path:="user://tests/jungle_bacatta_live.json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(mid,"  ",true,true));f.close()
	await step_until(func():return false,1.0)
	if not check(ctrl.restore(JSON.parse_string(FileAccess.get_file_as_string(path))).is_empty() and ctrl.checkpoint()==mid,"Mid-voice disk rollback differs"):return
	# Production host disk save and atomic quest validation during the escort.
	var host_path:="user://tests/jungle_bacatta_host.json"
	error=scene.quicksave(host_path)
	if not check(error.is_empty(),"Host mid-escort save failed: "+error):return
	var saved_host: Dictionary=Save.read_save(host_path)
	if not check(saved_host.error.is_empty(),"Host save read failed: "+str(saved_host.error)):return
	var saved_branch: Dictionary=saved_host.state.quests.jungle_bacatta.duplicate(true)
	saved_branch.version=1
	saved_branch.branch=State.canonical(saved_branch.branch)
	saved_branch.body=preload("res://scripts/lol2/scripted_creature_state.gd").canonical(saved_branch.body,ctrl.population.src)
	saved_branch.inside=saved_branch.inside.map(func(r):return int(r))
	await step_until(func():return false,0.5)
	error=scene.quickload(host_path)
	if not check(error.is_empty() and ctrl.checkpoint()==saved_branch and ctrl.input_locked(),"Host escort rollback failed: "+error):return
	g=globals()
	var malformed: Dictionary=saved_host.state.duplicate(true)
	malformed.quests.jungle_bacatta.inside=[1921.5]
	if not check(not scene.apply_save(malformed).is_empty() and ctrl.checkpoint()==saved_branch,"Host accepted fractional region or changed branch on rejection"):return
	if not check(not scene.open_inventory() and not scene.request_jump() and not spells.available() and not spells.cast() and not exit.population.strike(),"Escort host input lock failed"):return
	# World pause freezes the branch.
	spells.on=false;var frozen: Dictionary=ctrl.checkpoint();ctrl.advance(1.0)
	if not check(ctrl.checkpoint()==frozen,"Branch advanced while the world was inactive"):return
	spells.on=true
	# Path end (event22) releases the escort and starts guard60's clip on the exit's guard body.
	if not check(await step_until(func():return not ctrl.input_locked(),120.0),"Escort never released"):return
	if not check(ctrl.state.bacatta.state==10 and ctrl.state.guard60.clip.get("selector",-1)==8 and ctrl.meshes.guard60.visible,"Event22 choreography differs"):return
	# Choreography ends in one prop4398 event20 through the exit hook: the exit selects E068E and plays it.
	if not check(await step_until(func():return ctrl.state.ending_requested,60.0),"Ending never requested"):return
	if not check(str(exit.encounter.ending.get("movie",""))=="E068E.VQA" and int(exit.encounter.ending.predicate)==51 and exit.active(),"Exit did not play E068E: "+str(exit.encounter.ending)):return
	ctrl.advance(1.0)
	if not check(logged("exit_event20")==1,"Ending requested twice"):return
	exit.movie={"phase":"done","elapsed":0.0}
	# Hostile use (GV_BACATTA_RELATIONSHIP==0): exit local42 written, hostile Bacatta targetable, no escort.
	g.GV_BACATTA_RELATIONSHIP=0
	await linked_and_sighted()
	await face_prop()
	ctrl._unhandled_input(key)
	if not check(ctrl.state.prop552.state==41 and int(exit.encounter.locals["42"])==1,"Hostile use differs"):return
	if not check(await step_until(func():return ctrl.state.bacatta.present,20.0) and not ctrl.input_locked() and ctrl.targets().size()==1,"Hostile Bacatta differs"):return
	# Armed melee hit (kind9 mode4, one-shot): signed shared writes, selector14, hostile Bacatta.
	g.GV_BACATTA_RELATIONSHIP=1;g.GV_LUTHERS_SOUL=4;g.GV_DAWN_RELATIONSHIP=3
	await linked_and_sighted()
	await face_prop()
	if not check(ctrl.can_strike() and ctrl.strike() and ctrl.state.prop552.state==40 and int(g.GV_LUTHERS_SOUL)==3 and int(g.GV_DAWN_RELATIONSHIP)==2 and int(g.GV_BACATTA_RELATIONSHIP)==0,"Hit branch differs"):return
	if not check(not ctrl.can_strike() and not ctrl.strike(),"Hit latch did not hold"):return
	if not check(await step_until(func():return ctrl.state.bacatta.present,30.0) and ctrl.targets().size()==1,"Hit branch did not reach hostile Bacatta"):return
	# Source friendly writes saturate at the runtime-bound soul/relationship caps.
	g.GV_LUTHERS_SOUL=10;g.GV_BACATTA_RELATIONSHIP=2
	await linked_and_sighted();await face_prop()
	if not check(ctrl.use() and g.GV_LUTHERS_SOUL==10 and g.GV_BACATTA_RELATIONSHIP==2,"Friendly shared caps differ"):return
	# Malformed packets are rejected atomically.
	var before: Dictionary=ctrl.checkpoint()
	var bad: Dictionary=mid.duplicate(true);bad.body.actors["61"].present=not bool(bad.branch.bacatta.present)
	var bad2: Dictionary=mid.duplicate(true);bad2.inside=[4435]
	var bad3: Dictionary=mid.duplicate(true);bad3.branch.sounds[0].request=9999
	for packet in [bad,bad2,bad3,{"version":2}]:
		if not check(not ctrl.restore(packet).is_empty() and ctrl.checkpoint()==before,"Malformed packet changed state"):return
	# Older host saves have neither optional Jungle encounter; loading must clear later state.
	var legacy_host: Dictionary=saved_host.state.duplicate(true)
	legacy_host.quests.erase("jungle_bacatta")
	legacy_host.quests.erase("jungle_exit_encounter")
	if not check(scene.apply_save(legacy_host).is_empty() and not ctrl.input_locked() and not ctrl.state.prop552.present and not ctrl.state.bacatta.present and exit.targets().is_empty(),"Legacy host load retained branch state"):return
	DirAccess.remove_absolute(host_path)
	DirAccess.remove_absolute(path)
	print("PASS: Bacatta live on the real Jungle host + exit: region1921 link and prop_presence, exit kind5 sleeping loop, real-raycast E use (named globals +1 once, reposition), wake + 12 clips → Bacatta, property22 escort with following player, mid-voice disk rollback, world pause, event22 → guard60 clip on the exit body, one prop4398 request → exit E068E playing; hostile use (exit local42) and armed hit (signed globals, latch) → targetable hostile Bacatta; atomic malformed restore")
	quit()
