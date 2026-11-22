extends "res://tests/generic_l9_rollout_test.gd"
## Rendered Belial components. Supplied clear grounded stands, held root/NPC
## clocks; real E/left/F5/F9, pinned earned C15. No earned-route claim.
func point_for(id:int)->Vector3:
 if scene.progression.hinges.has(id):return scene.progression.hinges[id].transform*scene.progression.mover_bounds[id].get_center()
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
 var bounds:=AABB();var first:=true
 for face in pack.faces:
  if face.get("placement_kind")=="movable" and int(face.get("source_index",-1))==id:
   for point in face.points:
    var v:=Vector3(point[0],point[1],point[2])
    if first:bounds=AABB(v,Vector3.ZERO);first=false
    else:bounds=bounds.expand(v)
 return bounds.get_center()
func vantage(id:int,point:Vector3)->bool:
 for radius in [120.0,100.0,80.0,64.0,48.0]:
  for direction in 24:
   var side:Vector3=point+Vector3(sin(direction*TAU/24),0,cos(direction*TAU/24))*radius
   var ray:=PhysicsRayQueryParameters3D.create(side+Vector3.UP*10,side-Vector3.UP*240,1|256,[scene.player.get_rid()])
   var floor_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
   if floor_hit.is_empty() or floor_hit.normal.y<0.7:continue
   var at:Vector3=floor_hit.position+Vector3.UP*32.05
   if not free_at(at):continue
   if not await pose(at,point):return false
   if not player_clear():continue
   await aim(point)
   var target:Dictionary=scene.get_node("GenericObjects/GenericWorld").aimed()
   if target.get("kind")=="movable" and int(target.get("id",-1))==id:
    print("G03 BELIAL SAMPLE ",id," stand=",scene.player.position);return true
 return check(false,"Clear grounded visible Belial movable%d"%id)
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary Belial object components"):return
 folder="user://tests/generic_l19_rollout";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L19_BC.tscn","res://assets/lol2/generated/playtest_starts/c15_l19_bc.json","f2cdf6b46a4701cc06a8987899f1510059f42eb4bc0400dd9a7e65fcf0017755","lol2-restoration-map-L19_BC"):return
 scene.progression.change_scene_enabled=false # Isolate supplied local stands from the real return-to-Caverns trigger.
 var world:Node=scene.get_node("GenericObjects/GenericWorld")
 if not check(not Catalog.movables("L19_BC").has(74) and not Catalog.movables("L19_BC").has(75) and not Catalog.movables("L19_BC").has(76),"All three bow receivers remain exclusively owned; use cannot bypass shots"):return
 if not check(world.dedicated_movers.has(73),"Native guide-door73 owner keeps priority over raw kind4 fallback"):return
 var horn:Node=scene.get_node("L19BelialHorn")
 if not await pose(Vector3(120,32.05,350),horn.AIM):return
 await aim(horn.AIM)
 if not check(not world.would_use(),"The authored wall occludes the low-rim pipe; no invisible left-use target"):return
 await click()
 if not check(not horn.state().taken,"Left at the occluding wall does not grant the horn"):return
 await key(KEY_E)
 if not check(horn.state().taken and scene.carried_collected.count(horn.ITEM)==1 ,"Original real E takes the horn through its existing grounded-rim adapter once"):return
 await shot("horn_taken")
 for id in [56,55]:
  if not await vantage(id,point_for(id)):return
  var before:=state(id)
  if not check(int(before[Rules.PHASE])==(0 if id==56 else 1),"Native paired-door precondition for%d"%id):return
  if id==55:await key(KEY_E)
  else:await click()
  for tick in 180:await physics_frame
  print("PAIRED_DOOR ",id," before=",before," after55=",state(55)," after56=",state(56))
  for leaf in [55,56]:
   if not check(int(state(leaf)[Rules.PHASE])==(1 if id==56 else 5) and (int(state(leaf)[Rules.POSITION])>0 if id==56 else int(state(leaf)[Rules.POSITION])==0),"Native paired55/56 both open on real left56, both close on realE55"):return
  receipts.append({"id":id,"state":state(id),"stand":str(scene.player.position),"input":"E" if id==55 else "left"})
  await shot("open%d"%id)
 var drain:Node=scene.get_node("L19DrainPath")
 var stand:Vector3=Vector3(2571,-58,-869)
 var point:Vector3=scene.progression.hinges[51].global_transform*scene.progression.mover_bounds[51].get_center()
 if not await pose(stand,point):return
 await aim(point)
 if not check(player_clear(),"Golden Door actual-left fixture starts in clear ground space"):return
 if not check(world.other_aimed().get("owner")==drain,"Real Golden Door aim delegates to its original quest owner"):return
 await click()
 if not check(drain.state().door_clicked and drain.doors_open(),"Actual left opens original Golden Door pair51/52 through its owner"):return
 await shot("golden_open")
 print("GOLD OPEN stand=",scene.player.position," clear=",player_clear())
 # Opening the physical leaf reconciles support on live physics. Retire
 # toward the original prefix end; the supplied stand is already past its
 # two near-door points, so do not backtrack into the open leaf.
 scene.set_physics_process(true)
 for tick in 6:await physics_frame
 for waypoint in [drain.WALK[-1]]:
  await aim(Vector3(waypoint[0],scene.camera.global_position.y,waypoint[1]))
  var step:=InputEventKey.new();step.keycode=KEY_W;step.physical_keycode=KEY_W;step.pressed=true
  Input.parse_input_event(step);Input.flush_buffered_events()
  var reached:=false
  for tick in 480:
   await physics_frame
   if Vector2(scene.player.position.x-waypoint[0],scene.player.position.z-waypoint[1]).length()<8.0:reached=true;break
  step.pressed=false;Input.parse_input_event(step);Input.flush_buffered_events()
  for tick in 6:await physics_frame
  print("GOLD WALK waypoint=",waypoint," reached=",reached," body=",scene.player.position," floor=",scene.player.is_on_floor()," resets=",scene.resets," clear=",player_clear()," contacts=",scene.player.get_slide_collision_count())
  if not check(reached and scene.resets==0 and scene.player.is_on_floor() and player_clear(),"Real W retires to the original prefix end without overlap or recovery"):return
 scene.set_physics_process(false)
 var final_states:Dictionary={55:state(55),56:state(56)}
 await key(KEY_F5)
 if not await load_slot():return
 for row in receipts:
  if not check(motion_matches(int(row.id),final_states[int(row.id)]),"F9 restores exact Belial motion%d"%int(row.id)):return
 if not check(scene.get_node("L19DrainPath").state().door_clicked and scene.get_node("L19DrainPath").doors_open(),"F9 keeps the Golden Door quest receipt and open pair"):return
 if not check(scene.carried_collected.count("act2:L19_BC:horn")==1 and scene.quest_state.l19_belial_horn.taken and scene.resets==0,"F9 keeps horn once and no recovery"):return
 print("PASS Belial four rendered real-input objects55/56/51/222 (three new use bindings) and F5/F9; supplied grounded component stands")
 quit()
