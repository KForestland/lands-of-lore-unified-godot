extends Node3D
## Exact decoded order only. Initial Rampraise_Check is unproved: lead06:54
## admits the original success group after116,116,114,115. Never seed local8.
const Native=preload("res://scripts/lol2/native_script_host.gd")
const Combat=preload("res://scripts/lol2/player_combat.gd")
const InputGate=preload("res://scripts/lol2/world_input.gd")
const KEY="hive_decoded_locks"
const ORDER=[116,116,114,115]
const CONTROLS=[114,115,116]
const REACH=110.0 # Same use reach as the Hive's flute-floor owner.
const MAX_RISE=15.0
const BASE=-1011.0
const RISE_PER_SECOND=20.0 # Modern clock adapter: native c4's rate units remain unproved.
static var source:Dictionary={}
static var initial_snapshot:Dictionary={}
var host:Node3D
var native:RefCounted
var progress:=0
var completed:=false
var rise:=0.0
var floor_body:AnimatableBody3D
var bodies:Dictionary={}
var hint:Label
var sound_log:Array[int]=[]
var last_result:Dictionary={}
var configured:=false
var conversation:Node
var occupancy_pending:=false
static func data()->Dictionary:
 if source.is_empty():source=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/hive_locks_source.json"))
 return source
static func fresh_native()->RefCounted:
 var vm:=Native.new();var error:String=vm.load_area_data(data().native);assert(error.is_empty(),error);return vm
static func initial()->Dictionary:
 if initial_snapshot.is_empty():initial_snapshot={"version":1,"native":fresh_native().snapshot(),"progress":0,"completed":false,"rise":0.0}
 return initial_snapshot.duplicate(true)
static func source_error()->String:
 for pair in [["res://scripts/lol2/native_scripts/L5_HC.json","native_export_sha256"],["res://assets/lol2/generated/hive_review/hive.json","geometry_sha256"]]:
  if not FileAccess.file_exists(pair[0]) or FileAccess.get_sha256(pair[0])!=str(data().get(pair[1],"")):return "Hive lock source changed; stage the matching native scripts and geometry."
 return ""
static func lock_bounds(pack:Dictionary,id:int)->Dictionary:
 var points:Array=[]
 for face in pack.get("faces",[]):
  if int(face.get("assembly",-1))==id and face.get("initial",false):points.append_array(face.points)
 if points.is_empty():return {"error":"Hive lock %d has no initial geometry."%id}
 var first:Array=points[0];var box:=AABB(Vector3(first[0],first[1],first[2]),Vector3.ZERO)
 for point in points:box=box.expand(Vector3(point[0],point[1],point[2]))
 var placement:Dictionary=data().controls[str(id)]
 var origin:=Vector3(placement.x,placement.height,-placement.y)
 if box.get_center().distance_to(origin)>80:return {"error":"Hive lock geometry is not in published map coordinates."}
 var size:=box.size.max(Vector3(2,2,2))
 return {"error":"","bounds":AABB(box.get_center()-size*0.5,size)}
