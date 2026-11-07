extends SceneTree
## Pre-exit L4WW conversation on the real Jungle host (supplied local approach, not an earned route):
## camera sighting, grounded source regions, original in-world frames and voices, input hold and
## reposition, disk save/load inside both conversations with stale-callback rejection, actor0/66
## bodies, armed-melee hit branch, exit-spawn removal and atomic rejection of malformed packets.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const State=preload("res://scripts/lol2/jungle_exit_woman_state.gd")
var scene
var w
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok

func open_jungle(equip: bool=true) -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD if equip else "","equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	for name in ["exit_encounter","bacatta","kelsrick","dawn","actor62","villager_population","dino_population","village_gate","village_dialogue","followup_gate","followup_dialogue","world_items","source_pickups"]:
		var node=scene.get(name)
		if node!=null and is_instance_valid(node): node.set_physics_process(false);node.set_process(false)
	w=scene.exit_woman
	if w!=null: w.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func close_jungle() -> void:
	await RenderingServer.frame_post_draw
	scene.queue_free()
	for i in 3: await process_frame

## Stand on the ground of a source region (centre of its polygon).
func stand_in(region: int) -> void:
	var row: Dictionary=w.src.regions.filter(func(r): return int(r.region)==region)[0]
	var c:=Vector2.ZERO
	for v in row.polygon: c+=Vector2(v[0],v[1])
	c/=row.polygon.size()
	var o: Vector3=w.origin()
	var top:=Vector3(c.x,float(row.floor_min)+200,c.y)+o
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	var y: float=hit.position.y if not hit.is_empty() else float(row.floor_min)+o.y
	scene.player.global_position=Vector3(c.x+o.x,y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,c.y+o.z)
	scene.player.velocity=Vector3.ZERO
	await physics_frame

