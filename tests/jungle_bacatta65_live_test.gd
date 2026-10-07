extends SceneTree
## Huline-alert-before-first-meeting Bacatta (prop553 → actor65) on the real Jungle host (supplied approach, not an
## earned route): the alert is the village gate's shared29; prop3235 camera sighting starts the BC08 idle; grounded
## first entry holds movement, repositions and talks; the first line sets GV_MET_BACATTA; disk save/load mid-line
## restores exactly; an idle-wait E-use offer raises the Bacatta relationship; the state16 timer ends in the
## peaceful actor65 (persisting over save/load and a fresh-scene resume, no re-trigger); region3157 removes her.
## A second session: armed melee on prop553 → Luther lines → hostile actor65 fighting through the generic owner,
## persisting over save/load. Malformed packets are rejected atomically.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const State=preload("res://scripts/lol2/jungle_bacatta65_state.gd")
var scene
var b
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok

func globals() -> Dictionary: return scene.quest_state.monastery.globals

func open_jungle(alert: int=1) -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	for name in ["exit_encounter","bacatta","exit_woman","kelsrick","dawn","actor62","villager_population","dino_population","village_gate","village_dialogue","followup_gate","followup_dialogue","world_items","source_pickups"]:
		var node=scene.get(name)
		if node!=null and is_instance_valid(node): node.set_physics_process(false);node.set_process(false)
	b=scene.bacatta65
	if b!=null: b.set_physics_process(false)
	if alert==1 and is_instance_valid(scene.village_gate): scene.village_gate.state().shared29=1
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func close_jungle() -> void:
	await RenderingServer.frame_post_draw
	scene.queue_free()
	for i in 3: await process_frame

func stand_in(region: int) -> void:
	var row: Dictionary=b.src.regions.filter(func(r): return int(r.region)==region)[0]
	var c:=Vector2.ZERO
	for v in row.polygon: c+=Vector2(v[0],v[1])
	c/=row.polygon.size()
	var o: Vector3=b.origin()
	var top:=Vector3(c.x,float(row.floor_min)+200,c.y)+o
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	var y: float=hit.position.y if not hit.is_empty() else float(row.floor_min)+o.y
	scene.player.global_position=Vector3(c.x+o.x,y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,c.y+o.z)
	scene.player.velocity=Vector3.ZERO
	await physics_frame

