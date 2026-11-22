extends "res://tests/helpers/g15_spell_input.gd"
## Local receiver component, not an earned walk: one explicit stand-placement
## source site (possibly called repeatedly), learned/prerequisite fixtures are
## declared in each leaf. After settling, keys/mouse drive the actual receiver.
func boot_map(area_name:String)->bool:
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock1/60"):return false
 scene=load("res://scenes/lol2/maps/"+area_name+".tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for tick in 2400:
  await process_frame
  if scene.ready_for_review:break
 if not require(scene.ready_for_review,"Production area owners ready"):return false
 use_guard=false;await adopt()
 if not captured():await lclick();await frames(3)
 return require(hp()>0 and scene.resets==0 and not scene.flying and captured(),"Living production area component")
func stand_at(point:Vector3)->bool:
 # This is intentionally an audited position aid, never advertised as walking.
 scene.player.global_position=point;scene.player.velocity=Vector3.ZERO
 for tick in 90:
  await physics_frame
  if tick>=5 and scene.player.is_on_floor():break
 return require(scene.player.is_on_floor() and hp()>0 and scene.resets==0,"Disclosed stand settles on a real floor without recovery: "+str(point))