## Rendered witness (local only): user://captures/<name>.png.
func capture(name: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/%s.png"%name)

func step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		w.advance(1.0/30.0)
		if i%15==0: await process_frame

## Advances until a predicate holds; returns the clip selectors started meanwhile.
func run_until(predicate: Callable, limit: float=90.0) -> Array:
	var started: Array=[]
	var seen_log: int=w.effect_log.size()
	for i in int(limit*30.0):
		w.advance(1.0/30.0)
		if i%15==0: await process_frame
		if predicate.call(): break
	for e in w.effect_log.slice(seen_log):
		if e.type=="clip_start": started.append(int(e.selector))
	return started

func run() -> void:
	var path:="user://tests/jungle_exit_woman_live.json"
	await open_jungle()
	if not check(w!=null and w.state.prop.present and not w.sighted,"Exit conversation not installed on the Jungle host"):return
	# Sighting through the production camera frustum and an unobstructed ray.
	var anchor: Vector3=w.prop_anchor()
	scene.player.global_position=anchor+Vector3(-260,60,40);scene.camera.look_at(anchor+Vector3.UP*40)
	await physics_frame
	await step(0.2)
	if not check(w.sighted and int(w.state.prop.clip.selector)==0 and w.mesh.visible,"Camera sighting did not start the world idle"):return
	# First meeting: grounded region4387 entry holds input, repositions and starts selector6 frames.
	var before: Vector3=scene.player.global_position
	var log_at: int=w.effect_log.size()
	await stand_in(4387)
	await step(0.1)
	if not check(scene.actor_input_locked() and w.state.local1==3 and int(w.state.prop.selector)==6 and scene.player.global_position.distance_to(before)>1.0,"Region4387 did not hold/reposition/start selector6"):return
	# Op5 one-frame run, then the first line voiced exactly once, with the player focused on the speaker.
	var entry: Array=w.effect_log.slice(log_at).filter(func(e): return e.type in ["frames_start","clip_start"]).map(func(e): return [e.type,int(e.selector)])
	if not check(entry==[["frames_start",6],["clip_start",6]] and w.state.focus and int(w.state.prop.clip.selector)==6,"First line not voiced once after the one-frame run: %s"%[entry]):return
	var first:=await run_until(func(): return int(w.state.prop.state)==5 and not w.state.prop.clip.is_empty() and float(w.state.prop.clip.elapsed)>0.5)
	if not check(w.voice.playing and w.voice.stream!=null and w.mesh.visible,"Original voice/frames not presented mid-conversation"):return
	await capture("exit_woman_conversation")
	# Disk save mid-conversation, divergence, reload: exact restore and stale callbacks rejected.
	if not check(scene.quicksave(path).is_empty(),"Quicksave during conversation failed"):return
	var saved_state: Dictionary=w.state.duplicate(true)
	var old_gen: int=int(w.state.prop.clip.generation);var old_sel: int=int(w.state.prop.clip.selector)
	await step(3.0)
	if not check(scene.quickload(path).is_empty(),"Quickload during conversation failed"):return
	var reloaded: Dictionary=w.state.duplicate(true)
	if not check(int(reloaded.prop.state)==int(saved_state.prop.state) and int(reloaded.prop.clip.selector)==old_sel and absf(float(reloaded.prop.clip.elapsed)-float(saved_state.prop.clip.elapsed))<0.0001 and scene.actor_input_locked(),"Quickload did not restore the conversation exactly"):return
	if not check(int(w.state.prop.generation)>old_gen and not w.media_clip_ended(old_sel,old_gen) and w.state==reloaded,"Stale pre-restore callback was admitted"):return
	# Repeated load of the SAME file: callbacks from the first loaded presentation (its opening clip and its
	# later playback) must not be admitted by the second, via the host's runtime high-water mark.
	var load1_gen: int=int(w.state.prop.clip.generation);var load1_sel: int=int(w.state.prop.clip.selector)
	await step(4.0)
	var load1_later: int=int(w.state.prop.generation)
	var load1_later_sel: int=int(w.state.prop.clip.get("selector",w.state.prop.selector))
	if not check(scene.quickload(path).is_empty(),"Second quickload of the same file failed"):return
	var reloaded2: Dictionary=w.state.duplicate(true)
	if not check(int(w.state.prop.generation)>load1_later and not w.media_clip_ended(load1_sel,load1_gen) and not w.media_clip_ended(load1_later_sel,load1_later) and not w.media_selector_finished(load1_later_sel,load1_later) and w.state==reloaded2,"Repeated load admitted a callback from the first loaded presentation"):return
	first.append_array(await run_until(func(): return not w.state.prop.present))
	if not check(w.state.actors["0"].present and w.population.state.actors["0"].present and not scene.actor_input_locked() and not w.state.focus and not w.mesh.visible,"First conversation did not end with actor0 and released input"):return
	scene.player.global_position=w.prop_anchor()+Vector3(-150,40,30);scene.camera.look_at(w.prop_anchor()+Vector3.UP*30)
	await capture("exit_woman_actor0")
	# Second meeting: region4407 arms local1, region1902 relinks prop554, region4387 starts selector5.
	await stand_in(4407);await step(0.1)
	await stand_in(1902);await step(0.1)
	var relink_gen: int=int(w.state.prop.generation)
	if not check(w.state.local1==1 and w.state.prop.present and int(w.state.prop.clip.selector)==0,"Second-meeting relink differs"):return
	await stand_in(4387);await step(0.1)
	if not check(scene.actor_input_locked() and int(w.state.prop.selector)==5 and int(w.state.prop.clip.selector)==5 and w.state.focus and not w.media_clip_ended(0,relink_gen),"Second meeting entry differs or stale relink callback admitted"):return
	await run_until(func(): return int(w.state.prop.state)==13)
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and int(w.state.prop.state)==13 and scene.actor_input_locked(),"Second-conversation save/load differs"):return
	await run_until(func(): return not w.state.prop.present)
	if not check(w.state.actors["66"].present and w.population.state.actors["66"].present and not scene.actor_input_locked(),"Second conversation did not end with actor66"):return
	# Atomic rejection: a packet whose body disagrees with the conversation changes nothing.
	var good: Dictionary=w.checkpoint()
	var bad: Dictionary=good.duplicate(true);bad.body.actors["66"].present=false
	if not check(not w.restore(bad).is_empty() and w.checkpoint()==good and not preload("res://scripts/lol2/act_one_quest_state.gd").validate({"jungle_exit_woman":bad}).is_empty(),"Malformed packet partially applied"):return
	# Goal3 home return: actor0 already walked to its home node and removed itself (kind6 value8, A29EA);
	# actor66 walks now, survives a disk save/load mid-walk and removes itself on arrival.
	var removed0: bool=w.effect_log.any(func(e): return e.type=="remove" and int(e.actor)==0)
	if not check(not w.state.actors["0"].present and not w.population.state.actors["0"].present and removed0,"Actor0 did not walk home and remove itself"):return
	var home66:=Vector2(float(w.src.actors["66"].home[0]),float(w.src.actors["66"].home[2]))
	var start66:=Vector2(float(w.population.state.actors["66"].position[0]),float(w.population.state.actors["66"].position[2]))
	await step(5.0)
	var mid66: Array=w.population.state.actors["66"].position.duplicate()
	if not check(Vector2(mid66[0],mid66[2]).distance_to(home66)<start66.distance_to(home66)-100.0 and w.population.state.live["66"].mode==preload("res://scripts/lol2/creature_live_rules.gd").PURSUE,"Actor66 is not walking home"):return
	scene.player.global_position=w.population.bodies["66"].global_position+Vector3(-120,40,60);scene.camera.look_at(w.population.bodies["66"].global_position+Vector3.UP*30)
	await capture("exit_woman_actor66_walk")
	if not check(scene.quicksave(path).is_empty(),"Mid-walk save failed"):return
	await step(2.0)
	if not check(scene.quickload(path).is_empty() and w.population.state.actors["66"].position==mid66 and w.state.actors["66"].present,"Mid-walk load differs"):return
	await run_until(func(): return not w.state.actors["66"].present,40.0)
	if not check(not w.state.actors["66"].present and not w.population.state.actors["66"].present and not w.population.bodies["66"].visible,"Actor66 did not remove itself at its home node"):return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and not w.state.actors["66"].present and not w.state.actors["0"].present,"Post-removal save differs"):return
	await close_jungle()
	# Hit branch: real armed melee aimed at prop554 during the first meeting.
	await open_jungle()
	scene.player.global_position=w.prop_anchor()+Vector3(-260,60,40);scene.camera.look_at(w.prop_anchor()+Vector3.UP*40)
	await physics_frame;await step(0.1)
	await stand_in(4387);await step(1.0)
	var aimed:=false
	for angle in range(0,360,20):
		var a:=deg_to_rad(angle)
		scene.player.global_position=w.prop_anchor()+Vector3(sin(a)*60,32,cos(a)*60)
		scene.camera.look_at(w.prop_anchor()+Vector3.UP*40);await physics_frame
		if w.can_strike(): aimed=true;break
	if not check(aimed and w.strike() and w.state.actors["0"].present and not w.state.prop.present and w.state.local1==2 and not scene.actor_input_locked(),"Armed hit branch differs"):return
	await close_jungle()
	# Exit guard spawn (exit local56) removes prop554 and closes the branch.
	await open_jungle()
	scene.exit_encounter.encounter.locals["56"]=1
	await step(0.1)
	if not check(w.exit_applied and not w.state.prop.present and w.state.local1==5,"Exit spawn interaction differs"):return
	await stand_in(4387);await step(0.2)
	if not check(not scene.actor_input_locked() and w.state.prop.frames.is_empty(),"Branch continued after exit spawn"):return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and w.exit_applied,"Exit-closed save differs"):return
	await close_jungle()
	DirAccess.remove_absolute(path)
	if failed: return
	print("PASS jungle exit woman live: camera sighting, op5 one-frame run then first line voiced once with player focus, region4387 hold/reposition, original frames+voice, disk save/load in both conversations with stale pre-restore/repeated-load/relink callbacks rejected, actor0 then actor66 bodies walking home and removing themselves (kind6 value8) incl. mid-walk save/load, armed hit branch, exit-spawn closure, atomic malformed packet. Supplied approach; not earned.")
	quit()
