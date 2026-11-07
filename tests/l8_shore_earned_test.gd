extends "res://tests/l9_chapel_earned_test.gd"
func input_save()->String:return "res://tmp/l9_flood_escape_earned_save.json"
func run():
 check(not preload("res://scripts/lol2/act_one_quest_state.gd").validate({"l8_shore":{"version":1,"arrived":true}}).is_empty(),"shore without earned escape refused")
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual completed raft save"):quit(1);return
 prepare(scene)
 var carried:Array=scene.carried_collected.duplicate()
 scene.progression.change_scene_enabled=true
 await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.start_selector==5 and scene.arrived_by_level_change,"native L8 shore arrival")
 check(Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(-4292,-1623))<3,"source shore coordinates")
 check(scene.get_node("L8Shore").closed(scene.quest_state),"ruins closure earned")
 check(scene.act2_creatures.state.actors["20"].present,"original Dawn20 linked")
 check(scene.act2_creatures.bodies["20"].visible,"Dawn physically present")
 check(scene.carried_collected==carried,"no bracer duplication or item loss")
 var path:="res://tmp/l8_shore_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"shore/Dawn save reload")
 check(scene.act2_creatures.state.actors["20"].present and scene.get_node("L8Shore").closed(scene.quest_state),"presence and closure persist")
 var original_scene:int=scene.get_instance_id()
 scene.progression.change_scene_enabled=true
 # Exercise the shared destination gate used by every original Ruins entrance.
 for selector in [0,1,2,3]:
  scene.progression._change_level({"level":9,"selector":selector,"scene":"res://scenes/lol2/dragon_level.tscn"})
  await process_frame
  check(current_scene.get_instance_id()==original_scene,"flooded Ruins entrance refused "+str(selector))
 check(scene.carried_collected==carried and scene.progression.seeds_applied.is_empty(),"closure refusal preserves earned inventory, no seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual raft save -> native shore5 -> Dawn20 -> permanent Ruins closure -> save/reload; no duplicate bracers or inventory merge")
 quit(0 if failures==0 else 1)
