extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_hanging_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="9404854b4b38d73b75796c69a3bd5dff64bf66adb59ad40894613a5317bb0e23","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var population=scene.act2_creatures
 print("SPIDER68 INITIAL ",population.state.actors["68"])
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_hanging_spider.json"))
 if not await walk(scene,points,"original spider corridor"):quit(1);return
 var encounter=scene.get_node("L14SpiderPassage")
 check(population.state.actors["68"].health==0,"actual original HIVEW68 defeated")
 for i in 3:await physics_frame
 check(encounter.state().kills==1,"first actual combat death receipt")
 paused=true
 var before:float=encounter.state().timer
 for i in 20:await process_frame
 check(encounter.state().timer==before,"paused respawn clock")
 paused=false
 for i in 900:
  await physics_frame
  scene.move_grounded(Vector3.ZERO,1.0/60)
  if population.state.actors["68"].health>0:break
 check(population.state.actors["68"].health>0,"actual timed gameplay respawn")
 if not await fight_nearby(scene):quit(1);return
 for i in 3:await physics_frame
 check(encounter.state().kills==2,"second actual combat death")
 check(scene._quicksave_unrecorded("res://tmp/l14_spider_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l14_spider_earned_save.json").is_empty(),"original encounter save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 print("SPIDER END ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned hanging -> original corridor -> actual HIVEW68 combat/save-reload")
 quit(0 if failures==0 else 1)
