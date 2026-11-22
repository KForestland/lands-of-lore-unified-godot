extends RefCounted
## Physical continuation of native floor motion. Logical object/record fields
## remain in the VM bank and named owners. Restore never fires script events.
const Floors=preload("res://scripts/lol2/act2_floor_checkpoint.gd")
static func error(value:Variant,area:String)->String:
 if not value is Dictionary or value.size() not in [2,3] or value.get("version")!=1 or value.keys().any(func(key):return key not in ["version","floors","movers"]):return "Invalid physical world checkpoint."
 if value.has("movers"):
  if not value.movers is Dictionary or value.movers.size()>65536:return "Invalid saved moving objects."
  var limits:Dictionary=mover_limits(area,true) if not value.movers.is_empty() else {}
  for key in value.movers:
   if not key is String or not limits.has(key):return "Saved moving object is missing from this area."
   var pose_error:=mover_error(value.movers[key],limits[key])
   if not pose_error.is_empty():return pose_error
 var reason:=Floors.error(value.get("floors"))
 if not reason.is_empty():return reason
 if not value.floors.motions.is_empty():
  var path:="res://assets/lol2/generated/creature_nav/"+area+".json"
  if not FileAccess.file_exists(path):return "Missing moving-floor region data."
  var nav:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
  if not nav is Dictionary or not nav.get("regions") is Array:return "Invalid moving-floor region data."
  for key in value.floors.motions:
   if int(str(key))>=nav.regions.size():return "Moving-floor region outside this area."
 return ""
static func snapshot(progression:Node)->Dictionary:
 var movers:Dictionary={}
 for id in progression.hinges:
  if not Generic.movables(progression.area_id).has(int(id)):movers[str(id)]=encode(progression.hinges[id].transform)
 return {"version":1,"floors":progression.floor_checkpoint(),"movers":movers}
static func restore(progression:Node,value:Dictionary)->String:
 var reason:=error(value,progression.area_id)
 if not reason.is_empty():return reason
 # Existing C10 transport restores height/remaining/fraction/rate/clock and
 # projects deck geometry before the player's pose. It does not run a group.
 for key in value.get("movers",{}):
  if not progression.hinges.has(int(key)):return "Saved moving object is not hosted in this area."
 progression.restore_floor_checkpoint(value.floors)
 for key in value.get("movers",{}):
  var id:=int(key);var hinge:Node3D=progression.hinges[id]
  if Generic.movables(progression.area_id).has(id):
   var packet:Dictionary=progression.host.quest_state.get("generic_objects",{}).get("areas",{}).get(progression.area_id,{}).get("movables",{})
   if not packet.has(key):
    var pose:=decode(value.movers[key])
    var ref:String="movable:"+str(key)
    var raw:PackedByteArray=progression.native.placements[ref]
    var Rules=preload("res://scripts/lol2/generic_object_rules.gd")
    var limit:int=Rules.distance_word(int(raw[0x22]),int(raw[0x24]))
    var position:int=0
    if int(raw[0x22])==6:
     position=clampi(roundi(fposmod(-pose.basis.get_euler().y,TAU)/TAU*65536.0*65536.0),0,limit*65536)
    else:
     var legacy_limit:Dictionary=mover_limits(progression.area_id,true)[key]
     var axis:Vector3=legacy_axis(legacy_limit)
     var fraction:float=(pose.origin-legacy_limit.origin).dot(axis)/axis.length_squared()
     position=clampi(roundi(fraction*limit*65536.0),0,limit*65536)
     if position>0:progression.generic_legacy_axes[id]=axis
    var target:int=clampi(progression.native.field(ref,Rules.TRAVEL,0),0,limit)
    var phase:int=2 if position<target*65536 else (3 if position>target*65536 else (1 if position>0 else 0))
    progression.write_generic_motion(id,{Rules.POSITION:position,Rules.PHASE:phase,Rules.TRAVEL:target,Rules.FRACTION:0})
   progression._pose(id)
   hinge.transform=progression.mover_targets[id]
  else:hinge.transform=decode(value.movers[key])
  hinge.force_update_transform()
  progression.project_attached(id)
  if progression.mover_bodies.has(id):
   var body:AnimatableBody3D=progression.mover_bodies[id];body.force_update_transform()
   PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
 return ""

const Native=preload("res://scripts/lol2/native_script_host.gd")
const Generic=preload("res://scripts/lol2/generic_object_catalog.gd")
const Geometry=preload("res://scripts/lol2/geometry_move.gd")
static var _limits:Dictionary={}
static func encode(pose:Transform3D)->Array:
 var result:Array=[]
 for axis in 3:
  for component in 3:result.append(pose.basis[axis][component])
 for component in 3:result.append(pose.origin[component])
 return result
static func decode(values:Array)->Transform3D:
 return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
