extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_bedroom_crack_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="b175cb7b3bff007debca8f47aabc987a207a0fd8a02ac99ed4cb05675b02366d","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var library=scene.get_node("L14Library")
 check(not library.interact(147).ok,"remote second button refused")
 scene.camera.look_at(library.BUTTONS[146],Vector3.UP)
 paused=true;check(not library.interact(146).ok,"paused button refused");paused=false
 if not check(library.interact(146).ok,"press first original hall button146"):quit(1);return
 await physics_frame
 var before:float=library.state().stairs
 paused=true
 for i in 10:await process_frame
 check(library.state().stairs==before,"paused stair clock frozen")
 paused=false
 for i in 160:await physics_frame
 check(not library.interact(146).ok,"repeat first button refused")
 var route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_library_walk.json"))
 if not await walk(scene,route.slice(0,16),"lowered stairs to original low slope"):quit(1);return
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"earned Lizard for steep50-high corridor"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual low slope Lizard"):quit(1);return
 if not await walk(scene,route.slice(18,20),"original low sloped corridor"):quit(1);return
 if not check(passage.choose_form(),"Human beyond slope"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"actual Human second button approach"):quit(1);return
 if not await walk(scene,route.slice(20),"hall to second button"):quit(1);return
 scene.camera.look_at(library.BUTTONS[147],Vector3.UP)
 if not check(library.interact(147).ok,"press second original hall button147"):quit(1);return
 for i in 160:await physics_frame
 check(not library.interact(147).ok,"repeat second button refused")
 if not await walk(scene,[[1940,-4360],[2035,-4360],[2130,-4360]],"opened original barrier1518"):quit(1);return
 check(scene.player.position.y>25 and scene.player.position.y<40,"actual floor0 through library barrier")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_library_earned_save.json")
 if not check(error.is_empty(),"library save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_library_earned_save.json").is_empty(),"library reload")
 check(scene.carried_collected.count("act2:L14_HT:item65")==1 and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"same statue no seeds/recovery")
 print("LIBRARY END ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned lower hall -> buttons146/147 in order -> physical library barrier passage/save-reload")
 quit(0 if failures==0 else 1)
