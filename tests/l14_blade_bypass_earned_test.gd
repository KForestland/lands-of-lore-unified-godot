extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_flute_covers_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="ce0f1a42e7e7078c30b6d2bb7495c34701e931849ac0e0783198e3ec28f68a41","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 var trap=scene.get_node("L14TrapRoute")
 if not await walk(scene,[[-115,-1660],[-110,-1750],[32,-1800],[170,-1750],[170,-1650],[155,-1540],[145,-1470],[30,-1420],[30,-1360],[30,-1000],[30,-700],[30,-414]],"covered oil physical crossing"):quit(1);return
 scene.camera.look_at(trap.DOORS["81"],Vector3.UP)
 if not check(trap.open_door("81").ok,"original bypass entrance81"):quit(1);return
 if not await walk(scene,[[-160,-414],[-290,-280],[-290,400],[-240,576],[-110,580]],"original right blade bypass"):quit(1);return
 scene.camera.look_at(trap.DOORS["80"],Vector3.UP)
 if not check(trap.open_door("80").ok,"original bypass exit80"):quit(1);return
 if not await walk(scene,[[0,650]],"rejoin original lower hall"):quit(1);return
 check(scene.player.position.y<180,"actual lower bypass floor140")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_blade_bypass_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_blade_bypass_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned flute covers -> actual original lower oil route and right blade bypass -> save/reload")
 quit(0 if failures==0 else 1)