static func mover_limits(area:String,include_legacy_generic:bool=false)->Dictionary:
 var path:String={"L8_SJ":"res://assets/lol2/generated/darker_jungle/area.json","L9_DR":"res://assets/lol2/generated/dragon_level/area.json"}.get(area,"res://assets/lol2/generated/maps/"+area+"/area.json")
 if area not in ["L8_SJ","L9_DR"]:path=Geometry.pack_path(area,path)
 var key:=area+":"+path+":"+str(include_legacy_generic)
 if _limits.has(key):return _limits[key]
 if not FileAccess.file_exists(path):return {}
 var pack:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not pack is Dictionary or not pack.get("faces") is Array:return {}
 var native:=Native.new()
 if not native.load_area("res://scripts/lol2/native_scripts/"+area+".json").is_empty():return {}
 # Mirror the binder's metadata admission, excluding its dedicated owners.
 # The per-level census independently asserts these exact ids against live
 # hinges, so a future owner move cannot silently widen this save admission.
 var candidates:Dictionary={}
 for commands:Array in native.groups.values():
  for command:Dictionary in commands:
   if int(command.opcode)==1 and int(command.kind)==0x20:candidates[int(command.target)]=true
 for ref:String in native.objects:
  if not ref.begins_with("movable:"):continue
  for record:Dictionary in native.object_records(ref):
   if int(record.kind)==4:candidates[int(ref.get_slice(":",1))]=true
 var dedicated:Array={"L8_SJ":[50],"L12_CM":[50,51,55],"L13_RC":range(50,69),"L14_HT":[0,1,55,56,57,72,73,74,75,76,77,78,80,81,85,86,87]}.get(area,[])
 var result:Dictionary={}
 for face:Dictionary in pack.faces:
  if face.get("kind","")!="movable" or face.get("placement_kind","")!="movable":continue
  var id:=str(int(face.source_index));var ref:="movable:"+id
  if not candidates.has(int(id)) or int(id) in dedicated or (not include_legacy_generic and Generic.movables(area).has(int(id))):continue
  if not native.attributes.has(ref) or not native.placements.has(ref):continue
  var raw:PackedByteArray=native.placements[ref]
  var origin:=Vector3(raw.decode_s16(0),raw.decode_s16(6),-raw.decode_s16(2))
  if not result.has(id):result[id]={"origin":origin,"bounds":AABB(),"first":true,"mode":int(native.attributes[ref].mode),"heading":-float(raw.decode_u16(4))/65536.0*TAU}
  for point:Array in face.points:
   var vertex:=Vector3(point[0],point[1],point[2])-origin
   if result[id].first:result[id].bounds=AABB(vertex,Vector3.ZERO);result[id].first=false
   else:result[id].bounds=result[id].bounds.expand(vertex)
 # The existing L10 sigil owner overrides the generic panel axis for these
 # four halves. Admission must match that published source-travel adapter;
 # otherwise a perfectly ordinary already-open C15 gate refuses all saves.
 if area=="L10_DC":
  for id in [70,71,72,73]:
   if result.has(str(id)):
    var extent:=absf(float(native.attributes["movable:%d"%id].get("angle_word",132)))
    result[str(id)].owner_axis=Vector3.RIGHT*(-1.0 if id in [70,73] else 1.0)*extent
  if result.has("74"):result["74"].owner_axis=Vector3.UP*(result["74"].bounds.size.y+8.0) # Existing L10Barrel withdraws this panel upward.
 _limits[key]=result
 return result
static func mover_error(value:Variant,limit:Dictionary)->String:
 if not value is Array or value.size()!=12:return "Invalid saved moving pose."
 for i in 12:
  if not (value[i] is int or value[i] is float) or not is_finite(float(value[i])) or absf(float(value[i]))>(1.0001 if i<9 else 10000000):return "Invalid saved moving pose number."
 var pose:=decode(value)
 if not pose.basis.is_equal_approx(pose.basis.orthonormalized()) or not is_equal_approx(pose.basis.determinant(),1.0):return "Invalid saved moving orientation."
 var offset:Vector3=pose.origin-limit.origin
 if int(limit.mode)==6 and not limit.has("owner_axis"):
  if offset.length()>0.01 or pose.basis.y.distance_to(Vector3.UP)>0.0001:return "Saved door pose is outside its hinge."
 else:
  if not pose.basis.is_equal_approx(Basis()):return "Saved sliding object cannot rotate."
  var bounds:AABB=limit.bounds
  var displacement:=Vector3.UP*(bounds.size.y+8.0)
  if bounds.size.y<minf(bounds.size.x,bounds.size.z):displacement=Vector3(sin(limit.heading),0,cos(limit.heading))*(maxf(bounds.size.x,bounds.size.z)+8.0)
  displacement=limit.get("owner_axis",displacement)
  var fraction:=offset.dot(displacement)/displacement.length_squared()
  if absf(fraction)>1.0001 or (limit.has("owner_axis") and fraction < -0.0001) or offset.distance_to(displacement*fraction)>0.01:return "Saved moving pose is outside its source travel."
 return ""

static func legacy_axis(limit:Dictionary)->Vector3:
 var bounds:AABB=limit.bounds
 var axis:=Vector3.UP*(bounds.size.y+8.0)
 if bounds.size.y<minf(bounds.size.x,bounds.size.z):axis=Vector3(sin(limit.heading),0,cos(limit.heading))*(maxf(bounds.size.x,bounds.size.z)+8.0)
 return limit.get("owner_axis",axis)
static func legacy_axis_error(value:Variant,area:String,id:String)->String:
 if not value is Array or value.size()!=3:return "Invalid legacy motion axis."
 for number in value:
  if not (number is int or number is float) or not is_finite(float(number)):return "Invalid legacy motion axis."
 var limits:Dictionary=mover_limits(area,true)
 if not limits.has(id) or int(limits[id].mode)==6:return "Unknown legacy motion axis."
 var axis:=Vector3(value[0],value[1],value[2])
 if not axis.is_equal_approx(legacy_axis(limits[id])):return "Legacy motion axis differs from its source bounds."
 return ""
