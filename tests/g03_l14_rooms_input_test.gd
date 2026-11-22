extends "res://tests/generic_l14_rollout_test.gd"
## Local rendered room fixture; supplied grounded stand, held root/NPC clocks.
## Real E then explicit draw sets; every collision property must remain unchanged.
func collision_packet()->Dictionary:
 var result:Dictionary={};var queue:Array=[scene]
 while not queue.is_empty():
  var node:Node=queue.pop_back();queue.append_array(node.get_children())
  if node is CollisionObject3D:result[str(node.get_path())]=[node.collision_layer,node.collision_mask,str(node.global_transform)]
  elif node is CollisionShape3D:result[str(node.get_path())]=[node.disabled,node.shape.get_instance_id() if node.shape!=null else 0,str(node.global_transform)]
 return result
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary Temple room proof"):return
 folder="user://tests/g03_l14_rooms";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L14_HT.tscn","res://assets/lol2/generated/playtest_starts/c15_l14_ht.json","761850f60b460772b31566ff0eb4201caba6e3d6d120ccc590bc64addb317c2f","lol2-restoration-map-L14_HT"):return
 var id:=58;var parent:Node3D=scene.progression.hinges[id]
 if not await vantage(id,point_for(id)):return
 if not check(parent.is_visible_in_tree(),"Real grounded door58 stand draws its room"):return
 await key(KEY_E)
 for tick in 120:await physics_frame
 if not check(int(state(id)[Rules.PHASE])==1,"Real E opens58 with room drawing"):return
 await shot("actual_e58")
 var vis:Node=scene.region_visibility
 vis.set_process(false)
 var before:=collision_packet();vis.apply({})
 if not check(collision_packet()==before,"Hiding all rooms changes no collider"):return
 for key in Catalog.movables("L14_HT"):
  if not check(not scene.progression.hinges[key].is_visible_in_tree(),"Hidden room hides generic mover%d"%key):return
 await shot("all_hidden")
 var shown:Dictionary={}
 for key in Catalog.movables("L14_HT"):
  var placement:PackedByteArray=scene.progression.native.placements["movable:%d"%key]
  var region:int=placement.decode_u16(10);var hinge:Node3D=scene.progression.hinges[key]
  if not check(int(hinge.get_meta("object_room_region",-1))==region and int(hinge.get_meta("object_room",-1))==int(scene.region_cluster[region]),"Exact native Temple room for mover%d"%key):return
  shown[region]=true
 before=collision_packet();vis.apply(shown)
 for key in Catalog.movables("L14_HT"):
  if not check(scene.progression.hinges[key].visible,"Showing its source room draws mover%d"%key):return
 if not check(collision_packet()==before,"Showing rooms changes no body/layer/shape/transform"):return
 if not check(Catalog.movables("L14_HT").size()==14,"All fourteen free Temple movers have room ownership"):return
 vis.last_pose=Transform3D();vis.set_process(true)
 for tick in 12:await physics_frame
 if not check(parent.is_visible_in_tree() and scene.resets==0,"Normal portal drawing resumes the door room without recovery"):return
 await shot("normal_restored")
 print("PASS Temple14 source-room bindings, actualE58, hide/show and normal PVS; every collider unchanged, supplied stand/draw fixtures")
 quit()
