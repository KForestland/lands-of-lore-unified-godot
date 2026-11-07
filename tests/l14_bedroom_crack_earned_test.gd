extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_bedroom_approach_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="28eab90768a7e98855bdb35521594ae50b18d499cefb16c401e30b5032ba4c3a","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var space=scene.get_world_3d().direct_space_state
 var down=PhysicsRayQueryParameters3D.create(Vector3(2200,110,-5270),Vector3(2200,85,-5270),1)
 var up=PhysicsRayQueryParameters3D.create(Vector3(2200,85,-5270),Vector3(2200,110,-5270),1)
 check(space.intersect_ray(down).is_empty(),"crack ceiling does not support from above")
 var ceiling:Dictionary=space.intersect_ray(up)
 check(not ceiling.is_empty() and ceiling.position.y>90 and ceiling.position.y<100,"original crack ceiling still blocks from below")
 var head_ray=PhysicsRayQueryParameters3D.create(Vector3(2200,150,-5271),Vector3(2300,150,-5271),1)
 check(not space.intersect_ray(head_ray).is_empty(),"original closed headboard has real collision")
 var bedroom=scene.get_node("L14Bedroom")
 scene.camera.look_at(bedroom.POINT,Vector3.UP)
 paused=true;check(not bedroom.interact().ok,"paused headboard refused");paused=false
 if not check(bedroom.interact().ok,"push original headboard"):quit(1);return
 for i in 160:await physics_frame
 check(not bedroom.interact().ok,"repeat headboard refused")
 check(space.intersect_ray(head_ray).is_empty(),"original headboard collision moves aside")
 if not await walk(scene,[[2200,-5271],[2290,-5271],[2200,-5271]],"opened headboard physical crossing"):quit(1);return
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"earned Lizard bedroom choice"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual Lizard crack body"):quit(1);return
 if not check(scene.request_jump(),"ordinary Lizard hop behind altar"):quit(1);return
 if not await walk(scene,[[2100,-5272]],"hop to west crack lip"):quit(1);return
 print("CRACK LIP ",scene.player.position)
 if not await walk(scene,[[2200,-5272],[2350,-5290],[2420,-5270],[2440,-5270]],"Lizard low crack"):quit(1);return
 print("CRACK LOWER ",scene.player.position)
 if not check(scene.player.position.y<50,"actual lower corridor floor, not overlapping upper floor"):quit(1);return
 if not check(passage.choose_form(),"Human after crack"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"Human lower hall"):quit(1);return
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_bedroom_crack_earned_save.json")
 if not check(error.is_empty(),"crack save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_bedroom_crack_earned_save.json").is_empty(),"crack reload")
 check(scene.carried_collected.count("act2:L14_HT:item65")==1 and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"same statue no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned headboard crossing -> Lizard hop/crack -> Human lower hall/save-reload")
 quit(0 if failures==0 else 1)