static func validate(value:Variant)->String:
 if not value is Dictionary or value.size()!=5 or value.get("version")!=1 or not value.get("completed") is bool:return "Invalid Hive locks."
 if not Native._snapshot_integer(value.get("progress")) or int(value.progress)<0 or int(value.progress)>3:return "Invalid Hive lock sequence."
 if not (value.get("rise") is float or value.get("rise") is int) or not is_finite(float(value.rise)) or value.rise<0 or value.rise>15:return "Invalid Hive lock floor."
 var error:String=Native.snapshot_error(value.get("native"))
 if not error.is_empty():return error
 var vm:Dictionary=value.native
 if not vm.record_state.is_empty() or not vm.locals_e58.is_empty():return "Unexpected Hive lock cells."
 if vm.state.size()!=(4 if value.completed else 3):return "Invalid Hive lock native fields."
 for id in CONTROLS:
  var fields:Variant=vm.state.get("control:%d"%id)
  if not fields is Dictionary or fields.size()!=3 or fields.get(Native.FIELD_SELECTOR)!=0 or fields.get(Native.FIELD_BYTE26)!=str(data().controls[str(id)].placement_hex).hex_decode()[30] or not fields.has(Native.FIELD_BYTE25):return "Invalid Hive lock state."
  if int(fields[Native.FIELD_BYTE25])<0 or int(fields[Native.FIELD_BYTE25])>(2 if id==116 else 1):return "Invalid Hive lock value."
 if value.completed:
  var floor:Variant=vm.state.get("0x22d0c:760")
  if not floor is Dictionary or floor.size()!=2 or floor.get(Native.FIELD_FLOOR_TARGET)!=-996 or floor.get(Native.FIELD_FLOOR_RATE)!=20:return "Invalid Hive lock target."
  if vm.locals.size()!=1 or vm.locals.get("16")!=0 or value.progress!=0:return "Invalid Hive lock completion."
 elif not vm.locals.is_empty() or value.rise!=0:return "Unfinished Hive locks cannot raise the floor."
 var left:int=int(vm.state["control:116"][Native.FIELD_BYTE25]);var right:int=int(vm.state["control:114"][Native.FIELD_BYTE25]);var top:int=int(vm.state["control:115"][Native.FIELD_BYTE25])
 if value.completed and [left,right,top]!=[0,0,1]:return "Invalid completed lock pose."
 if not value.completed:
  match int(value.progress):
   0:if left!=0 or right!=0:return "Invalid reset lock prefix."
   1:if left!=1 or right!=0:return "Invalid first lock prefix."
   2:if left!=2 or right!=1:return "Invalid second lock prefix."
   3:if [left,right,top]!=[0,0,1]:return "Invalid third lock prefix."
 return ""
func checkpoint()->Dictionary:return {"version":1,"native":native.snapshot(),"progress":progress,"completed":completed,"rise":snappedf(rise,1.0/4096.0)}
func restore(value:Variant)->String:
 var saved:Variant=initial() if value==null else value
 var error:String=validate(saved)
 if not error.is_empty():return error
 native.restore(saved.native);progress=int(saved.progress);completed=saved.completed;rise=float(saved.rise);occupancy_pending=completed
 sound_log.clear();present();return ""
func setup(map:Node3D)->String:
 name="HiveDecodedLocks";host=map;native=fresh_native()
 var error:=source_error()
 if not error.is_empty():return error
 conversation=host.get_node_or_null("ConversationReview")
 native.sound_request.connect(func(request:int):sound_log.append(request);print("Hive lock native sound request ",request," (logged; audio mapping unhosted)"))
 # Exact source control bounds, hit-only; no new player obstacles.
 var pack:Dictionary=host.static_assemblies.data
 var boxes:Dictionary={}
 for id in CONTROLS:
  var result:=lock_bounds(pack,id)
  if not str(result.error).is_empty():return result.error
  boxes[id]=result.bounds
 for id in CONTROLS:
  var box:AABB=boxes[id]
  var body:=StaticBody3D.new();body.name="Lock%d"%id;body.collision_layer=4;body.collision_mask=0
  var shape:=CollisionShape3D.new();var hull:=BoxShape3D.new();hull.size=box.size;shape.shape=hull;body.position=box.get_center();body.add_child(shape);add_child(body);bodies[id]=body
 # Raised source quad in its own body. Original terrain mesh stays unchanged.
 var face:Dictionary=data().floor;var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(host.materials[face.material]);var corners:=PackedVector3Array()
 for p in face.points:
  # Fill all the way below the original floor at every height, including on
  # load. A floating two-unit slab left an enterable pocket for small forms.
  corners.append(Vector3(p[0],p[1],p[2]));corners.append(Vector3(p[0],p[1]-MAX_RISE-2,p[2]))
 for i in [0,1,2,0,2,3]:
  var p:Array=face.points[i];surface.set_uv(Vector2(face.uv[i][0],face.uv[i][1]));surface.add_vertex(Vector3(p[0],p[1],p[2]))
 surface.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit()
 floor_body=AnimatableBody3D.new();floor_body.name="NativeFloor760";floor_body.sync_to_physics=false;floor_body.add_child(mesh)
 var collider:=CollisionShape3D.new();var slab:=ConvexPolygonShape3D.new();slab.points=corners;collider.shape=slab;floor_body.add_child(collider);add_child(floor_body)
 hint=preload("res://scripts/lol2/interaction_hint_label.gd").attach(self,Vector2(24,435))
 configured=true
 return restore(host.carried_quest_checkpoint.get(KEY))
