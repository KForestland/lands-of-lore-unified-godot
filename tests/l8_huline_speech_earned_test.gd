extends "res://tests/l8_gift_earned_test.gd"
const Speech=preload("res://scripts/lol2/l8_huline_speech_state.gd")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/dampen_darker_arrival_regression_anchor.json"
 if not check(FileAccess.get_sha256(path)=="b8b36f01602041be97deb36e307de2c92d1fc375a415d771561edb8bd6d6ecc9","actual earned Dawn departure anchor"):quit(1);return
 var input:=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_darker_resume",input.state)
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 scene.player.set_physics_process(false);scene.set_physics_process(false);scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var speech=scene.get_node("L8HulineSpeech");var before:Array=scene.carried_collected.duplicate()
 check(not speech.start("93") and not speech.start("missing"),"remote/invalid speech refused")
 await approach_entry(scene,scene.get_node("L8Journey"))
 for id in ["93","92"]:
  scene.camera.look_at(scene.act2_creatures.bodies[id].position+Vector3.UP*45,Vector3.UP)
  paused=true;check(not speech.start(id),"paused speech refused");paused=false
  if not check(speech.start(id),"physical original speech actor"+id):quit(1);return
  check(speech.voice.playing and speech.voice.stream!=null,"original WAV playing")
  check(scene.actor_input_locked() and not scene.starting_magic.world_active(),"speech holds movement and world consumers")
  for i in 6:await physics_frame
  var elapsed:float=speech.state().elapsed
  paused=true
  for i in 6:await process_frame
  check(is_equal_approx(speech.state().elapsed,elapsed) and speech.voice.stream_paused,"pause holds audio and saved clock");paused=false
  var mid:="res://tmp/l8_huline_speech_mid_earned_save.json"
  var error:String=scene._quicksave_unrecorded(mid)
  if not check(error.is_empty(),"speech mid-save: "+error):quit(1);return
  if not check(scene._quickload_unrecorded(mid).is_empty(),"speech mid-load"):quit(1);return
  for i in 600:
   await physics_frame
   if not speech.input_locked():break
  check(id in speech.state().heard and not speech.start(id),"speech receipt completes once")
  check(not scene.actor_input_locked(),"speech releases movement")
 check(scene.carried_collected==before,"conversation preserves earned inventory")
 var end:="res://tmp/l8_huline_speech_earned_save.json"
 check(scene._quicksave_unrecorded(end).is_empty(),"heard speech save")
 check(scene._quickload_unrecorded(end).is_empty(),"heard speech reload")
 check(speech.state().heard==["93","92"] and not speech.input_locked(),"reload does not replay completed voices")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no resets or seeds")
 # Separate actual arena checkpoint: replace the entire scene save, never merge inventories.
 var arena:=Save.read_save("res://tmp/act2_wild_village_qualified/l8_initiation_earned_save.json","lol2-restoration-darker-jungle")
 if not check(arena.error.is_empty(),"earned arena branch"):quit(1);return
 if not check(scene.apply_save(arena.state).is_empty(),"replace entire save with separate arena branch"):quit(1);return
 before=scene.carried_collected.duplicate()
 scene.camera.look_at(scene.act2_creatures.bodies["23"].position+Vector3.UP*45,Vector3.UP)
 if not check(speech.start("23"),"original post-bout Daniel cue"):quit(1);return
 for i in 600:
  await physics_frame
  if not speech.input_locked():break
 check(speech.state().heard==["23"] and scene.carried_collected==before,"separate arena speech preserves its own earned inventory")
 check(scene._quicksave_unrecorded("res://tmp/l8_huline_arena_speech_earned_save.json").is_empty(),"separate arena speech save")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned first-arrival walk -> original actor93/92 voices -> pause/mid-save/reload/one-shot completion; native conversation triggers remain adapters")
 quit(0 if failures==0 else 1)
