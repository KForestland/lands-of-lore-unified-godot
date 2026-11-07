extends "res://tests/l9_chapel_earned_test.gd"
func input_save()->String:return "res://tmp/l9_ashes_earned_save.json"
func return_parts()->Array:return ["chapel","bridge","bank","gallery"]
func return_points(part: String,route: Dictionary)->Array:return route[part].points
func walk(scene: Node,points: Array,label: String)->bool:
 var jumps: Array={"ashes return bank":[[3090,-8308],[2700,-7790],[-300,-6560]],"ashes return gallery":[[-1120,-6100]]}.get(label,[])
 var segment: Array=[]
 var jump_next:=false
 for point in points:
  if jump_next:
   if not await running_jump_to(scene,point):return false
   jump_next=false
   continue
  segment.append(point)
  var jump_here:=false
  for target in jumps:
   if Vector2(point[0],point[1]).distance_to(Vector2(target[0],target[1]))<0.1:jump_here=true
  if not jump_here:continue
  if not await super.walk(scene,segment,label):return false
  for i in 120:
   await physics_frame
   scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
   if scene.player.is_on_floor():break
  if not check(scene.request_jump(),"real grounded return jump"):return false
  segment=[];jump_next=true
 return await super.walk(scene,segment,label)
func running_jump_to(scene: Node,point: Array)->bool:
 var goal:=Vector3(point[0],0,point[1]);var airborne:=false
 var high: float=scene.player.position.y
 print("RETURN JUMP start ",scene.player.position," target ",goal)
 for i in 600:
  await physics_frame
  # Keep the running jump moving while live enemies attack; fight on landing.
  if not check(scene.resets==0 and scene.starting_magic.health()>0,"survive real airborne crossing"):return false
  if scene.starting_magic.health()<heal_threshold():
   scene.starting_magic.select_spell("heal");scene.starting_magic.cast()
  high=maxf(high,scene.player.position.y)
  var delta: Vector3=goal-scene.player.position;delta.y=0
  if not scene.player.is_on_floor():airborne=true
  if airborne and scene.player.is_on_floor() and delta.length()<8:return true
  scene.move_grounded(delta.normalized() if delta.length()>6 else Vector3.ZERO,scene.player.get_physics_process_delta_time(),true)
 for i in scene.player.get_slide_collision_count():
  var collision=scene.player.get_slide_collision(i);print("RETURN JUMP HIT ",collision.get_collider().get_path()," ",collision.get_position()," ",collision.get_normal())
 return check(false,"real running jump failed at "+str(scene.player.position)+" high "+str(high))
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual filled urn save"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_ashes_return_walk.json"))
 for part in return_parts():
  if not await walk(scene,return_points(part,route),"ashes return "+part):quit(1);return
  check(scene._quicksave_unrecorded("res://tmp/l9_ashes_return_"+part+"_earned_save.json").is_empty(),"actual ashes return checkpoint "+part)
 if not await walk(scene,route.cemetery_mirror.points,"Cemetery source mirror"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"source Cemetery mirror entered"):quit(1);return
 var change: Dictionary=scene.progression.level_changes.back()
 if not check(change.level==10 and change.selector==2,"original Cemetery2 destination"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check("act2:L9_DR:item0" in scene.carried_collected and "act2:L10_DC:priest_urn" not in scene.carried_collected,"filled urn survives original mirror handoff")
 check(scene.quest_state.l9_pyre.phase==3 and scene.quest_state.l9_pyre.slots["chapel:ashes"].committed,"cremation and receipt survive return")
 check(scene.progression.seeds_applied.is_empty(),"no arrival seeds")
 var path:="res://tmp/l10_ashes_return_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual Cemetery ashes save/reload")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual filled urn -> reverse chapel/bridge/bank/gallery -> native Cemetery mirror -> actual ashes return save/reload; no seeds or branch merging")
 quit(0 if failures==0 else 1)
