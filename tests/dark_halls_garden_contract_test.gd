extends SceneTree
## Geometry/lifecycle component. No earned-walk claim. Runtime downward and
## under-bed loads are covered by the separate actual-input case.
func _initialize():run.call_deferred()
func run():
 var scene=load("res://scenes/lol2/dark_halls.tscn").instantiate();root.add_child(scene);current_scene=scene
 for i in 60:await process_frame
 scene.set_physics_process(false)
 var atrium:Node=scene.get_node("DarkHallsAtrium")
 var body:StaticBody3D=atrium.get_node("GardenBedFloorCollision")
 var terrain:StaticBody3D
 for child in scene.get_children():
  if not child is StaticBody3D or child.name=="RegionBlockers":continue
  for shape in child.get_children():
   if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:terrain=child;break
  if terrain!=null:break
 assert(terrain!=null and body.collision_layer==terrain.collision_layer and body.collision_mask==terrain.collision_mask,"Garden copies every terrain collision bit")
 var shape:ConcavePolygonShape3D=body.get_child(0).shape
 assert(shape.backface_collision==terrain.get_child(0).shape.backface_collision,"Garden matches the existing two-sided terrain")
 var faces:PackedVector3Array=shape.get_faces();assert(faces.size()==144)
 var drawn:=PackedVector3Array()
 for mesh:MeshInstance3D in atrium.bed_meshes:
  var arrays:Array=mesh.mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var indices:Variant=arrays[Mesh.ARRAY_INDEX]
  if not indices is PackedInt32Array or indices.is_empty():drawn.append_array(vertices)
  else:
   for index in indices:drawn.append(vertices[index])
 assert(drawn.to_byte_array()==faces.to_byte_array(),"Drawn and solid triangles are identical, same native coordinates")
 var body_id:int=body.get_instance_id();var before:PackedByteArray=faces.to_byte_array()
 assert(atrium.open_roof())
 assert(body.get_instance_id()==body_id and body.get_child(0).shape.get_faces().to_byte_array()==before,"Soil to grass never rebuilds/removes its collision")
 atrium.restore_from_quests()
 assert(body.get_instance_id()==body_id and body.get_child(0).shape.get_faces().to_byte_array()==before,"Saved open-state projection never rebuilds its collision")
 print("PASS R142 inherited terrain bits/two-sided policy,144 shared render/collision vertices, identity coordinates and same collision through open/restore; geometry component, not a campaign walk")
 quit()
