extends "res://tests/l12_logs_approach_earned_test.gd"
func jump_gap(scene:Node,hop:Dictionary)->bool:
 var centre:=Vector3(hop.centres[0][0],0,hop.centres[0][1])
 var edge:=Vector3(hop.from[0],0,hop.from[1])
 var landing:=Vector3(hop.to[0],0,hop.to[1])
 var far_centre:=Vector3(hop.centres[1][0],0,hop.centres[1][1])
 var launch:Vector3=edge+(centre-edge).normalized()*4
 landing+=(far_centre-landing).normalized()*10
 if not await walk(scene,[[centre.x,centre.z]],"ledge run-up"):return false
 var jumped:=false;var landed:=false
 for tick in 400:
  var goal:Vector3=landing if jumped else launch
  var d:Vector3=goal-scene.player.position;d.y=0
  if not jumped and d.length()<6:
   if not check(scene.request_jump(),"ordinary sprint jump at original ledge"):return false
   jumped=true;d=landing-scene.player.position;d.y=0
   print("LEDGE JUMP ",hop.jump," from ",scene.player.position," to ",landing)
  scene.move_grounded(d.normalized(),1.0/60,true);scene.curse.advance(1.0/60);await physics_frame
  if jumped and scene.player.is_on_floor():landed=true;break
 if not check(jumped and landed and scene.player.position.y-32>=float(hop.landing_floor)-3,"actual raised ledge landing "+str(hop.jump)+" at "+str(scene.player.position)):return false
 return await walk(scene,[[far_centre.x,far_centre.z]],"raised ledge landing centre")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_spiral_slot_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="d2c2c706435236d946a761a120cca8abc5ae6ad73f3d8ac650f2be46bd29c15e","qualified original slot/spiral input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-door approach"):quit(1);return
 prepare(scene)
 var trials=scene.get_node("L14Trials")
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_ledge_maze_walk.json"))
 check(not trials.open_door("90").ok,"remote door refused")
 if not await walk(scene,[[300,-2250],[340,-2185]],"left-hand original NiceDoor90"):quit(1);return
 scene.camera.look_at(trials.DOORS["90"],Vector3.UP)
 var ray=PhysicsRayQueryParameters3D.create(trials.DOORS["90"]-Vector3(25,0,40),trials.DOORS["90"]+Vector3(25,0,40),1,[scene.player.get_rid()])
 check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"original trial door closed collision")
 paused=true;check(not trials.open_door("90").ok,"paused door refuses");paused=false
 if not check(trials.open_door("90").ok,"open original left NiceDoor90"):quit(1);return
 check(not trials.open_door("90").ok,"repeat door cannot shift twice")
 await physics_frame
 check(scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"original trial door opens collision")
 if not await walk(scene,[[400,-2090],[500,-1960]],"through original left door"):quit(1);return
 if not await walk(scene,route.entry,"raised maze entrance"):quit(1);return
 for hop in route.ledges:
  if hop.has("jump"):
   if not await jump_gap(scene,hop):quit(1);return
  elif not await walk(scene,[hop.point],"original raised maze ledges"):quit(1);return
  if not check(scene.player.position.y>110 and scene.resets==0,"stay on raised route, no pit shortcut"):quit(1);return
 if not await walk(scene,route.exit,"maze exit hall to original LifeIdol371"):quit(1);return
 scene.camera.look_at(trials.PRIZE,Vector3.UP)
 check(not trials.take(scene.carried_collected.size()).ok,"full statue pickup refused")
 paused=true;check(not trials.take().ok,"paused statue pickup refused");paused=false
 if not check(trials.take().ok,"take source371 Jkar idol once"):quit(1);return
 check(not trials.take().ok,"duplicate trial statue refused")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_ledge_maze_earned_save.json")
 if not check(error.is_empty(),"maze reward save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_ledge_maze_earned_save.json").is_empty(),"maze reward reload")
 check(trials.IDOL in scene.carried_collected and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"one earned idol/no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned left door -> actual raised ledges/four sprint jumps -> original371 Jkaridol/save-reload")
 quit(0 if failures==0 else 1)
