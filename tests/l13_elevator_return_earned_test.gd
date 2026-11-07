extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_prison_refusal_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="088a585e66e5b5465414d3c35ca9338a7f8686f7201a7a6d6f5dea4cadef9733","qualified prison refusal input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned prison refusal input"):quit(1);return
 prepare(scene)
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_prison_walk.json")).points
 points.reverse();points.append_array([[-4839,2240],[-4839,2600],[-4860,2820],[-4860,3090]])
 if not await walk(scene,points,"return to elevator"):quit(1);return
 var lift=scene.get_node("L13Elevator")
 scene.camera.look_at(lift.aim(),Vector3.UP);scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast() and lift.state().motion.remaining>0,"real Spark starts authorized return"):quit(1);return
 check(not lift.activate(),"moving lift refuses retrigger")
 var y:float=lift.state().motion.height;paused=true
 for i in 12:await process_frame
 check(lift.state().motion.height==y,"paused return does not move");paused=false
 for i in 120:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(scene._quicksave_unrecorded("res://tmp/l13_elevator_rising_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_elevator_rising_earned_save.json").is_empty(),"actual rising save/reload")
 for i in 900:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if lift.state().motion.remaining==0:break
 if not check(lift.state().motion.height==-40 and absf(scene.player.position.y+8)<8,"physical ride reaches original upper endpoint"):quit(1);return
 if not await walk(scene,[[-4860,3200],[-4780,3300],[-4740,3500]],"upper landing"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l13_elevator_return_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_elevator_return_earned_save.json").is_empty(),"earned upper return save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no teleport seed or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned prison refusal -> physical return walk -> actual Spark elevator rise -> mid-motion reload -> original upper landing")
 quit(0 if failures==0 else 1)
