extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_blade_bypass_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="f8244f800896b6cc24c5dd91f67e9cf05c21bd3297071938bb700ccf2360bba5","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 var trap=scene.get_node("L14TrapRoute")
 if not await walk(scene,[[29,1000]],"actual approach to central boulder trigger"):quit(1);return
 var motion_saved:bool=false
 for i in 240:
  scene.move_grounded(Vector3(0,0,1),1.0/60);await physics_frame
  if trap.state().triggered and not motion_saved and trap.state().elapsed>=0.1:
   var elapsed:float=trap.state().elapsed
   paused=true
   for j in 8:await process_frame
   check(trap.state().elapsed==elapsed,"boulder motion pauses");paused=false
   var err:String=scene._quicksave_unrecorded("res://tmp/l14_boulder_moving_save.json")
   if not check(err.is_empty(),"moving boulder save: "+err):quit(1);return
   if not check(scene._quickload_unrecorded("res://tmp/l14_boulder_moving_save.json").is_empty(),"moving boulder reload"):quit(1);return
   check(trap.state().triggered and absf(trap.state().elapsed-elapsed)<0.02,"boulder motion retained")
   motion_saved=true
  if scene.starting_magic.health()==0:break
 check(motion_saved and trap.state().triggered and scene.starting_magic.health()==0,"actual central walk triggers lethal boulder; no seeded death")
 if not check(scene.apply_save(input.state).is_empty(),"reload earned bypass before fatal choice"):quit(1);return
 prepare(scene)
 for i in 2:await physics_frame
 check(not trap.state().triggered and scene.starting_magic.health()>0,"older earned save restores hazard and health")
 if not await walk(scene,[[-32,850],[-33,1000],[-33,1100],[-33,1250],[-30,1400]],"actual off-centre source side strip"):quit(1);return
 check(not trap.state().triggered and scene.starting_magic.health()>0,"side route avoids original central trigger")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_boulder_side_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_boulder_side_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual central boulder death -> earned reload -> off-centre safe side-strip walk/save-reload")
 quit(0 if failures==0 else 1)
