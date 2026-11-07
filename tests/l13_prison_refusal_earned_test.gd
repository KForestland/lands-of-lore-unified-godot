extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_elevator_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="87959d2b6238a1f6fe73eb243f687f18f320e9af79bd7b06f8a082503b41b23e","qualified basin input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned basin input"):quit(1);return
 prepare(scene)
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_prison_walk.json"))
 if not await walk(scene,route.points,"lower prison approach"):quit(1);return
 var prison=scene.get_node("L13Prison")
 check(not prison.enter(),"walking beside circle does not enter")
 scene.jump_requested=true
 for i in 150:
  var d:Vector3=prison.PLATE-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>5 else Vector3.ZERO,1.0/60.0,true)
  await physics_frame
  if prison.entered:break
 if not check(prison.entered and paused,"actual Human jump into source plate opens room"):quit(1);return
 check(not prison.use_switch() and prison.cue=="11" and not prison.state().released,"living Ruloi cause original refusal")
 check(not scene._quicksave_unrecorded("res://tmp/forbidden_prison_save.json").is_empty(),"room save refused")
 for i in 1200:
  await process_frame
  if prison.cue=="999":break
 check(prison.cue=="999","original refusal completes and returns to idle")
 prison.leave()
 # Finish the real jump after closing the room; do not save an artificial floor placement.
 for i in 120:
  scene.move_grounded(Vector3.ZERO,1.0/60.0);await physics_frame
  if scene.player.is_on_floor():break
 check(scene._quicksave_unrecorded("res://tmp/l13_prison_refusal_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_prison_refusal_earned_save.json").is_empty(),"earned visit save/reload")
 check(prison.state().visited and not prison.state().released,"visit persists without premature release")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned lower route/combat -> Human jump into original plate52 -> original maiden refusal while Ruloi live -> actual visit save/reload")
 quit(0 if failures==0 else 1)
