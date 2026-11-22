extends "res://tests/generic_l10_table_input_test.gd"
## Local rendered visibility/control proof; inherited stand/NPC/clock fixtures
## are conservatively disclosed. This does not claim an earned sitting.
func parts()->Array:
 var out:Array=[]
 for id in Catalog.movables("L10_DC"):
  if not scene.progression.hinges.has(id):continue
  for child:Node in scene.progression.hinges[id].get_children():
   if child is MeshInstance3D:out.append(child)
 for nodes:Array in scene.get_node("GenericObjects").renderer.stateful_meshes.values():out.append_array(nodes)
 return out
func collision_packet()->Dictionary:
 var out:Dictionary={};var queue:Array=[scene]
 while not queue.is_empty():
  var node:Node=queue.pop_back();queue.append_array(node.get_children())
  if node is CollisionObject3D:out[str(node.get_path())]=[node.collision_layer,node.collision_mask,str(node.global_transform)]
  elif node is CollisionShape3D:out[str(node.get_path())]=[node.disabled,node.shape.get_instance_id() if node.shape!=null else 0,str(node.global_transform)]
 return out
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 folder="user://tests/g15_l10_rooms";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://assets/lol2/generated/playtest_starts/c15_l10_dc.json","6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","lol2-restoration-map-L10_DC"):return
 var world:Node=scene.get_node("GenericObjects")
 var lid:Node3D=scene.progression.hinges[107]
 var point:Vector3=lid.transform*scene.progression.mover_bounds[107].get_center()
 if not await stand_for(point,"movable",107):return
 if not check(lid.is_visible_in_tree(),"Lid107 is visible from its real clear-body use stand"):return
 await key(KEY_E)
 for tick in 90:await physics_frame
 if not check(int(state(107)[Rules.PHASE])==1,"Actual E still opens lid107 with room drawing enabled"):return
 await shot("actual_e_lid107")
 var vis:Node=scene.region_visibility
 vis.set_process(false) # Controlled draw fixture, no collision/world writes.
 var before:Dictionary=collision_packet()
 vis.apply({})
 if not check(collision_packet()==before,"Hiding every room changes no collider"):return
 await shot("rooms_hidden")
 # Compare synchronous presentation operations separately from a rendered
 # frame: independent live world actors are allowed to move during a frame.
 before=collision_packet()
 for mesh:MeshInstance3D in parts():
  if not check(not mesh.is_visible_in_tree(),"Unseen room must hide object part "+str(mesh.get_path())):return
 var shown:Dictionary={};var count:=0
 for id in Catalog.movables("L10_DC"):
  if not scene.progression.hinges.has(id):continue
  var placement:PackedByteArray=scene.progression.native.placements["movable:%d"%id]
  var region:int=placement.decode_u16(10);var parent:Node3D=scene.progression.hinges[id]
  if not check(int(parent.get_meta("object_room_region",-1))==region and int(parent.get_meta("object_room",-1))==int(scene.region_cluster[region]),"Mover source-region room binding "+str(id)):return
  shown[region]=true;count+=1
 for id in Catalog.breakables("L10_DC"):
  var row:Dictionary=world.renderer.data.placements[str(id)]
  var region:int=str(row.placement_hex).hex_decode().decode_u16(10)
  for mesh:MeshInstance3D in world.renderer.stateful_meshes[id]:
   if not check(int(mesh.get_parent().get_meta("object_room_region",-1))==region,"Cover source-region wrapper "+str(id)):return
  shown[region]=true;count+=1
 var controllers:Array=[scene]
 var controlled_count:=0
 while not controllers.is_empty():
  var controller:Node=controllers.pop_back();controllers.append_array(controller.get_children())
  if controller.get_script()==null or not str(controller.get_script().resource_path).ends_with("static_assemblies.gd"):continue
  for meshes:Array in controller.stateful_meshes.values():
   if meshes.is_empty():continue
   if not check(meshes[0].get_parent().has_meta("object_rooms"),"Feature-owned source assembly also follows rooms"):return
   controlled_count+=1
 print("ALL CONTROLLED ASSEMBLY ROOMS ",controlled_count)
 if not check(count==85,"All56 movables +29 covers have their actual native rooms, none left always drawn"):return
 vis.apply(shown)
 for mesh:MeshInstance3D in parts():
  if not check(mesh.get_parent().visible,"A drawn room exposes its object parent"):return
 world.renderer.set_present(5,false)
 vis.apply(shown)
 for mesh:MeshInstance3D in world.renderer.stateful_meshes[5]:
  if not check(not mesh.is_visible_in_tree(),"Room visibility never resurrects absent cover5"):return
 vis.apply({})
 world.renderer.set_mode(247,1) # Rebuild selector meshes while their room is hidden.
 for mesh:MeshInstance3D in world.renderer.stateful_meshes[247]:
  if not check(not mesh.is_visible_in_tree(),"Selector rebuild retains hidden room parent"):return
 world.renderer.set_present(5,true)
 if not check(collision_packet()==before,"Room draw/presence/selector fixtures leave every collider/layer/shape/transform unchanged"):return
 vis.last_pose=Transform3D() # Invalidate the camera cache after explicit draw fixtures.
 vis.set_process(true)
 scene.set_physics_process(true)
 for tick in 12:await physics_frame
 scene.set_physics_process(false)
 if not check(lid.is_visible_in_tree() and scene.resets==0,"Normal portal drawing restores the player's lid room with no recovery"):return
 await shot("normal_room_restored")
 print("PASS L10 all85 native object rooms, actual E107, hidden-room draw, absent cover/selector rebuild preserve state, collision unchanged; local fixtures not an earned walk")
 quit()
