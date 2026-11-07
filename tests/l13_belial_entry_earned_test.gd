extends "res://tests/l13_upper_ruloi_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_belial_ring_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="2801b3e6957b91b0a578bd7873d9f266bc81cda8f09ed91c305015ee14541aab","qualified upper ring input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned control103 approach input"):quit(1);return
 prepare(scene)
 for i in 15:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 var entry=scene.get_node("L13Belial")
 scene.camera.look_at(entry.WEB+Vector3.UP*32,Vector3.UP)
 var boss:Dictionary=scene.act2_creatures.state.actors["40"].duplicate(true)
 if not check(entry.enter() and paused,"actual control103 movie admission"):quit(1);return
 check(not scene._quicksave_unrecorded("res://tmp/l13_movie_forbidden_save.json").is_empty(),"movie refuses save")
 for i in 50000:
  await process_frame
  if not entry.playing:break
 if not check(entry.state().entered and not paused,"full original movie finishes and admits arena"):quit(1);return
 check(scene.act2_creatures.state.actors["40"]==boss,"movie freezes living boss")
 check(scene.player.position.distance_to(entry.ARRIVAL)<1,"approved source-coordinate arena transport")
 scene.starting_magic.select_spell("heal")
 var mana:int=scene.starting_magic.magic_state().player.mana
 if not check(scene.starting_magic.cast(3) and entry.state().cured and scene.starting_magic.magic_state().player.mana==mana-3,"first arena action Healing III cures poison with mana debit"):quit(1);return
 for i in 20:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(scene.player.is_on_floor(),"arena admission settles on original floor")
 check(scene._quicksave_unrecorded("res://tmp/l13_belial_entry_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_belial_entry_earned_save.json").is_empty(),"earned arena entry/cure save-reload")
 check(entry.state().cured and scene.act2_creatures.state.actors["40"].health>0,"cure persists with actual boss alive")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 print("ARENA at ",scene.player.position," boss ",scene.act2_creatures.bodies["40"].position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned source103 -> full original movie31 -> approved arena admission -> first action HealingIII -> save-reload")
 quit(0 if failures==0 else 1)
