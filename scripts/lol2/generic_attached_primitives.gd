extends RefCounted
## Sprite-only movables stay on their original primitive/batch/material.
## This bridge projects a parent's motion and targets its drawn rectangle;
## it creates no mesh substitute, collision volume, selector or story effect.
static func collect(host:Node3D,pack:Dictionary,owners:Dictionary)->Dictionary:
 var result:Dictionary={}
 # Existing mixed mesh objects keep their current part ownership. This
 # admission fills the missing sprite-only class without taking those parts.
 var needed:Dictionary=owners.duplicate()
 for face:Dictionary in pack.get("faces",[]):
  if face.get("kind")=="movable" and face.get("placement_kind")=="movable":needed.erase(int(face.get("source_index",-1)))
 if needed.is_empty():return result
 var nodes:Dictionary={}
 for node in host.find_children("*","MultiMeshInstance3D",true,false):nodes[node.multimesh]=node
 for index in pack.get("props",[]).size():
  var row:Dictionary=pack.props[index]
  var placement:Variant=row.get("placement")
  if typeof(placement) not in [TYPE_INT,TYPE_FLOAT] or int(row.get("child_type",-1))!=1:continue
  var id:int=int(placement)
  var key:int=-1-index
  if not needed.has(id) or not host.prop_placements.has(key):continue
  var entry:Array=host.prop_placements[key]
  var multi:MultiMesh=entry[0]
  if not result.has(id):result[id]=[]
  result[id].append({"row":row,"key":key,"multi":multi,"instance":int(entry[1]),"base":multi.get_instance_transform(int(entry[1])),"node":nodes.get(multi)})
 return result
static func bounds(children:Array,origin:Vector3)->AABB:
 var result:=AABB();var first:=true
 for child:Dictionary in children:
  for point:Array in child.row.points:
   var local:=Vector3(point[0],point[1],point[2])-origin
   if first:result=AABB(local,Vector3.ZERO);first=false
   else:result=result.expand(local)
 return result
static func project(children:Array,transform:Transform3D,origin:Vector3):
 var delta:Transform3D=transform*Transform3D(Basis.IDENTITY,origin).affine_inverse()
 for child:Dictionary in children:child.multi.set_instance_transform(child.instance,delta*child.base)
static func aimed(host:Node3D,groups:Dictionary,reach:float)->Dictionary:
 var eye:Vector3=host.camera.global_position
 var direction:Vector3=-host.camera.global_basis.z
 var best:Dictionary={}
 for id in groups:
  for child:Dictionary in groups[id]:
   if is_instance_valid(child.node) and not child.node.is_visible_in_tree():continue
   var transform:Transform3D=child.multi.get_instance_transform(child.instance)
   if absf(transform.basis.determinant())<0.000001:continue
   var point:Vector3=host.to_global(transform.origin)
   var normal:=Vector3(eye.x-point.x,0,eye.z-point.z).normalized()
   var denominator:float=direction.dot(normal)
   if absf(denominator)<0.0001:continue
   var distance:float=(point-eye).dot(normal)/denominator
   if distance<=0 or distance>reach or (not best.is_empty() and distance>=float(best.distance)):continue
   var hit:Vector3=eye+direction*distance
   var right:=Vector3(normal.z,0,-normal.x)
   var x:float=(hit-point).dot(right);var y:float=hit.y-point.y
   if x<float(child.row.left) or x>float(child.row.right) or y<float(child.row.bottom) or y>float(child.row.top):continue
   var query:=PhysicsRayQueryParameters3D.create(eye,hit,3,[host.player.get_rid()])
   if not host.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
   best={"kind":"movable","id":int(id),"distance":distance,"primitive":true}
 return best
