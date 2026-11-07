extends "res://tests/l9_chapel_earned_test.gd"
func defeat(scene:Node,id:String)->bool:
 var pop=scene.act2_creatures
 for tick in 18000:
  if pop.state.actors[id].health<=0:return true
  if not check(scene.starting_magic.health()>0,"survived Ruloi circuit"):return false
  var aim:Vector3=pop.bodies[id].global_position+Vector3.UP*24
  scene.camera.look_at(aim,Vector3.UP)
  var q:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,aim,3,[scene.player.get_rid()])
  var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(q)
  var clear:bool=not hit.is_empty() and hit.collider==pop.bodies[id]
  if scene.starting_magic.health()<18:
   scene.starting_magic.select_spell("heal");scene.starting_magic.cast()
  elif clear:
   if pop.aimed()==id:pop.strike()
   scene.starting_magic.select_spell("spark");scene.starting_magic.cast(3 if scene.camera.global_position.distance_to(aim)>350 else 1)
  scene.move_grounded(Vector3.ZERO,1.0/60.0);await physics_frame
  if tick%1200==0:print("RULOI ",id," HP ",pop.state.actors[id].health," player ",scene.player.position," target ",aim," mana ",scene.starting_magic.magic_state().player.mana)
 return check(false,"Ruloi combat timeout "+id)
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_elevator_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="37176fff126d89f619d2be5aca4664f4fd79f54cbaf47e82689003ae8aae9a6b","qualified upper return input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned upper return input"):quit(1);return
 prepare(scene)
 if not await walk(scene,[[-4780,3300],[-4860,3200],[-4860,3090]],"open lift shaft sightline"):quit(1);return
 if not await defeat(scene,"22"):quit(1);return
 if not await walk(scene,[[-4860,3200],[-4780,3300],[-4740,3500]],"upper landing return"):quit(1);return
 var legs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_upper_ruloi_walk.json"))
 if not await walk(scene,legs[0].points,"upper chamber Ruloi"):quit(1);return
 if not await defeat(scene,"37"):quit(1);return
 if not await walk(scene,legs[1].points,"upper entrance Ruloi"):quit(1);return
 if not await defeat(scene,"39"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l13_upper_ruloi_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_upper_ruloi_earned_save.json").is_empty(),"earned upper Ruloi save/reload")
 for id in ["22","37","39"]:check(scene.act2_creatures.state.actors[id].health==0,"actual upper Ruloi dead "+id)
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned elevator return -> production combat upper Ruloi22/37/39 -> physical circuit/save-reload")
 quit(0 if failures==0 else 1)
