extends "res://tests/act2_body_fit_walk.gd"
var fresh_reload_done:=false
func scenario()->String:return "blood"
func proof_folder()->String:return "blood_fresh_reload"
func after_sample()->bool:
 if fresh_reload_done or failed:return not failed
 var fit:Dictionary=scene.player.get_meta("lol2_world_fit",{})
 if not bool(fit.get("active",false)) or float(fit.get("height",46.0))>10.0:return true
 fresh_reload_done=true
 forward(false)
 var position:Vector3=scene.player.position
 var path:=out+"fresh_scene_mid_fit.json"
 if not check(scene._quicksave_unrecorded(path).is_empty(),"save earned pose inside fitted passage"):return false
 var carried:Array=scene.carried_collected.duplicate();carried.sort()
 var form:int=scene.player_form
 var input=Save.read_save(path,"lol2-restoration-map-L19_BC")
 if not check(input.error.is_empty(),"read mid-fit save"):return false
 var previous:Node=scene
 previous.set_physics_process(false)
 previous.queue_free();scene=null;current_scene=null
 await process_frame;await process_frame
 set_meta("lol2_map_start_selector",1)
 scene=load("res://scenes/lol2/maps/L19_BC.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.ready_for_review,"fresh scene ready"):return false
 if not check(scene.apply_save(input.state).is_empty(),"normal load in fresh scene"):return false
 scene.progression.change_scene_enabled=false
 if not check(scene.player.position.distance_to(position)<0.1,"fresh scene restored exact earned pose"):return false
 var restored:Array=scene.carried_collected.duplicate();restored.sort()
 if restored!=carried or scene.player_form!=form:print("FRESH INVENTORY expected ",carried," form ",form," restored ",restored," form ",scene.player_form)
 if not check(restored==carried and scene.player_form==form,"fresh scene retained earned item counts and form"):return false
 if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:await click()
 for i in 3:await physics_frame
 print("FRESH SCENE RELOAD saved ",position," idle ",scene.player.position," fit ",scene.player.get_meta("lol2_world_fit",{}))
 if not check(scene.resets==0 and scene.player.position.distance_to(position)<1.0,"fresh load settles inside passage without recovery displacement"):return false
 proof["fresh_scene_reload"]={"saved_position":[position.x,position.y,position.z],"idle_position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"normal_save_load":true,"resets":scene.resets}
 return true
func run():
 await super.run()
 if not failed:check(fresh_reload_done,"fresh scene reload exercised inside fitted passage")
