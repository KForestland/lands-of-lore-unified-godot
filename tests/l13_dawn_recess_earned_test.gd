extends "res://tests/l9_chapel_earned_test.gd"
func jump_into(scene:Node,prison:Node)->bool:
 scene.jump_requested=true
 for i in 150:
  var d:Vector3=prison.PLATE-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>5 else Vector3.ZERO,1.0/60.0,true);await physics_frame
  if prison.entered:break
 return check(prison.entered and paused,"actual Human jump into source prison plate")
func land(scene:Node):
 for i in 120:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player.is_on_floor():break
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_prisons_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="4dbbfb934155d84b532babcc6e3eec36680cd05a9321e8f2a2a385a638a3bfc7","qualified prison input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned prison input"):quit(1);return
 prepare(scene)
 var route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_spires_prison_walk.json"))[-1].points.duplicate(true)
 route.reverse();route.append([-6251,-3061])
 if not await walk(scene,route,"Dawn earned return"):quit(1);return
 var dawn=scene.get_node("L13DawnPrison")
 if not await jump_into(scene,dawn):quit(1);return
 var inventory:Array=scene.carried_collected.duplicate();var quests:Dictionary=scene.quest_state.duplicate(true)
 check(not dawn.offer("").ok,"missing stone refused")
 for item in inventory:check(not dawn.offer(item).ok,"actual non-Dreamstone inventory refused")
 check(inventory==scene.carried_collected and quests==scene.quest_state and not dawn.state().released,"wrong offers do not mutate inventory/world")
 dawn.leave();await land(scene)
 check(scene._quicksave_unrecorded("res://tmp/l13_dawn_recess_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_dawn_recess_earned_save.json").is_empty(),"earned recess save reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned return to Dawn recess -> all actual wrong items refused atomically -> save/reload; positive release awaits earned Dreamstone")
 quit(0 if failures==0 else 1)
