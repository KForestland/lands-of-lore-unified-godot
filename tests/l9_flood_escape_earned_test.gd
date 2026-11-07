extends "res://tests/l9_chapel_earned_test.gd"
func combat_candidate(_scene:Node,id:String)->bool:return id!="76"
func reached_waypoint(scene:Node,label:String,index:int)->void:
 if label=="low roof" and index in [3,17]:check(scene.request_jump(),"ordinary jump over source seam")
func input_save()->String:return "res://tmp/dampen_qualified/l9_statue_fight_earned_save.json"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"qualified statue-fight save"):quit(1);return
 prepare(scene)
 var inventory:Array=scene.carried_collected.duplicate()
 var lift=scene.get_node("L9Escape")
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_flood_escape_walk.json"))
 if not await walk(scene,route.approach,"low roof"):quit(1);return
 check(not lift.state().boarded,"brushing table side did not board lift")
 check(scene.request_jump(),"ordinary jump onto source table122")
 for i in 170:
  await physics_frame
  var d:Vector3=lift.bodies[122].position-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>3 else Vector3.ZERO,scene.player.get_physics_process_delta_time(),true)
 if not check(lift.state().boarded,"standing on table starts lift"):quit(1);return
 for i in 500:
  await physics_frame;scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
  if lift.state().lift>=8:break
 var midpoint:Dictionary=lift.state().duplicate(true)
 paused=true
 for i in 12:await process_frame
 check(lift.state()==midpoint,"pause freezes physical lift")
 paused=false
 var path:="res://tmp/l9_flood_lift_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"mid-lift save/reload")
 for i in 600:
  await physics_frame;scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
  if lift.state().lift==lift.State.DURATION:break
 if not check(absf(scene.player.position.y-32-lift.tunnel_floor)<3,"carried to geometry tunnel floor"):quit(1);return
 check(scene.request_jump(),"ordinary jump off lift")
 for i in 65:
  await physics_frame
  var d:Vector3=Vector3(2620,0,-9650)-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>3 else Vector3.ZERO,scene.player.get_physics_process_delta_time(),true)
 if not check(scene.player.position.y>450,"landed in source side tunnel6304"):quit(1);return
 if not await walk(scene,route.tunnel,"tunnel to raft"):quit(1);return
 for i in 1200:
  await physics_frame;scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
  if not scene.progression.level_changes.is_empty():break
 if not check(lift.state().escaped and not scene.progression.level_changes.is_empty(),"physical raft -> source exit timer"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 check(change.level==8 and change.selector==5,"original shore arrival5")
 check(scene.carried_collected==inventory,"escape preserves inventory")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no recovery or arrival seeds")
 path="res://tmp/l9_flood_escape_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"escaped receipt persists")
 scene.queue_free();await process_frame
 if failures==0:print("PASS qualified statue fight -> rising water -> low roof -> ordinary table jump -> saved lift ride -> ordinary tunnel jump -> physical raft -> native L8/5 exit; inventory unchanged")
 quit(0 if failures==0 else 1)
