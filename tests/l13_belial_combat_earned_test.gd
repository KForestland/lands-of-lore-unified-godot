extends "res://tests/l13_upper_ruloi_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_belial_entry_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="0286c78de6f31d0018b7b177a54dd3cef411bd87a6e899fbf1136bcb8c318423","qualified movie/cure input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned arena input"):quit(1);return
 prepare(scene)
 if not await walk(scene,[[-2850,-2680],[-2700,-2680]],"arena approach"):quit(1);return
 if not await defeat(scene,"40"):quit(1);return
 check(scene.get_node("L13Belial").state().cured and scene.act2_creatures.state.actors["40"].health<=0,"first-action cure then actual boss death")
 check(scene._quicksave_unrecorded("res://tmp/l13_belial_combat_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_belial_combat_earned_save.json").is_empty(),"earned boss combat save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 print("BELIAL defeated at ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned movie/cure -> actual arena approach/combat -> first Belial dead/save-reload")
 quit(0 if failures==0 else 1)
