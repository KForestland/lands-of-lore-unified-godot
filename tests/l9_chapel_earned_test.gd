extends "res://tests/l10_barrel_earned_test.gd"
func fight_nearby(scene: Node)->bool:
 if scene.resets!=0:return check(false,"fall recovery invalidates earned route")
 return await super.fight_nearby(scene)
func reached_waypoint(scene: Node,label: String,index: int)->void:
 if not check(scene.resets==0,"no fall recovery in earned route"):return
 super.reached_waypoint(scene,label,index)
 if label=="Noble north upstairs" and Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(-1050,-5940))<9:
  check(scene.request_jump(),"real jump from lower channel lip")
 if label=="west bank" and Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(2540,-7855))<9:
  check(scene.request_jump(),"real jump onto upper bank beside source floor350")
 if label=="west bank" and Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(2910,-8310))<9:
  check(scene.request_jump(),"real jump over steep bank seam")
 if label=="west bank" and Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(3125.88,-8243.87))<9:
  check(scene.request_jump(),"real jump onto source upper bank")
 if label=="west bank" and Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(3220,-8245))<9:
  check(scene.request_jump(),"real jump from sloped bank to bridge landing")
func input_save()->String:return "res://tmp/l10_priest_urn_earned_save.json"
func statue_points(route: Dictionary)->Array:return route.statue.points
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual priest urn Cemetery save"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_chapel_walk.json"))
 if not await walk(scene,statue_points(route),"Cemetery mirror statue"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_chapel_statue_earned_save.json").is_empty(),"actual statue approach save")
 var aim_row: Array=scene.progression.exit_objects["control:150"][0].position
 var aim:=Vector3(aim_row[0],aim_row[1],aim_row[2]);scene.camera.look_at(aim,Vector3.UP)
 var target: String=scene.progression.aimed_exit()
 print("STATUE aimed ",target," player",scene.player.position)
 if not check(target=="control:150","production source statue E target"):quit(1);return
 print("STATUE source E ",scene.progression.use_exit(target))
 if not await walk(scene,route.mirror42.points,"source mirror42"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"earned source statue mirror transition"):quit(1);return
 var change: Dictionary=scene.progression.level_changes.back()
 if not check(change.level==9 and change.selector==3,"source Ruins mirror arrival3"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.progression.seeds_applied.is_empty(),"no Ruins arrival seeds")
 check("act2:L10_DC:priest_urn" in scene.carried_collected,"earned urn transported")
 check(scene._quicksave_unrecorded("res://tmp/l9_chapel_gallery_earned_save.json").is_empty(),"actual Ruins gallery urn save")
 if not await walk(scene,route.upstairs.points,"Noble north upstairs"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l9_chapel_upstairs_earned_save.json").is_empty(),"actual upstairs urn save")
 if not await finish_chapel(scene,route):quit(1);return
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned priest urn -> Cemetery mirror -> Noble upstairs -> break source north rail -> west bank -> original bridge -> east tunnel chapel -> actual save/reload")
 quit(0 if failures==0 else 1)
func finish_chapel(scene: Node,route: Dictionary)->bool:
 var rails=scene.get_node("L9NobleRails")
 check(not rails.validate({"version":1,"broken":["480","480"]}).is_empty(),"duplicate saved rail IDs rejected")
 check(not rails.validate({"version":1,"broken":[478]}).is_empty(),"malformed rail IDs rejected")
 check(scene.player.position.y>145,"actual upstairs floor120")
 check(not rails.strike(),"distant strike cannot break rail")
 if not await walk(scene,[[639,-5700],[639,-5655]],"original balcony deck481"):return false
 check(scene.player.position.y>145,"original raised deck supports player")
 scene.camera.look_at(Vector3(639,160,-5596),Vector3.UP)
 paused=true
 check(not rails.strike(),"paused strike refused")
 paused=false
 for i in 45:
  await physics_frame
  scene.move_grounded(Vector3(0,0,1),scene.player.get_physics_process_delta_time())
 check(scene.player.position.z< -5605,"closed source rail blocks north crossing")
 scene.camera.look_at(Vector3(639,160,-5596),Vector3.UP)
 if not check(rails.strike(),"landed melee breaks original north rail480"):return false
 check(not rails.strike(),"duplicate rail strike refused")
 var broken:="res://tmp/l9_north_rail_earned_save.json"
 check(scene._quicksave_unrecorded(broken).is_empty() and scene._quickload_unrecorded(broken).is_empty(),"broken north rail actual save/reload")
 rails.restore()
 check("480" in rails.state().broken and rails.bodies[480].collision_layer==0,"saved broken rail collision follows selector1")
 if not await walk(scene,[[639,-5500]],"north rail exit"):return false
 if not await walk(scene,route.bank.points,"west bank"):return false
 if not check(scene.player.is_on_floor() and scene.player.position.y>65,"grounded source west bridge landing40"):return false
 check(scene._quicksave_unrecorded("res://tmp/l9_west_bridge_earned_save.json").is_empty(),"actual west bridge approach save")
 if not await walk(scene,route.bridge.points,"original bridge471/472"):return false
 check(scene.player.is_on_floor() and scene.player.position.y>65,"bridge reaches source east landing40 above channel")
 if not await walk(scene,route.chapel.points,"east tunnel chapel"):return false
 check("act2:L10_DC:priest_urn" in scene.carried_collected,"empty urn retained for cremation")
 var path:="res://tmp/l9_chapel_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual chapel arrival save/reload")
 check(scene.progression.seeds_applied.is_empty(),"no arrival seeds")
 return failures==0
