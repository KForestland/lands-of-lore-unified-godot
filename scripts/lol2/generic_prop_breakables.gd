extends RefCounted
## Original prop billboards for class-C strike admission. No added walk body,
## L10 terminal hide, contents or selector is inferred from zero durability.
const Views=preload("res://scripts/lol2/prop_selector_view.gd")
static func build(host:Node3D,area:String,rows:Dictionary)->Dictionary:
 var result:Dictionary={}
 for id in rows:
  if rows[id].native_class!="prop":continue
  var view:Node3D=Views.attach(host,area,int(id))
  if view==null:
   push_error("Generic breakable prop lacks original selector media: %s:%d"%[area,id])
   continue
  result[id]=view
 return result
static func aimed(host:Node3D,views:Dictionary,reach:float)->Dictionary:
 var eye:Vector3=host.camera.global_position
 var direction:Vector3=-host.camera.global_basis.z
 var nearest:Dictionary={}
 for id in views:
  var view:Node3D=views[id]
  if not view.mesh.is_visible_in_tree():continue
  var row:Dictionary=view.pack.selectors["%d:%d"%[view.template,view.selector]]
  var point:Vector3=view.global_position
  var normal:=Vector3(eye.x-point.x,0,eye.z-point.z).normalized()
  var denominator:float=direction.dot(normal)
  if absf(denominator)<0.0001:continue
  var distance:float=(point-eye).dot(normal)/denominator
  if distance<=0 or distance>reach or (not nearest.is_empty() and distance>=float(nearest.distance)):continue
  var hit:Vector3=eye+direction*distance
  var right:=Vector3(normal.z,0,-normal.x)
  var x:float=(hit-point).dot(right);var y:float=hit.y-point.y
  if x<float(row.left) or x>float(row.right) or y<float(row.bottom) or y>float(row.state_height)-float(row.top_trim):continue
  var query:=PhysicsRayQueryParameters3D.create(eye,hit,3,[host.player.get_rid()])
  if not host.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
  nearest={"kind":"cover","id":int(id),"distance":distance,"prop":true}
 return nearest
