extends "res://tests/generic_l10_table_input_test.gd"
## The existing real-input table, additionally asserting DRAW at each grounded
## usable stand; room membership alone must not make a needed object disappear.
func candidate_drawn(kind:String,id:int)->bool:
 var meshes:Array=[]
 if kind=="movable":
  if scene.progression.hinges.has(id):
   for node:Node in scene.progression.hinges[id].get_children():
    if node is MeshInstance3D:meshes.append(node)
 else:
  var renderer:Node=scene.get_node("GenericObjects").renderer
  if kind=="emperor":renderer=scene.get_node("L10Emperor").renderer
  if renderer.stateful_meshes.has(id):meshes=renderer.stateful_meshes[id]
 if meshes.is_empty():return true
 for mesh:MeshInstance3D in meshes:
  if mesh.is_visible_in_tree():return true
 return false
func stand_for(point:Vector3,kind:String,id:int)->bool:
 if not await super.stand_for(point,kind,id):return false
 for tick in 6:await physics_frame
 var meshes:Array=[]
 if kind=="movable":
  for node:Node in scene.progression.hinges[id].get_children():
   if node is MeshInstance3D:meshes.append(node)
 else:
  var renderer:Node=scene.get_node("GenericObjects").renderer
  if kind=="emperor":renderer=scene.get_node("L10Emperor").renderer
  if renderer.stateful_meshes.has(id):meshes=renderer.stateful_meshes[id]
 if meshes.is_empty():return true # Independent item/actor owners are outside the generic-part draw change.
 var shown:=false
 for mesh:MeshInstance3D in meshes:
  if mesh.is_visible_in_tree():shown=true;break
 if not shown:
  var vis:Node=scene.region_visibility
  var seen:Dictionary={}
  for region in vis.visible_regions:seen[int(vis.cluster_of.get(region,-1))]=true
  for mesh:MeshInstance3D in meshes:print("ROOM DETAIL ",{"kind":kind,"id":id,"mesh":mesh.visible,"parent":mesh.get_parent().visible,"rooms":mesh.get_parent().get_meta("object_rooms",[]),"seen":seen.keys(),"start":vis.last_start,"presence":scene.get_node("GenericObjects").renderer.is_present(id)})
 print("ROOM STAND ",kind,id," drawn=",shown," region=",meshes[0].get_parent().get_meta("object_room_region",-1)," player=",scene.player.position)
 return check(shown,"Player-usable grounded stand must actually DRAW generic part %s%d"%[kind,id])