func capture(name: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/%s.png"%name)

func step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		b.advance(1.0/30.0)
		if i%15==0: await process_frame

func run_until(predicate: Callable, limit: float=90.0) -> bool:
	for i in int(limit*30.0):
		b.advance(1.0/30.0)
		if i%15==0: await process_frame
		if predicate.call(): return true
	return false

## Look at prop3235 from a clear lane (the sighting producer needs frustum + unobstructed ray).
func sight() -> bool:
	var at: Vector3=b.starter_anchor()
	for angle in range(0,360,30):
		var a:=deg_to_rad(angle)
		scene.player.global_position=at+Vector3(sin(a)*300,60,cos(a)*300)
		scene.camera.look_at(at+Vector3.UP*40);await physics_frame
		if b.starter_visible(): return true
	return false

func aim_prop(check_fn: Callable) -> bool:
	for angle in range(0,360,20):
		var a:=deg_to_rad(angle)
		scene.player.global_position=b.prop_anchor()+Vector3(sin(a)*60,32,cos(a)*60)
		scene.camera.look_at(b.prop_anchor()+Vector3.UP*45);await physics_frame
		if check_fn.call(): return true
	return false

## Sighting + first entry, shared by both sessions.
func meet() -> bool:
	if not check(await sight(),"No clear view of prop3235"): return false
	await step(0.2)
	if not check(b.state.sighted and b.state.prop.present and int(b.state.prop.clip.segment)==1 and b.mesh.visible,"Sighting did not start the BC08 idle"): return false
	var before: Vector3=scene.player.global_position
	await stand_in(3896);await step(0.1)
	if not check(int(b.state.locals["2"])==1 and int(b.state.prop.state)==2 and b.movement_locked() and not scene.request_jump() and scene.player.global_position.distance_to(before)>1.0,"First entry did not hold/reposition/talk"): return false
	return true

func run() -> void:
	var path:="user://tests/jungle_bacatta65_live.json"
	# No alert: the sighting admits nothing.
	await open_jungle(0)
	if not check(b!=null and not b.state.prop.present,"Bacatta65 not installed on the Jungle host"): return
	await sight();await step(0.3)
	if not check(not b.state.sighted and not b.state.prop.present,"Sighting admitted without the Huline alert"): return
	await close_jungle()
	# Session 1: talk, save/load mid-line, offer, timer -> peaceful actor65, resume, removal.
	await open_jungle()
	if not await meet(): return
	if not check(await run_until(func(): return int(globals().get("GV_MET_BACATTA",0))==1),"First line did not set GV_MET_BACATTA"): return
	await run_until(func(): return not b.state.prop.clip.is_empty() and float(b.state.prop.clip.elapsed)>0.5,10.0)
	if not check(b.voice.playing and b.mesh.visible,"Original voice/frames not presented mid-conversation"): return
	scene.player.global_position=b.prop_anchor()+Vector3(-150,50,40);scene.camera.look_at(b.prop_anchor()+Vector3.UP*45)
	await capture("bacatta65_conversation")
	var saved: Dictionary=b.checkpoint()
	if not check(scene.quicksave(path).is_empty(),"Quicksave during conversation failed"): return
	await step(2.0)
	if not check(scene.quickload(path).is_empty() and b.checkpoint().branch==State.canonical(saved.branch),"Quickload did not restore the conversation exactly"): return
	if not check(b.movement_locked() and int(globals().GV_MET_BACATTA)==1 and int(scene.village_gate.state().shared29)==1,"Reload lost the hold or the globals"): return
	# Idle wait at state6: movement free, E-use with a carried item offers (+1 relationship).
	if not check(await run_until(func(): return int(b.state.prop.state)==6,60.0),"State6 wait not reached"): return
	if not check(not b.movement_locked(),"Idle wait holds movement"): return
	scene.hand_item=Save.Museum.SWORD
	if not check(await aim_prop(func(): return b.can_offer()) and b.offer() and int(globals().get("GV_BACATTA_RELATIONSHIP",0))==1 and int(b.state.prop.state)==29,"Offer at the idle wait differs"): return
	scene.hand_item=""
	if not check(await run_until(func(): return int(b.state.prop.state)==16,150.0),"State16 not reached"): return
	if not check(await run_until(func(): return b.state.actor.present,120.0),"Timer did not lead to actor65: %s"%[b.state]): return
	if not check(not b.hostile() and not b.state.prop.present and not b.movement_locked() and b.population.state.actors["65"].present and b.targets().size()>0,"Peaceful outcome differs"): return
	scene.player.global_position=b.population.bodies["65"].global_position+Vector3(-140,50,40);scene.camera.look_at(b.population.bodies["65"].global_position+Vector3.UP*35)
	await capture("bacatta65_peaceful")
	if not check(scene.quicksave(path).is_empty(),"Peaceful save failed"): return
	await close_jungle()
	# Return: a fresh host resumes the peaceful Bacatta65; re-entry and re-sighting run nothing.
	await open_jungle()
	if not check(scene.quickload(path).is_empty() and b.state.actor.present and not b.hostile() and b.population.state.actors["65"].present and not b.state.prop.present,"Fresh-host resume differs"): return
	var resumed: Dictionary=b.checkpoint()
	await sight();await stand_in(3896);await step(0.5)
	if not check(b.checkpoint().branch==resumed.branch,"Return re-ran the encounter"): return
	# Region3157 (met) removes actor65; actor57 stays unowned (reported).
	await stand_in(3157);await step(0.1)
	if not check(not b.state.actor.present and not b.population.state.actors["65"].present and b.effect_log.any(func(e): return e.type=="external" and e.raw=="090239000200"),"Region3157 removal differs"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and not b.state.actor.present,"Post-removal save differs"): return
	# Atomic rejection of a packet whose body disagrees with the branch.
	var good: Dictionary=b.checkpoint()
	var bad: Dictionary=good.duplicate(true);bad.body.actors["65"].present=true
	if not check(not b.restore(bad).is_empty() and b.checkpoint()==good and not preload("res://scripts/lol2/act_one_quest_state.gd").validate({"jungle_bacatta65":bad}).is_empty(),"Malformed packet partially applied"): return
	await close_jungle()
	# Session 2: armed strike on prop553 -> Luther lines -> hostile actor65.
	await open_jungle()
	if not await meet(): return
	# Walk-away during the state6 idle wait: grounded entry into an outer region pulls the player back (selector29 once).
	if not check(await run_until(func(): return int(b.state.prop.state)==6,60.0) and not b.movement_locked(),"State6 idle wait not reached"): return
	var away_from: Vector3
	await stand_in(3890);away_from=scene.player.global_position;await step(0.1)
	if not check(int(b.state.locals["2"])==3 and int(b.state.prop.state)==32 and int(b.state.prop.selector)==29 and b.movement_locked() and scene.player.global_position.distance_to(away_from)>1.0,"Walk-away did not pull the player back"): return
	if not check(await run_until(func(): return int(b.state.prop.state)==7,15.0),"Walk-away line did not resume the talk"): return
	await stand_in(3891);await step(0.1)
	if not check(int(b.state.prop.state)!=32,"Walk-away replayed"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and int(b.state.locals["2"])==3,"Walk-away save/load differs"): return
	# Ordinary armed strike during the state11 idle wait.
	if not check(await run_until(func(): return int(b.state.prop.state)==11,90.0) and not b.movement_locked(),"State11 idle wait not reached"): return
	if not check(await aim_prop(func(): return b.can_strike()) and b.strike() and int(b.state.prop.state)==19 and int(b.state.locals["3"])==1,"Armed strike did not take the hit path"): return
	if not check(int(globals().GV_MET_BACATTA)==1,"Hit did not set GV_MET_BACATTA"): return
	if not check(await run_until(func(): return b.state.actor.present,30.0) and b.hostile() and b.targets().size()>0 and not b.movement_locked(),"Hit path did not end in a hostile actor65"): return
	await step(1.0)
	if not check(b.population.state.actors["65"].woken,"Hostile actor65 not fighting"): return
	scene.player.global_position=b.population.bodies["65"].global_position+Vector3(-140,50,40);scene.camera.look_at(b.population.bodies["65"].global_position+Vector3.UP*35)
	await capture("bacatta65_hostile")
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and b.hostile() and b.population.state.actors["65"].present,"Hostile save/load differs"): return
	# Independent lead probe: actual hostile attack, pause and defeat persistence.
	scene.health=30
	scene.player.global_position=b.population.bodies["65"].global_position+Vector3(36,32,0)
	await physics_frame
	if not check(await run_until(func(): return scene.health<30,12.0),"Hostile body never damaged the nearby player"): return
	var hit_health: int=scene.health
	var paused_packet: Dictionary=b.checkpoint()
	paused_packet=paused_packet.duplicate(true)
	paused=true
	b.advance(2.0)
	paused=false
	if not check(b.checkpoint()==paused_packet and scene.health==hit_health,"Paused encounter advanced or damaged player"): return
	# Use the existing damage receiver (combat owner), then disk-save the corpse.
	if not check(b.population.receive_damage("65",1000,true),"Hostile body rejected lethal damage"): return
	await step(0.2)
	if not check(b.population.state.actors["65"].health==0 and b.targets().is_empty(),"Defeated Bacatta remains targetable"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and b.population.state.actors["65"].health==0 and b.targets().is_empty(),"Corpse resurrected on disk reload"): return
	print("PASS independent Bacatta65 body: attack health=",hit_health," pause frozen; lethal receiver/corpse disk restore")
	await close_jungle()
	DirAccess.remove_absolute(path)
	if failed: return
	print("PASS jungle bacatta65 live: alert gate (village shared29), prop3235 camera sighting -> BC08 idle, grounded first entry hold/reposition, first line sets GV_MET_BACATTA, disk save/load mid-line exact, idle-wait offer +1 relationship, timer -> peaceful actor65, fresh-host resume without re-trigger, region3157 removal, atomic malformed packet; walk-away during the idle wait pulls back once (save/load), armed strike during the idle wait -> Luther lines -> hostile actor65 (generic owner) persisting over save/load. Supplied approach; not earned.")
	quit()
