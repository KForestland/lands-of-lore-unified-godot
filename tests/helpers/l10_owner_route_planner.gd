extends RefCounted
## Read-only route planning. Never writes a player pose or game collision. The
## actual input walk, not this graph, qualifies reachability.
var host:Node3D
var data:Dictionary
var graph:AStar3D
var points:PackedVector3Array
var point_clear:Dictionary={}
var edge_clear:Dictionary={}
var excludes:Array[RID]=[]
var probe:CylinderShape3D
var attempts:=0
func _init(scene:Node3D,source:Dictionary):
 host=scene;data=source;graph=AStar3D.new();points=PackedVector3Array()
 graph.reserve_space(data.nodes.size()+2)
 for row in data.nodes:
  var at:=Vector3(row[0],row[1],row[2]);points.append(at);graph.add_point(points.size()-1,at)
 for link in data.links:graph.connect_points(int(link[0]),int(link[1]))
 excludes.append(host.player.get_rid())
 for body in host.act2_creatures.bodies.values():
  if body is CollisionObject3D:excludes.append(body.get_rid())
 probe=CylinderShape3D.new();probe.radius=8.0;probe.height=6.0
func supported(at:Vector3)->bool:
 var floor_query:=PhysicsRayQueryParameters3D.create(at+Vector3.DOWN*30,at+Vector3.DOWN*36,host.player.collision_mask,excludes)
 var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(floor_query)
 return not hit.is_empty() and hit.normal.y>=0.5
func body_clear(at:Vector3)->bool:
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=probe;query.collision_mask=host.player.collision_mask;query.exclude=excludes;query.margin=0.001
 query.transform=Transform3D(Basis.IDENTITY,Vector3(at.x,at.y-32+5.05,at.z))
 return host.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func free_at(at:Vector3)->bool:return supported(at) and body_clear(at)
func clear_node(id:int)->bool:
 if point_clear.has(id):return point_clear[id]
 var at:Vector3=graph.get_point_position(id)
 var ok:=free_at(at)
 # A native stair quad can be thinner than the body: its centre can touch the
 # next, higher floor. Propose a step; actual W must still prove it. Never
 # raise a goal or player, only this read-only planning node.
 if not ok and id<data.nodes.size() and supported(at):
  var region:String=str(int(data.nodes[id][3]))
  var ceiling:float=float(data.region_ceilings.get(region,1000000))
  for rise in [8.0,16.0,32.0,48.0]:
   if at.y-32+rise+8.25>ceiling:continue
   if body_clear(at+Vector3.UP*rise):
    graph.set_point_position(id,at+Vector3.UP*rise);ok=true;break
 point_clear[id]=ok;return ok
func clear_edge(a:int,b:int)->bool:
 var key:=Vector2i(mini(a,b),maxi(a,b))
 if edge_clear.has(key):return edge_clear[key]
 if not clear_node(a) or not clear_node(b):edge_clear[key]=false;return false
 var pa:Vector3=graph.get_point_position(a);var pb:Vector3=graph.get_point_position(b)
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=probe;query.exclude=excludes;query.collision_mask=host.player.collision_mask;query.margin=0.001
 query.transform=Transform3D(Basis.IDENTITY,Vector3(pa.x,maxf(pa.y,pb.y)-32+5.05,pa.z));query.motion=Vector3(pb.x-pa.x,0,pb.z-pa.z)
 var hit:PackedFloat32Array=host.get_world_3d().direct_space_state.cast_motion(query)
 var clear:bool=hit.size()==2 and hit[0]>=0.9995
 if clear:
  var length:float=Vector2(pb.x-pa.x,pb.z-pa.z).length()
  for step in range(1,int(ceil(length/16.0))):
   var t:float=float(step)/float(ceil(length/16.0));var sample:Vector3=pa.lerp(pb,t)
   var support:=PhysicsRayQueryParameters3D.create(sample+Vector3.DOWN*30,sample+Vector3.DOWN*80,host.player.collision_mask,excludes)
   var ground:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(support)
   if ground.is_empty() or ground.normal.y<0.5:clear=false;break
 edge_clear[key]=clear;return clear
func attach(id:int,at:Vector3)->bool:
 if graph.has_point(id):graph.remove_point(id)
 point_clear.erase(id)
 for key in edge_clear.keys():
  if key.x==id or key.y==id:edge_clear.erase(key)
 graph.add_point(id,at)
 var count:=0
 for region in data.regions.values():
  var polygon:=PackedVector2Array()
  for point in region.polygon:polygon.append(Vector2(point[0],point[1]))
  if not Geometry2D.is_point_in_polygon(Vector2(at.x,at.z),polygon):continue
  for index in region.nodes:
   var node:int=int(index)
   if absf(graph.get_point_position(node).y-at.y)>48:continue
   graph.connect_points(id,node);count+=1
 return count>0
func route(from:Vector3,to:Vector3)->Dictionary:
 var start:int=data.nodes.size();var end:int=start+1
 if not attach(start,from) or not attach(end,to):return {"points":[],"reason":"No native floor-region attachment at the specified storey."}
 var fallback:Array=[]
 for attempt in 600:
  var ids:PackedInt64Array=graph.get_id_path(start,end)
  if ids.is_empty():return {"points":[],"fallback":fallback,"reason":"Native portal graph has no path after actual support/collision probes."}
  if fallback.is_empty():
   for index in range(1,ids.size()):
    var point:Vector3=graph.get_point_position(ids[index]);fallback.append([point.x,point.z])
  var blocked:=false
  for i in ids.size()-1:
   if not clear_edge(ids[i],ids[i+1]):
    graph.disconnect_points(ids[i],ids[i+1]);blocked=true;attempts+=1;break
  if blocked:continue
  var path:Array=[]
  for i in range(1,ids.size()):
   var point:Vector3=graph.get_point_position(ids[i]);path.append([point.x,point.z])
  return {"points":path,"reason":"Read-only native portal planning; actual walk still required.","filtered_edges":attempts}
 return {"points":[],"fallback":fallback,"reason":"Probe budget exhausted; no reachability verdict."}
