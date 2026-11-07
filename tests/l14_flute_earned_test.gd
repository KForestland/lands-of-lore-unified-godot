extends "res://tests/l12_logs_approach_earned_test.gd"
func walk(scene:Node,points:Array,label:String)->bool:
 var result:bool=await super.walk(scene,points,label)
 if not result:
  for j in scene.player.get_slide_collision_count():
   var c=scene.player.get_slide_collision(j)
   print("FLUTE WALK BLOCK ",c.get_collider().get_path()," ",c.get_position()," ",c.get_normal())
 return result
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_spider_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="c74a570dc41a812be14a701ba175d192c03f3570e58b180e0d0924d71dd37fd4","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var items=scene.get_node("Act2WorldItems")
 var id:="act2:L14_HT:item77"
 check(not items.take(id),"remote Temple flute refused")
 var approach:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_flute_approach.json"))
 if not await walk(scene,approach,"return lowered ritual floor"):quit(1);return
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"earned Dreamstone Lizard choice"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual Lizard body"):quit(1);return
 # No automatic stair jumps: remain beneath the original upper floor.
 for point in [[2302,-3320],[2304,-3272],[2290,-3200],[2222,-3046]]:
  var reached:=false
  for i in 1600:
   scene.curse.advance(1.0/60)
   var d:Vector3=Vector3(point[0],scene.player.position.y,point[1])-scene.player.position
   if d.length()<3 and scene.player.is_on_floor():reached=true;break
   scene.move_grounded(d.normalized(),1.0/60);await physics_frame
  print("LOWER CRAWL ",point," ",scene.player.position)
  if not check(reached,"physical lower corridor crawl"):quit(1);return
 if not check(scene.player.position.y< -40,"actual lower floor-80 with preserved32-unit player origin, not upper ceiling"):quit(1);return
 if not check(passage.choose_form(),"production Human return"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"Human fits original lower corridor"):quit(1);return
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_flute_walk.json"))
 if not await walk(scene,points,"Temple coffin flute"):quit(1);return
 scene.camera.look_at(items.aim_point(id),Vector3.UP)
 paused=true;check(not items.take(id),"paused flute pickup refused");paused=false
 if not check(items.take(id),"take actual Temple item77 Iron Flute"):quit(1);return
 check(not items.take(id),"no duplicate flute")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_flute_earned_save.json")
 print("FLUTE SAVE ERROR ",error)
 check(error.is_empty(),"Temple flute save: "+error)
 if error.is_empty():check(scene._quickload_unrecorded("res://tmp/l14_flute_earned_save.json").is_empty(),"Temple flute reload")
 else:
  var debug=FileAccess.open("res://tmp/l14_flute_failed_state.json",FileAccess.WRITE)
  debug.store_string(JSON.stringify({"inventory":scene.inventory_state(),"quests":scene.quest_state}));debug.close()
 check(scene.carried_collected.count(id)==1 and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"same original flute no seed/recovery")
 print("FLUTE END ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned spider corridor -> original Temple flute77 pickup/save-reload")
 quit(0 if failures==0 else 1)
