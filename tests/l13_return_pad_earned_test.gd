extends "res://tests/l13_altar_earned_test.gd"
func input_path() -> String:
 return "res://tmp/l13_altar_qualified_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.get_sha256(path)=="d388d0204d82651270990c17e038177e15e05ac0744583b1dab45489a1e2b33b"
func pass_line() -> String:
 return "PASS earned Dreamstone ->physical source54 approach/walk-on ->source return coordinates/equipment/save-reload"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path: String = input_path()
 if not check(input_ready(path),"qualified altar input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned altar input"):quit(1);return
 prepare(scene)
 var pad=scene.get_node("L13ReturnPad")
 check(not pad.enter(),"remote return pad refuses")
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_return_pad_walk.json"))
 # Lead 2026-11-15 (row 0670): control54 is a step-on pad; walking onto it fires it, no jump.
 if not await walk(scene,points.slice(0,points.size()-2),"original return pad54 approach"):quit(1);return
 var items:Array=scene.carried_collected.duplicate()
 var target:=Vector3(points.back()[0],0,points.back()[1])
 var hinted:=false
 for i in 600:
  var d:Vector3=target-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>1 else Vector3.ZERO,1.0/60);await physics_frame;await process_frame
  if pad.hint.text==pad.NEAR_HINT:hinted=true
  if pad.state().used:break
 check(hinted,"near the pad the screen says what it does")
 if not check(pad.state().used and scene.player.position.distance_to(pad.ARRIVAL)<2,"walking onto source54 returns (no jump)"):quit(1);return
 check(scene.carried_collected==items and scene.equipped_item=="act2:L13_RC:dark_sword","return preserves earned equipment and stone")
 for i in 20:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 var error:String=scene._quicksave_unrecorded("res://tmp/l13_return_pad_earned_save.json")
 check(error.is_empty(),"return save: "+error)
 error=scene._quickload_unrecorded("res://tmp/l13_return_pad_earned_save.json");check(error.is_empty(),"return load: "+error)
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 scene.queue_free();await process_frame
 if failures==0:print(pass_line())
 quit(0 if failures==0 else 1)
