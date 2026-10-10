extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var scene = load("res://scenes/lol2/jungle_review.tscn").instantiate()
 root.add_child(scene)
 await physics_frame
 await physics_frame
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_review/jungle.json"))
 var checks := 0
 # Interior spans follow the 7,573 floor/outer-wall faces.
 for face in data.faces.slice(7573):
  var p := PackedVector3Array()
  for a in face.points: p.append(Vector3(a[0],a[1],a[2]))
  if p[0].distance_to(p[1]) < 4 or minf(p[3].y-p[0].y,p[2].y-p[1].y) < 4: continue
  var center := p[0]*0.2+p[1]*0.3+p[2]*0.5
  var normal := (p[1]-p[0]).cross(p[3]-p[0]).normalized()
  if normal.length() < 0.5: continue
  for sign_value in [-1.0,1.0]:
   var ray := PhysicsRayQueryParameters3D.create(center+normal*sign_value,center-normal*sign_value)
   ray.exclude = [scene.player.get_rid()]
   var hit = scene.get_world_3d().direct_space_state.intersect_ray(ray)
   assert(not hit.is_empty(),"Interior wall missing collision")
   assert(hit.position.distance_to(center)<0.1,"Interior collision differs from visual face")
  checks += 1
  if checks == 20: break
 assert(checks == 20)
 print("Jungle interior collision: 20 spans block rays from both sides.")
 quit()
