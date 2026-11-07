extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_priest_supplies_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="f83523a56f2884e1b0766dfbf8d6db565bf349737110e65f729080f5de36c196","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var ritual=scene.get_node("L14PriestRitual")
 for pt in [Vector3(2300,80,-3400),Vector3(2500,80,-3450)]:
  var ray:=PhysicsRayQueryParameters3D.create(pt,pt-Vector3.UP*180,1)
  var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
  print("RITUAL FLOOR BEFORE ",pt," ",hit.get("position")," ",hit.get("collider"))
  check(not hit.is_empty() and absf(hit.position.y)<0.1,"actual original floor0 before ritual")
 var before:Array=scene.carried_collected.duplicate()
 check(not ritual.offer("370","act2:L14_HT:item68").ok and scene.carried_collected==before,"remote bowl refused without loss")
 check(not ritual.spark(1),"premature Spark refuses")
 if not await walk(scene,[[2300,-3450],[2375,-3605]],"west ritual bowl"):quit(1);return
 scene.camera.look_at(ritual.BOWLS["370"],Vector3.UP)
 check(not ritual.offer("370","act2:L14_HT:item72").ok and scene.carried_collected==before,"wrong poison in west bowl refused")
 paused=true;check(not ritual.offer("370","act2:L14_HT:item68").ok,"paused bowl refused");paused=false
 if not check(ritual.offer("370","act2:L14_HT:item68").ok,"Kit aloe west370"):quit(1);return
 check(ritual.state().lowered==0,"one bowl cannot lower floor")
 check(scene._quicksave_unrecorded("res://tmp/l14_ritual_one_bowl_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l14_ritual_one_bowl_save.json").is_empty(),"one bowl save/reload")
 if not await walk(scene,[[2441,-3605]],"east ritual bowl"):quit(1);return
 scene.camera.look_at(ritual.BOWLS["369"],Vector3.UP)
 if not check(ritual.offer("369","act2:L14_HT:item72").ok,"Kit poison east369"):quit(1);return
 var lowered:float=ritual.state().lowered
 paused=true
 for i in 10:await process_frame
 check(ritual.state().lowered==lowered,"paused floor motion");paused=false
 for i in 180:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if ritual.state().lowered>=2:break
 for pt in [Vector3(2300,80,-3400),Vector3(2500,80,-3450)]:
  var ray:=PhysicsRayQueryParameters3D.create(pt,pt-Vector3.UP*180,1)
  var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
  print("RITUAL FLOOR AFTER ",pt," ",hit.get("position")," ",hit.get("collider"))
  check(not hit.is_empty() and absf(hit.position.y+30)<0.1,"actual original floor collision lowered30")
 check(ritual.state().lowered==2,"original22 unique floor targets reached")
 check(scene._quicksave_unrecorded("res://tmp/l14_ritual_lowered_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l14_ritual_lowered_save.json").is_empty(),"lowered floor save/reload")
 if not await walk(scene,[[2500,-3480],[2480,-3328]],"return to priest slab"):quit(1);return
 scene.camera.look_at(ritual.SPARK,Vector3.UP)
 for i in 180:
  await physics_frame
  if scene.starting_magic.magic_state().cooldown<=0:break
 scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast(),"actual Spark at placed body"):quit(1);return
 await physics_frame
 if not check(ritual.state().vanished,"actual Spark removes priest"):quit(1);return
 check(not ritual.spark(1),"no repeated body removal")
 check(scene._quicksave_unrecorded("res://tmp/l14_priest_ritual_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l14_priest_ritual_earned_save.json").is_empty(),"finished ritual save/reload")
 check("act2:L14_HT:item68" not in scene.carried_collected and "act2:L14_HT:item72" not in scene.carried_collected,"each original ingredient held in its bowl")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned priest and supplies -> Kit west aloe/east poison -> source floor descent -> actual Spark removes body/save-reload")
 quit(0 if failures==0 else 1)
