extends "res://tests/generic_l10_table_input_test.gd"
## Four rendered components, supplied clear grounded stands, held root/NPC
## clocks, real mouse/E/left/F5/F9. No earned-route claim.
func point_for(id:int)->Vector3:
 if scene.progression.hinges.has(id):return scene.progression.hinges[id].transform*scene.progression.mover_bounds[id].get_center()
 var path:String="res://assets/lol2/generated/dragon_level/area.json"
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var bounds:=AABB();var first:=true
 for face in pack.faces:
  if face.get("placement_kind")=="movable" and int(face.get("source_index",-1))==id:
   for p in face.points:
    var v:=Vector3(p[0],p[1],p[2])
    if first:bounds=AABB(v,Vector3.ZERO);first=false
    else:bounds=bounds.expand(v)
 return bounds.get_center()
func vantage(id:int,point:Vector3)->bool:
 for radius in [100.0,120.0,80.0,64.0,48.0]:
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
   var world:Node=scene.get_node_or_null("GenericObjects")
   if world!=null:
    var target:Dictionary=world.aimed()
    if target.get("kind")!="movable" or int(target.get("id",-1))!=id:continue
   print("G03 SAMPLE id=",id," stand=",scene.player.position," aim=",point)
   return true
 return check(false,"A clear grounded input stand exists for movable%d"%id)
func walk_open_door()->bool:
 # Door101 rotates about its published centre. Plain W goes around the open
 # leaf; walking through its centreline would hit the visible open leaf.
 scene.set_physics_process(true)
 for waypoint in [[615.0,-5770.0],[615.0,-5905.0],[583.0,-5905.0]]:
  await aim(Vector3(waypoint[0],scene.camera.global_position.y,waypoint[1]))
  var event:=InputEventKey.new();event.keycode=KEY_W;event.physical_keycode=KEY_W;event.pressed=true
  Input.parse_input_event(event);Input.flush_buffered_events()
  var reached:=false
  for tick in 480:
   await physics_frame
   if Vector2(scene.player.position.x-waypoint[0],scene.player.position.z-waypoint[1]).length()<6.0:reached=true;break
  event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
  for tick in 3:await physics_frame
  if not check(reached and scene.resets==0 and scene.player.is_on_floor() and player_clear(),"Real W clears the visible open door101 without recovery or overlap"):return false
 scene.set_physics_process(false)
 return true
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered G03 Ruins components"):return
 folder="user://tests/generic_l9_rollout";DirAccess.make_dir_recursive_absolute(folder)
 var input:="res://assets/lol2/generated/playtest_starts/c15_l9_dr.json"
 if not await boot("res://scenes/lol2/dragon_level.tscn",input,"02de1113c40d183c3fdd780f205d4c41643a7df6149b857bc68d8f21b5375eda","lol2-restoration-dragon-preview"):return
 for id in [1,55,58,101]:
  var point:=point_for(id)
  if not await vantage(id,point):return
  var before:Dictionary=state(id)
  if id==58:await click()
  else:await key(KEY_E)
  for tick in 180:await physics_frame
  if not check(int(state(id)[Rules.POSITION])>int(before[Rules.POSITION]),"Actual E/left opens Ruins movable%d"%id):return
  if not check(int(state(id)[Rules.PHASE])==1,"Published motion finishes for movable%d"%id):return
  if id==101 and not await walk_open_door():return
  await shot("open%d"%id)
  receipts.append({"id":id,"state":state(id),"stand":str(scene.player.position),"input":"left" if id==58 else "E"})
 await key(KEY_F5)
 if not await load_slot():return
 for receipt in receipts:
  if not check(motion_matches(int(receipt.id),receipt.state),"F9 restores exact generic fields for%d"%int(receipt.id)):return
 if not check(scene.resets==0,"No recovery in supplied grounded components"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipts,"  "));file.close()
 print("PASS G03 L9 four rendered real-input generic rows and F5/F9; disclosed component stands, not an earned route")
 quit()