func present()->void:
 if not is_instance_valid(floor_body):return
 floor_body.position.y=rise;floor_body.visible=rise>0;floor_body.collision_layer=1 if rise>0 else 0
 if completed and rise>0:lift_occupants()
func inside_floor(point:Vector3)->bool:
 var polygon:=PackedVector2Array()
 for p in data().floor.points:polygon.append(Vector2(p[0],p[2]))
 return Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon)
func lift_occupants()->void:
 # At most fifteen units within this exact floor. This also projects old
 # mid-rise saves before their first physics step; no search or quest replay.
 var top:=BASE+rise
 var player:CharacterBody3D=host.player
 var feet:float=player.global_position.y-32.0
 if inside_floor(player.global_position) and feet>=BASE-1 and feet<top:
  player.global_position.y=top+32;player.velocity.y=maxf(0,player.velocity.y);player.force_update_transform()
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=floor_body.get_child(1).shape;query.transform=floor_body.global_transform;query.collision_mask=2
 for hit in get_world_3d().direct_space_state.intersect_shape(query,64):
  var body:Node3D=hit.collider
  if body==player or not inside_floor(body.global_position):continue
  for child in body.get_children():
   if not child is CollisionShape3D or child.disabled:continue
   var shape:Shape3D=child.shape
   var half:float=shape.height*0.5 if shape is CapsuleShape3D else shape.size.y*0.5 if shape is BoxShape3D else shape.radius if shape is SphereShape3D else -1.0
   if half<0:continue
   var bottom:float=child.global_position.y-half*child.global_basis.y.length()
   if bottom>=BASE-1 and bottom<top:
    body.global_position.y+=top-bottom;body.force_update_transform()
   break
 var effects:Variant=host.get("item_effects")
 if is_instance_valid(effects):
  for row in effects.state().get("thrown_items",[]):
   if row.area!=host.scene_file_path:continue
   var point:=Vector3(row.position[0],row.position[1],row.position[2])
   if inside_floor(point) and point.y>=BASE+3 and point.y<top+4:row.position[1]=top+4
func active()->bool:
 if not configured or not is_instance_valid(host) or not is_instance_valid(host.starting_magic) or host.starting_magic.health()<=0 or not host.starting_magic.world_active() or not InputGate.available() or host.actor_input_locked():return false
 if is_instance_valid(host.runes) and host.runes.active():return false
 return not (is_instance_valid(conversation) and conversation.started and not conversation.completed)
func aimed()->int:
 if not active():return -1
 var origin:Vector3=host.camera.global_position;var end:Vector3=origin-host.camera.global_basis.z*REACH
 # Terrain1, actors2, lock receivers4 and existing scenery256 all occlude.
 var hit:Dictionary=Combat.ray_between(host,origin,end,263,[host.player.get_rid()])
 for id in bodies:
  if hit.get("collider")==bodies[id]:return int(id)
 return -1
func press(id:int)->bool:
 if not id in CONTROLS:return false
 if completed:host.save_feedback("The lock sequence is complete.");return true
 var state:int=int(native.field("control:%d"%id,Native.FIELD_BYTE25,0))
 var group:int=([6408,6436][state] if id==114 else ([6532,6560][state] if id==115 else [6676,6698,6726][state]))
 var correct:bool=id==ORDER[progress]
 # Do not let a stale source state admit success after a wrong extra press.
 if id==115 and (not correct or progress!=3):group=6532
 last_result=native.execute_group(1,group)
 if last_result.status!="ran":host.save_feedback("This lock cannot move now.");return true
 if correct:
  progress+=1
  if progress==4:completed=true;progress=0
 else:progress=1 if id==116 else 0
 host.save_feedback("The nearby recessed floor rises." if completed else "The lock clicks.")
 return true
func _physics_process(delta:float)->void:
 if completed and rise<15 and active():
  rise=move_toward(rise,MAX_RISE,RISE_PER_SECOND*delta)
  present()
 elif occupancy_pending and completed and rise>0:
  lift_occupants();occupancy_pending=false
func _process(_delta:float)->void:
 if is_instance_valid(hint):hint.text="E — Press the lock" if aimed()>=0 else ""
func _unhandled_input(event:InputEvent)->void:
 var use:bool=event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E
 if not use:return
 var id:int=aimed()
 if id>=0 and press(id):get_viewport().set_input_as_handled()
