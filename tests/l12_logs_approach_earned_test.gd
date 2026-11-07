extends "res://tests/l9_chapel_earned_test.gd"
func fight_nearby(scene:Node)->bool:
 scene.curse.advance(1.0/60) # Live controller clock while headless harness owns movement.
 return await super.fight_nearby(scene)
func walk(scene:Node,points:Array,label:String)->bool:
 for index in points.size():
  var goal:=Vector3(points[index][0],0,points[index][1])
  var reached:=false
  var prior:Vector3=scene.player.position
  var stalled:=0
  for tick in 1600:
   if not await fight_nearby(scene):return false
   var d:Vector3=goal-scene.player.position;d.y=0
   if d.length()<(2.0 if scene.player_form==2 else 7.0) and scene.player.is_on_floor():reached=true;break
   if scene.player.position.distance_to(prior)<0.05:stalled+=1
   else:stalled=0
   prior=scene.player.position
   if stalled==20 and scene.player.is_on_floor():
    check(scene.request_jump(),"actual jump at original stair lip");print("STAIR jump ",index," ",scene.player.position);stalled=0
   scene.move_grounded(d.normalized(),1.0/60);await physics_frame
   if tick%300==0:print("RETURN WALK ",label," point",index," ",scene.player.position)
  if not check(reached,label+" point"+str(index)+" at "+str(scene.player.position)):return false
  if label=="return Lizard crawl" and index==4:check(scene.request_jump(),"real Lizard jump before original20-unit upward floor seam")
 return true
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_frozen_bow_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="0d98d5cb6598a599a549a6c8cbd16772ff639847922f74c5121b1b14d1198c09","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var cave=scene.get_node("L12Crevasse")
 if not check(cave.choose_form(),"production return Lizard request"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual return Lizard body"):quit(1);return
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_crevasse_crawl.json"));points.reverse();points.append([3000,-13600])
 if not await walk(scene,points,"return Lizard crawl"):quit(1);return
 if not check(cave.choose_form(),"production Human request at outer entrance"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"Human log-climb approach"):quit(1);return
 points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_crevasse_approach.json"));points.reverse();points.append([3000,-13000])
 if not await walk(scene,points,"return to original ice bridge"):quit(1);return
 if not await walk(scene,[[2990,-12750],[3037,-12602],[3114,-12454],[3202,-12313],[3250,-12255],[3250,-12235],[3190,-12120]],"reverse original bridge83/84/85"):quit(1);return
 points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_logs_approach.json"))
 if not await walk(scene,points,"original glacier log68"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l12_logs_approach_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_logs_approach_earned_save.json").is_empty(),"earned log approach save/reload")
 check(scene.equipped_armor=="act2:L12_CM:item5" and "act2:L12_CM:blue_bow" in scene.carried_collected and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"earned items/no seeds/recovery")
 print("LOGS APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned bow ->physical return Lizard crawl ->Human bridge crossing ->original log approach/save-reload")
 quit(0 if failures==0 else 1)
