extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_hopper_platform_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="f594ccfa6a5c7526b4be0d2a74ab6d1e125f8ea0288dcb2494d23e3f91e670d6","qualified weighted platform descent"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned weighted platform input"):quit(1);return
 prepare(scene)
 var puzzle=scene.get_node("L14Belial")
 paused=true;check(not puzzle.enter(),"paused elevator admission refuses");paused=false
 if not await walk(scene,[[25,5920]],"physical weighted-platform trigger approach"):quit(1);return
 if not check(puzzle.enter(),"source elevator transition from earned weighted floor"):quit(1);return
 check(not puzzle.enter(),"repeat admission refuses")
 for i in 30:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(scene.player.is_on_floor() and absf(scene.player.position.y-22)<2 and scene.player.position.distance_to(Vector3(42,22,11041))<4,"source lowered landing supports arrival")
 if not await walk(scene,[[42,11110],[42,11200]],"actual chamber approach after source transition"):quit(1);return
 var pop=scene.act2_creatures
 var original_hp:int=pop.state.actors["90"].health
 check(not pop.receive_damage("90",12),"unadmitted boss refuses strike")
 if not await walk(scene,[[42,11220],[42,11290]],"actual boss approach"):quit(1);return
 paused=true;check(not puzzle.talk(),"paused conversation refuses");paused=false
 check(puzzle.talk() and not puzzle.talk(),"local confrontation once")
 check(not pop.receive_damage("90",12) and pop.state.actors["90"].health==original_hp,"human cannot wound boss")
 var health:int=scene.starting_magic.health()
 check(not pop.receive_damage("90",1,false) and pop.state.actors["90"].health==original_hp and scene.starting_magic.health()==health-1,"ranged attack reflected")
 if not check(puzzle.choose_form(),"earned Dreamstone Beast choice"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==1:break
 if scene.player_form!=1:
  var q:=PhysicsShapeQueryParameters3D.new();q.shape=preload("res://scripts/lol2/player_form_body.gd").shape_for(1);q.transform=Transform3D(Basis.IDENTITY,scene.player.position+Vector3.UP*2.5);q.collision_mask=scene.player.collision_mask;q.exclude=[scene.player.get_rid()]
  print("MORPH BLOCK ",scene.player.position," curse ",scene.curse.state," health ",scene.starting_magic.health())
  for hit in scene.get_world_3d().direct_space_state.intersect_shape(q):print("MORPH HIT ",hit.collider.get_path())
 if not check(scene.player_form==1,"actual Beast morph"):quit(1);return
 for i in 2400:
  if pop.state.actors["90"].health<=0:break
  if not check(scene.starting_magic.health()>0,"Beast survives actual combat"):quit(1);return
  scene.camera.look_at(pop.bodies["90"].position+Vector3.UP*24,Vector3.UP)
  pop.strike();scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 if not check(pop.state.actors["90"].health==0,"real Beast melee defeats boss"):quit(1);return
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_belial_combat_earned_save.json")
 if not check(error.is_empty(),"lower-hall approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_belial_combat_earned_save.json").is_empty(),"lower-hall approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("LOWER HALL APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned elevator transition -> actual confrontation -> Beast morph/melee defeat/save-reload")
 quit(0 if failures==0 else 1)
