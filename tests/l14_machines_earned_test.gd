extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_flute_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="854689a47d77b657832dfbd8e5156721b9a68cab618fbc5fca540a3f1f7773e4","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var machine=scene.get_node("L14Machines")
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_machines_walk.json"))
 check(not machine.interact("start").ok,"remote button refused")
 if not await walk(scene,route.table,"original examining table"):quit(1);return
 scene.camera.look_at(machine.BUTTON,Vector3.UP)
 paused=true;check(not machine.interact("start").ok,"paused button refused");paused=false
 if not check(machine.interact("start").ok,"press original pedestal72"):quit(1);return
 for i in 150:await physics_frame
 if not check(machine.state().phase=="ready","actual active-time grinder fills trough"):quit(1);return
 if not await walk(scene,route.box,"original Blood Trough75"):quit(1);return
 scene.camera.look_at(machine.BOX+Vector3.UP*12,Vector3.UP)
 if not check(machine.interact("carry").ok,"carry original world trough"):quit(1);return
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_trough_carried_save.json")
 if not check(error.is_empty(),"carried box save: "+error):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_trough_carried_save.json").is_empty(),"carried box reload"):quit(1);return
 if not await walk(scene,route.machine,"second machine source region3902"):quit(1);return
 if not await walk(scene,[[3240,-3615]],"machine aperture"):quit(1);return
 scene.camera.look_at(machine.INSERT,Vector3.UP)
 check(not machine.interact("insert").ok,"short-edge orientation refused")
 if not check(machine.interact("rotate").ok,"turn carried trough long edge first"):quit(1);return
 check(not machine.interact("insert","wrong").ok,"wrong item refused by Kit")
 check(not machine.interact("insert",machine.BODY,scene.carried_collected.size()).ok,"full output inventory refused without losing box")
 paused=true;check(not machine.interact("insert").ok,"paused insertion refused");paused=false
 if not check(machine.interact("insert").ok,"Kit consumes aligned world trough once"):quit(1);return
 check(not machine.interact("insert").ok,"repeat insertion refused")
 if not await walk(scene,route.catch,"walk around to original machine output"):quit(1);return
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"earned Dreamstone Lizard choice at low output"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual low viewpoint fits output aperture"):quit(1);return
 for i in 1200:
  await physics_frame
  if machine.state().phase=="formed":break
 if not check(machine.state().phase=="formed","machine produces original statue at back"):quit(1);return
 var items=scene.get_node("Act2WorldItems")
 scene.camera.look_at(items.aim_point(machine.STATUE),Vector3.UP)
 if not check(items.take(machine.STATUE),"catch original dormant statue65"):quit(1);return
 check(machine.state().caught and machine.state().phase=="taken","actual catch before landing")
 if not check(passage.choose_form(),"return to Human outside machine"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 check(scene.player_form==0,"Human restored after catch")
 error=scene._quicksave_unrecorded("res://tmp/l14_machines_earned_save.json")
 if not check(error.is_empty(),"machine save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_machines_earned_save.json").is_empty(),"machine reload")
 check(scene.carried_collected.count(machine.STATUE)==1 and scene.carried_collected.count("act2:L14_HT:item77")==1,"same statue and Temple flute retained once")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 print("MACHINE END ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Temple flute -> table/grinder -> Kit oriented trough -> actual statue catch/save-reload")
 quit(0 if failures==0 else 1)
