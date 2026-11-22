extends "res://tests/generic_l9_rollout_test.gd"
## Three original attached primitive children: supplied clear grounded stands,
## held root/NPC clocks, actual E/left/F5/F9, no new walk collision or terrain.
var primitives:Dictionary={}
func entry_for(id:int)->Array:return scene.prop_placements[-1-int(primitives[id].index)]
func shown_position(id:int)->Vector3:
 var entry:=entry_for(id)
 return (entry[0] as MultiMesh).get_instance_transform(int(entry[1])).origin
func center(id:int)->Vector3:
 var row:Dictionary=primitives[id].row
 return shown_position(id)+Vector3.UP*(float(row.top)+float(row.bottom))*0.5
func terrain_hash()->String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
 for body in scene.get_children():
  if not body is StaticBody3D or body.name=="HeightBoundaryCollision":continue
  for collider in body.get_children():
   if collider is CollisionShape3D and collider.shape is ConcavePolygonShape3D:hash.update(collider.shape.get_faces().to_byte_array())
 return hash.finish().hex_encode()
func primitive_stand(id:int)->bool:
 var point:=center(id)
 for radius in [64.0,80.0,48.0,100.0]:
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
   var los:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,point,3,[scene.player.get_rid()])
   if not scene.get_world_3d().direct_space_state.intersect_ray(los).is_empty():continue
   if scene.camera.is_position_behind(point):continue
   print("TYPE1 stand",id," ",scene.player.position," point",point)
   return true
 return check(false,"Clear grounded view of original primitive%d"%id)
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock1/60"):return
 folder="user://tests/generic_l9_primitive";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/dragon_level.tscn","res://assets/lol2/generated/playtest_starts/c15_l9_dr.json","02de1113c40d183c3fdd780f205d4c41643a7df6149b857bc68d8f21b5375eda","lol2-restoration-dragon-preview"):return
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
 for i in pack.props.size():
  var row:Dictionary=pack.props[i]
  if typeof(row.get("placement")) in [TYPE_INT,TYPE_FLOAT] and int(row.placement) in [0,3,4] and int(row.get("child_type",-1))==1:primitives[int(row.placement)]={"index":i,"row":row}
 if not check(primitives.size()==3,"Three original type1 rows, not fabricated faces"):return
 var hash_before:=terrain_hash()
 print("TYPE1 TERRAIN ",hash_before)
 for id in [0,3,4]:
  if not await primitive_stand(id):return
  var original:=shown_position(id)
  var before:=state(id)
  await shot("before%d"%id)
  if id==4:await click()
  else:await key(KEY_E)
  for tick in 90:await physics_frame
  if not check(int(state(id)[Rules.POSITION])>int(before[Rules.POSITION]) and int(state(id)[Rules.PHASE])==1,"Actual E/left moves source primitive%d"%id):return
  var delta:=shown_position(id)-original
  if not check(delta.is_equal_approx(Vector3.UP*20),"Actual drawn primitive follows published20-unit rise%d"%id):return
  if not check(scene.progression.hinges.has(id) and not scene.progression.mover_bodies.has(id),"Primitive has motion owner, no invented walk body%d"%id):return
  receipts.append({"id":id,"state":state(id),"shown":str(shown_position(id)),"input":"left" if id==4 else "E","stand":str(scene.player.position)})
  await shot("raised%d"%id)
 await key(KEY_F5)
 if not await load_slot():return
 for receipt in receipts:
  var id:int=int(receipt.id)
  if not check(motion_matches(id,receipt.state) and shown_position(id).is_equal_approx(Vector3(primitives[id].row.position[0],primitives[id].row.position[1]+20,primitives[id].row.position[2])),"F9 keeps native fields and drawn primitive pose%d"%id):return
 if not check(terrain_hash()==hash_before and scene.resets==0,"Terrain collision bytes unchanged across use/F9, no recovery"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify({"terrain_sha256":hash_before,"rows":receipts},"  "));file.close()
 print("PASS L9 type1 primitives0/3/4 real E/E/left, drawn20-unit motion, no new walk bodies, exact native/drawn F5F9 and unchanged terrain hash; supplied grounded stands")
 quit()
