extends "res://tests/l9_chapel_earned_test.gd"
func reached_waypoint(_scene: Node,_label: String,_index: int)->void:pass
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l9_statue_fight_earned_save.json","lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual earned fight save"):quit(1);return
 prepare(scene)
 var water=scene.get_node("L9Flood")
 check(water.enabled(),"earned fight starts water")
 var inventory: Array=scene.carried_collected.duplicate()
 for i in 6000:
  await physics_frame
  scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
  scene.curse.advance(scene.player.get_physics_process_delta_time())
  if water.state().breath>=5 or scene.starting_magic.health()<=0:break
 if not check(water.state().breath>=5 and scene.starting_magic.health()>0,"actual rising water submerges corridor player"):quit(1);return
 var saved: Dictionary=water.state().duplicate()
 paused=true
 for i in 60:await process_frame
 check(water.state()==saved,"pause freezes both clocks")
 paused=false
 var path:="res://tmp/l9_flood_submerged_earned_save.json"
 if not check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual submerged save/reload"):quit(1);return
 check(water.state()==saved,"reload preserves water and breath, no free refill")
 for i in 1800:
  await physics_frame
  scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
  if scene.starting_magic.health()<=0:break
 check(water.state().dead and water.state().breath==15 and scene.starting_magic.health()==0,"actual shared drowning limit kills stranded player")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty() and scene.carried_collected==inventory,"no recovery, seeds or inventory changes")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned fight -> actual rising water/submersion -> paused clocks -> saved breath/reload -> drowning; isolated failed-escape branch, no completed escape claim")
 quit(0 if failures==0 else 1)
