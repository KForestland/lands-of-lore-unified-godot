extends SceneTree
## Live exit encounter consumer on the real Jungle host: source region edges, supplied spawn,
## original def9 guards on the generic owner, guard59/guard58 VQA pose clips holding opcode8,
## generic combat mirrored into source defeat, all three original ending movies, partial pose
## and movie playback through disk rollback, atomic malformed restore.
const Controller=preload("res://scripts/lol2/jungle_exit_encounter.gd")
const State=preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Save=preload("res://scripts/lol2/jungle_save.gd")
const FOOT:=32.0
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var on:=true
	func world_active() -> bool: return on
var flags:={"shared":{"13":0,"14":1,"18":1,"47":0},"locals":{"41":0,"49":0,"51":0}}
var handled: Array=[]
var scene
var ctrl
var melee_ok:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func logged(type: String, key: String="", value: Variant=null) -> int:
	var n:=0
	for e in ctrl.effect_log:
		if e.type==type and (key=="" or e.get(key)==value): n+=1
	return n
func step(seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		ctrl.advance(1.0/60.0)
		if i%15==0: await physics_frame
func region_point(region: int) -> Vector3:
	for r in ctrl.src.regions:
		if int(r.region)!=region: continue
		var c:=Vector2.ZERO
		for v in r.polygon: c+=Vector2(v[0],v[1])
		c/=r.polygon.size()
		return Vector3(c.x,float(r.floor_min)+FOOT,c.y)
	return Vector3.ZERO
func enter(region: int) -> void:
	scene.player.global_position=region_point(region)
	ctrl.advance(1.0/60.0)
	scene.player.global_position=Vector3(5300,-114+FOOT,-3300) # outside every exit polygon
	ctrl.advance(1.0/60.0)
func save_disk(packet: Dictionary, path: String) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(packet));f.close()
func load_disk(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func armed() -> Dictionary:
	# Arm through source regions + supplied spawn, then the guard59 cutscene to its end.
	ctrl.restore(ctrl.initial())
	for r in [4437,4435]: enter(r)
	ctrl.spawn_guards()
	for r in [4439,4442]: enter(r)
	return ctrl.checkpoint()
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	scene.exit_encounter.set_physics_process(false)
	for pop in [scene.villager_population,scene.dino_population]:
		if pop!=null: pop.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	ctrl=Controller.new();ctrl.name="JungleExitEncounter";scene.add_child(ctrl)
	var error: String=ctrl.setup(scene,func():return flags,func(e):handled.append(e))
	if not check(error.is_empty(),"Setup failed: "+error):return
	ctrl.set_physics_process(false)
	var pop=ctrl.population
	if not check(pop.bodies.size()==3 and ctrl.targets().is_empty() and State.GUARDS.all(func(id):return not pop.bodies[id].visible),"Guards present before the supplied spawn"):return
	if not check(ctrl.clips[8].frames==22 and ctrl.clips[12].frames==26 and ctrl.endings.size()==3,"Original media differ"):return
	# Region edges: 4437 arms (pred138), re-entry with a latched local53 does nothing; 4435 advances.
	enter(4437)
	if not check(ctrl.encounter.locals["42"]==1 and ctrl.encounter.locals["53"]==1,"Region4437 entry did not arm"):return
	scene.player.global_position=region_point(4437)
	await step(0.5)
	if not check(logged("group","group",17748)==1,"Region event repeated while inside"):return
	enter(4435)
	if not check(ctrl.encounter.locals["42"]==2 and ctrl.encounter.prop4398==1 and handled.any(func(e):return e.type=="object" and e.target==552),"Region4435 differs"):return
	# No automatic spawn: time passes, guards stay absent until the supplied kind5 trigger.
	await step(2.0)
	if not check(ctrl.targets().is_empty(),"Guards spawned without the supplied trigger"):return
	if not check(ctrl.spawn_guards() and ctrl.targets().size()==3 and State.GUARDS.all(func(id):return pop.bodies[id].visible and pop.state.actors[id].present and not pop.state.actors[id].woken),"Supplied spawn differs"):return
	# Predicate182 has no latch: a repeated supplied kind5 re-runs group10720 but cannot duplicate guards.
	var spawns:=logged("spawn")
	if not check(ctrl.spawn_guards() and logged("spawn")==spawns and logged("group","group",10720)==2 and ctrl.targets().size()==3,"Repeated supplied spawn differs"):return
	# Standing next to undecided guards is harmless (source B5 holds them).
	scene.player.global_position=pop.bodies["60"].global_position+Vector3(0,FOOT,40)
	await step(3.0)
	if not check(scene.health==30,"Undecided guard attacked"):return
	enter(4439)
	if not check(ctrl.encounter.locals["56"]==2,"Region4439 differs"):return
	enter(4442)
	var waits:=State.waiting(ctrl.encounter,ctrl.src)
	if not check(ctrl.encounter.actors["59"].pose==8 and ctrl.poses["59"]>=0 and ctrl.pose_meshes["59"].visible and not pop.meshes["59"].visible and waits.size()==1 and waits[0].group==28438 and waits[0].argument==2,"Guard59 pose clip did not start/hold opcode8"):return
	# Partial pose playback through disk.
	await step(0.75)
	var mid:Dictionary=ctrl.checkpoint()
	var frame_mid:int=ctrl.pose_frame("59")
	if not check(frame_mid>=10 and frame_mid<14 and mid.encounter.pending.size()==1,"Pose clip did not advance"):return
	var path:="user://tests/jungle_exit_live.json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	save_disk(mid,path)
	await step(1.0)
	if not check(ctrl.poses["59"]==-1 and ctrl.encounter.pending.is_empty() and State.GUARDS.all(func(id):return State.fighting(ctrl.encounter,id)) and logged("group","group",28528)==1,"Pose end did not release opcode8/event0"):return
	if not check(ctrl.restore(load_disk(path)).is_empty() and ctrl.checkpoint()==mid and ctrl.pose_frame("59")==frame_mid and ctrl.pose_meshes["59"].visible,"Mid-pose disk rollback differs"):return
	ctrl.effect_log.clear()
	await step(1.0)
	if not check(logged("group","group",28528)==1 and State.GUARDS.all(func(id):return State.fighting(ctrl.encounter,id) and pop.state.actors[id].woken),"Restored pose did not finish exactly once"):return
	# Fighting guards attack through the generic owner (original def9 attack clip).
	scene.player.global_position=pop.bodies["60"].global_position+Vector3(0,FOOT,40)
	var waited:=0.0
	while scene.health==30 and waited<8.0:
		await step(0.25);waited+=0.25
	if not check(scene.health<30,"Fighting guard did not attack"):return
	scene.health=30;spells.set_health(30)
	# Original def9 reward scale10 must accept real melee and mirror damage.
	var quests_before: Dictionary=scene.quest_state.duplicate(true)
	melee_ok=pop.receive_damage("60",20)
	await step(0.05)
	if not check(melee_ok and ctrl.encounter.actors["60"].health==235 and scene.quest_state!=quests_before,"Scale10 melee rejected or failed to mirror/reward"):return
	# Spell hits through the generic owner (source reward planner) enter the source as kind9 + event10.
	if not check(pop.receive_damage("60",255,false,20),"Generic spell hit rejected"):return
	await step(0.1)
	if not check(ctrl.encounter.actors["60"].defeated and ctrl.encounter.locals["48"]==1 and ctrl.encounter.actors["60"].health==0,"Defeat did not mirror into the source"):return
	# Timer0 (15 s from the fight) makes guard58 play pose12 while held.
	scene.player.global_position=Vector3(5300,-114+FOOT,-3300)
	await step(13.0)
	if not check(ctrl.poses["58"]>=0 and ctrl.encounter.actors["58"].pose==12 and not State.fighting(ctrl.encounter,"58"),"Timer0 pose12 differs"):return
	await step(2.0)
	if not check(ctrl.poses["58"]==-1 and State.fighting(ctrl.encounter,"58") and (ctrl.encounter.timers["58:1"].flags&1)==0,"Guard58 pose end differs"):return
	for id in ["58","59"]:
		if not check(pop.receive_damage(id,255,false,20),"Spell hit rejected"):return
	await step(0.1)
	if not check(ctrl.encounter.locals["48"]==3 and ctrl.targets().is_empty(),"All defeated differs"):return
	await step(15.1)
	# HW-BRDGE: movie overlay, host paused, partial playback through disk, reposition once.
	if not check(ctrl.movie.phase=="playing" and ctrl.encounter.ending.movie=="HW-BRDGE.VQA" and ctrl.overlay.visible and not scene.is_physics_processing(),"HW-BRDGE did not start"):return
	await step(2.0)
	var movie_mid:Dictionary=ctrl.checkpoint()
	save_disk(movie_mid,path)
	if not check(ctrl.atlas.region.position!=Vector2.ZERO or ctrl.page>0,"Movie frame did not advance"):return
	await step(float(ctrl.endings["HW-BRDGE.VQA"].duration))
	if not check(ctrl.movie.phase=="done" and not ctrl.overlay.visible and scene.is_physics_processing() and is_equal_approx(scene.player.global_position.x,5559.0) and is_equal_approx(scene.player.global_position.z,-3922.0) and logged("reposition")==1,"HW-BRDGE end/reposition differs"):return
	if not check(ctrl.restore(load_disk(path)).is_empty() and ctrl.movie.phase=="playing" and absf(ctrl.movie.elapsed-movie_mid.movie.elapsed)<0.001 and ctrl.overlay.visible,"Mid-movie disk rollback differs"):return
	ctrl.effect_log.clear()
	await step(float(ctrl.endings["HW-BRDGE.VQA"].duration))
	if not check(ctrl.movie.phase=="done" and logged("reposition")==1 and ctrl.checkpoint().encounter.locals["42"]==5,"Restored movie did not finish once"):return
	var done:Dictionary=ctrl.checkpoint()
	await step(1.0)
	if not check(ctrl.checkpoint()==done,"Finished ending changed afterwards"):return
	# E069E: guards alive when the player returns west through region4450 (local42==3).
	var before:=armed()
	await step(2.0)
	enter(4450)
	if not check(ctrl.encounter.ending.movie=="E069E.VQA" and ctrl.movie.phase=="playing" and State.GUARDS.all(func(id):return not pop.state.actors[id].present and not pop.bodies[id].visible),"E069E differs"):return
	if not check(ctrl.validate(ctrl.checkpoint()).is_empty(),"E069E packet invalid"):return
	await step(float(ctrl.endings["E069E.VQA"].duration)+0.1)
	if not check(ctrl.movie.phase=="done" and is_equal_approx(scene.player.global_position.x,5559.0),"E069E end differs"):return
	# E068E: a saved prop4398 state0 (the unstaged Bacatta/guard60 branch) selects predicate51.
	var bacatta:=before.duplicate(true);bacatta.encounter.prop4398=0
	if not check(ctrl.restore(bacatta).is_empty(),"State0 packet rejected"):return
	await step(2.0)
	enter(4450)
	if not check(ctrl.encounter.ending.movie=="E068E.VQA" and ctrl.movie.phase=="playing","E068E differs"):return
	await step(float(ctrl.endings["E068E.VQA"].duration)+0.1)
	if not check(ctrl.movie.phase=="done" and is_equal_approx(scene.player.global_position.x,5563.0),"E068E end differs"):return
	# No context supplied: region edges cannot evaluate predicates and do nothing.
	ctrl.restore(ctrl.initial());ctrl.context_provider=Callable()
	enter(4437)
	if not check(ctrl.encounter.locals["42"]==0,"Region ran without supplied context"):return
	ctrl.context_provider=func():return flags
	# Inactive world (menus/dialogue) freezes the encounter.
	ctrl.restore(mid);spells.on=false
	await step(2.0)
	if not check(ctrl.checkpoint()==mid,"Inactive world advanced"):return
	spells.on=true
	# Malformed packets are rejected atomically.
	var bad_cases: Array=[]
	var b1:=mid.duplicate(true);b1.poses["59"]=-1.0;bad_cases.append(b1)
	var b2:=mid.duplicate(true);b2.poses["59"]=NAN;bad_cases.append(b2)
	var b3:=mid.duplicate(true);b3.poses["59"]=5.0;bad_cases.append(b3)
	var b4:=mid.duplicate(true);b4.movie={"phase":"playing","elapsed":1.0};bad_cases.append(b4)
	var b5:=movie_mid.duplicate(true);b5.movie.elapsed=500.0;bad_cases.append(b5)
	var b6:=mid.duplicate(true);b6.guards.actors["58"].health=100;bad_cases.append(b6)
	var b7:=mid.duplicate(true);b7.inside=[1];bad_cases.append(b7)
	var b8:=mid.duplicate(true);b8.encounter.ticks_fraction=INF;bad_cases.append(b8)
	var b9:=mid.duplicate(true);b9.encounter.ending={"movie_index":33,"movie":"E069E.VQA","predicate":50};bad_cases.append(b9)
	var b10:=mid.duplicate(true);b10.extra=1;bad_cases.append(b10)
	for i in bad_cases.size():
		if not check(not ctrl.restore(bad_cases[i]).is_empty() and ctrl.checkpoint()==mid,"Accepted malformed packet %d"%i):return
	DirAccess.remove_absolute(path)
	print("NOTE: generic melee on def9 (reward scale10) ","accepted" if melee_ok else "rejected by shared cave_melee_reward scale1-4 gate (no state change)")
	print("PASS: Jungle exit live consumer: saved region-entry edges (4437 latch/4435/4439/4442/4450), no auto-spawn, supplied kind5 spawn of 3 original def9 guards on the generic owner, B5-held undecided guards harmless, guard59 pose8 VQA clip holds opcode8 arg2 then event0 (mid-pose disk rollback, exactly-once completion), generic attacks, generic spell hits mirrored to kind9/event10 local48, melee gate atomic, timer0 guard58 pose12 clip, HW-BRDGE/E069E/E068E original movies with paused host, mid-movie disk rollback, single reposition, no context = no region dispatch, inactive world frozen, atomic malformed rejection")
	scene.queue_free()
	await process_frame
	quit()
