extends Node3D
## Shared generic bridge; per-area census admission retains dedicated puzzle owners.
const Catalog=preload("res://scripts/lol2/generic_object_catalog.gd")
const Rules=preload("res://scripts/lol2/generic_object_rules.gd")
const Native=preload("res://scripts/lol2/native_script_host.gd")
const Combat=preload("res://scripts/lol2/player_combat.gd")
const WorldInput=preload("res://scripts/lol2/world_input.gd")
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
const KEY:="generic_objects"
const RESTORE_ON:=["load","arrival"]
var host:Node3D
var binding:Node
var renderer:Node3D
var cover_bodies:Dictionary={}
var prop_views:Dictionary={}
var cover_modes:Dictionary={}
var dedicated_movers:Dictionary={}
var hint:Label
var pause_hint:Label
static var warned_clamps:Dictionary={}
static func initial()->Dictionary:return {"version":1,"areas":{}}
static var data_checked:=false
static var data_problem:=""
## Preflight is separate from reporting so invalid packs can be tested without
## mutating staged media or swallowing runtime errors.
static func data_error(rows:Dictionary,pack:Variant,collision:Variant,native_present:bool)->String:
 if not native_present:return "native script export is missing"
 if rows.is_empty():return "census is missing or empty"
 if not pack is Dictionary or not pack.get("placements") is Dictionary or not pack.get("faces") is Array or not pack.get("materials") is Dictionary:return "assembly media manifest is missing or invalid"
 if not collision is Dictionary or not collision.get("boxes") is Dictionary:return "collision manifest is missing or invalid"
 for id in rows:
  if not pack.placements.has(str(id)) or not collision.boxes.has(str(id)):return "assembly placement or box %d is missing"%id
 for face in pack.faces:
  if rows.has(int(face.assembly)) and (not pack.materials.has(face.material) or not FileAccess.file_exists(Assemblies.ROOT+"L10_DC/"+str(face.material))):return "cover material is missing: "+str(face.material)
 return ""
static func preparation_error()->String:
 if data_checked:return data_problem
 data_checked=true
 var pack:Variant=JSON.parse_string(FileAccess.get_file_as_string(Assemblies.ROOT+"L10_DC/assemblies.json"))
 var collision:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L10_DC.json"))
 data_problem=data_error(Catalog.breakables("L10_DC"),pack,collision,FileAccess.file_exists("res://scripts/lol2/native_scripts/L10_DC.json"))
 if not data_problem.is_empty():push_error("Generic objects: "+data_problem+"; original map frames retained. Restage generated inputs.")
 return data_problem
static func owns(face:Dictionary)->bool:
 if not preparation_error().is_empty():return false
 return face.get("placement_kind")=="static_assembly" and Catalog.breakables("L10_DC").has(int(face.get("source_index",-1)))
static func attach(map:Node3D)->Node3D:
 var node:Node3D=load("res://scripts/lol2/generic_object_world.gd").new()
 node.host=map
 var existing:Node=map.get_node_or_null("GenericObjects")
 node.name="GenericObjects" if existing==null else "GenericWorld"
 if existing==null:map.add_child(node)
 else:existing.add_child(node)
 return node
static var warned_unknown:Dictionary={}
static func unknown(message:String):
 if warned_unknown.has(message):return
 warned_unknown[message]=true;push_warning(message)
static func selector_limit(row:Dictionary)->int:
 return int(row.get("selector_limit",3 if int(row.template)==1 else 0))
static func clamp_saved_cover(value:Variant,row:Dictionary)->Variant:
 if not value is Dictionary or value.size()!=2:return value
 var saved:Dictionary=value.duplicate(true)
 for pair in [["life",int(row.start_life)],["selector",selector_limit(row)]]:
  var field:String=pair[0];var number:Variant=saved.get(field)
  if (number is int or number is float) and is_finite(float(number)) and number==int(number) and number>int(pair[1]):saved[field]=int(pair[1])
 return saved
static func clamped(message:String):
 if warned_clamps.has(message):return
 warned_clamps[message]=true;push_warning(message)
static func validate(value:Variant)->String:
 if not value is Dictionary or value.get("version")!=1 or not value.get("areas") is Dictionary:return "Invalid generic object packet."
 for area in value.areas:
  if not (area is String or area is StringName):return "Invalid generic area identity."
  var moves:=Catalog.movables(area);var breaks:=Catalog.breakables(area)
  if area!="L10_DC" and not Catalog.PACKETS.has(area):
   unknown("Generic objects: ignoring unknown saved area "+str(area));continue
  var state:Variant=value.areas[area]
  if not state is Dictionary or not state.get("movables",{}) is Dictionary or not state.get("breakables",{}) is Dictionary:return "Invalid generic area."
  if not state.get("legacy_axes",{}) is Dictionary:return "Invalid legacy motion axes."
  for id in state.get("legacy_axes",{}):
   if not id is String or not moves.has(int(id)) or not state.get("movables",{}).has(id):return "Unknown legacy motion owner."
   var axis_error:String=preload("res://scripts/lol2/act2_world_checkpoint.gd").legacy_axis_error(state.legacy_axes[id],area,id)
   if not axis_error.is_empty():return axis_error
  for id in state.get("movables",{}):
   if not id is String or not id.is_valid_int() or id!=str(int(id)) or not moves.has(int(id)):
    unknown("Generic objects: ignoring unknown saved movable %s:%s"%[area,id]);continue
   var placement:PackedByteArray=str(moves[int(id)].placement_hex).hex_decode()
   var error:=Rules.motion_error(Rules.clamp_saved_motion(state.movables[id],placement),placement)
   if not error.is_empty():return error
  for id in state.get("breakables",{}):
   if not id is String or not id.is_valid_int() or id!=str(int(id)) or not breaks.has(int(id)):
    unknown("Generic objects: ignoring unknown saved breakable %s:%s"%[area,id]);continue
   var row:Variant=clamp_saved_cover(state.breakables[id],breaks[int(id)])
   if not row is Dictionary or row.size()!=2:return "Invalid generic cover."
   for field in ["life","selector"]:
    if not (row.get(field) is int or row.get(field) is float) or not is_finite(float(row[field])) or row[field]!=int(row[field]):return "Invalid generic cover field."
   var max_selector:int=selector_limit(breaks[int(id)])
   if row.life<0 or row.life>int(breaks[int(id)].start_life) or row.selector<0 or row.selector>max_selector:return "Invalid generic cover bounds."
 return ""
func _ready():
 binding=host.get("progression")
 if binding==null:return
 if binding.area_id=="L10_DC":
  if not preparation_error().is_empty():binding=null;return
  setup_covers()
 prop_views=preload("res://scripts/lol2/generic_prop_breakables.gd").build(host,binding.area_id,Catalog.breakables(binding.area_id))
 for id in Catalog.breakables(binding.area_id):
  if Catalog.breakables(binding.area_id)[id].native_class=="prop" and not prop_views.has(id):binding=null;return
 remember_dedicated_movers()
 binding.native.object_state_changed.connect(_field)
 hint=preload("res://scripts/lol2/interaction_hint_label.gd").attach(self,Vector2(24,365))
 pause_hint=preload("res://scripts/lol2/interaction_hint_label.gd").attach(self,Vector2(24,340))
 restore()
func remember_dedicated_movers():
 # The registered puzzle owner keeps E and its own prerequisites. Adding a
 # left binding must not run a generic native callback ahead of that owner.
 var registry:Node=host.get("area_owners")
 if not is_instance_valid(registry):return
 for owner:Node in registry.owners():
  if owner.has_method("generic_owned_movers"):
   for id in owner.generic_owned_movers():dedicated_movers[int(id)]=true
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for face in pack.faces:
  if face.get("placement_kind")!="movable":continue
  var id:int=int(face.get("source_index",-1))
  if dedicated_movers.has(id) or not binding.mover_bodies.has(id) or Catalog.movables(binding.area_id).has(id):continue
  if registry.claims_static(face) or registry.claims_collision(face):dedicated_movers[id]=true
func setup_covers():
 renderer=Assemblies.new();add_child(renderer)
 var error:String=renderer.setup_selected(host,binding.area_id,Catalog.breakables(binding.area_id).keys())
 if not error.is_empty():
  push_error("Generic objects: "+error);binding=null;return
 var boxes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L10_DC.json")).boxes
 for id in Catalog.breakables(binding.area_id):
  var body:StaticBody3D=Assemblies.box_body(int(id),boxes[str(id)],Vector3.ZERO)
  if body==null:
   push_error("Generic objects: cover %d lacks a usable published box"%id);binding=null;return
  body.name="GenericCover%d"%id;body.collision_layer=1|Assemblies.SCENERY_LAYER;body.collision_mask=0
  body.set_meta("generic_cover",int(id));add_child(body);cover_bodies[int(id)]=body
func cover_ref(id:int)->String:
 return "%s:%d"%[Catalog.breakables(binding.area_id)[id].native_class,id]
func _field(ref:String,field:String,_value:int):
 if field!=Native.FIELD_SELECTOR:return
 var id:int=int(ref.get_slice(":",1))
 if Catalog.breakables(binding.area_id).has(id) and ref==cover_ref(id):refresh(id)
func refresh(id:int):
 if prop_views.has(id):
  prop_views[id].show_selector(binding.native.field(cover_ref(id),Native.FIELD_SELECTOR,0))
  return # Native prop groups decide effects; zero life does not imply deletion.
 var broken:bool=binding.native.field(cover_ref(id),Native.FIELD_BYTE26,0)<=0
 var mode:int=binding.native.field(cover_ref(id),Native.FIELD_SELECTOR,0)
 # Modern terminal bridge: retain the last published damage frame and release
 # the solid front at zero life; do not delete artwork or invent contents.
 if broken and int(Catalog.breakables(binding.area_id)[id].template)==1:mode=3
 cover_bodies[id].collision_layer=0 if broken else 1|Assemblies.SCENERY_LAYER
 # No damage frame exists for template66. Keep the released opening visible
 # by hiding its intact artwork at zero life; never invent a frame.
 if int(Catalog.breakables(binding.area_id)[id].template)!=1:renderer.set_present(id,not broken)
 if cover_modes.get(id,-1)==mode:return
 cover_modes[id]=mode;renderer.set_mode(id,mode)
func snapshot_area()->Dictionary:
 var state:Dictionary={"movables":{},"breakables":{}}
 if not binding.generic_legacy_axes.is_empty():
  state.legacy_axes={}
  for id in binding.generic_legacy_axes:
   var axis:Vector3=binding.generic_legacy_axes[id]
   state.legacy_axes[str(id)]=[axis.x,axis.y,axis.z]
 for id in Catalog.movables(binding.area_id):
  var ref:String="movable:%d"%id;var row:Dictionary={}
  for field in Rules.FIELDS:row[field]=binding.native.field(ref,field,0)
  state.movables[str(id)]=row
 for id in Catalog.breakables(binding.area_id):
  var ref:String=cover_ref(id)
  state.breakables[str(id)]={"life":binding.native.field(ref,Native.FIELD_BYTE26,0),"selector":binding.native.field(ref,Native.FIELD_SELECTOR,0)}
 return state
func sync():
 if binding==null:return
 var area_state:Dictionary=snapshot_area()
 if area_state.movables.is_empty() and area_state.breakables.is_empty():return
 var packet:Dictionary=host.quest_state.get(KEY,initial()).duplicate(true)
 packet.areas[binding.area_id]=area_state;host.quest_state[KEY]=packet
func restore()->String:
 if binding==null:return ""
 var packet:Dictionary=host.quest_state.get(KEY,initial())
 var error:=validate(packet)
 if not error.is_empty():return error
 var saved:Dictionary=packet.areas.get(binding.area_id,{})
 for id in Catalog.movables(binding.area_id):
  var ref:String="movable:%d"%id
  if saved.get("legacy_axes",{}).has(str(id)):
   var axis:Array=saved.legacy_axes[str(id)];binding.generic_legacy_axes[id]=Vector3(axis[0],axis[1],axis[2])
  elif saved.get("movables",{}).has(str(id)):binding.generic_legacy_axes.erase(id)
  var defaults:Dictionary=Rules.initial(binding.native.placements[ref])
  if binding.area_id!="L10_DC":
   for field in Rules.FIELDS:defaults[field]=binding.native.field(ref,field,int(defaults[field]))
  var row:Dictionary=saved.get("movables",{}).get(str(id),defaults)
  var bounded:Dictionary=Rules.clamp_saved_motion(row,binding.native.placements[ref])
  if bounded!=row:clamped("Generic objects: clamped saved movable %s:%d to current span"%[binding.area_id,id])
  binding.write_generic_motion(id,bounded)
  binding._pose(id)
  if binding.hinges.has(id):
   binding.hinges[id].transform=binding.mover_targets[id]
   binding.project_attached(id)
   if binding.mover_bodies.has(id):
    var body:AnimatableBody3D=binding.mover_bodies[id];body.force_update_transform()
    PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
 for id in Catalog.breakables(binding.area_id):
  var ref:String=cover_ref(id)
  var row:Dictionary=saved.get("breakables",{}).get(str(id),{"life":int(Catalog.breakables(binding.area_id)[id].start_life),"selector":0})
  var bounded:Dictionary=clamp_saved_cover(row,Catalog.breakables(binding.area_id)[id])
  if bounded!=row:clamped("Generic objects: clamped saved cover %s:%d to current life/selector bounds"%[binding.area_id,id])
  binding.native.set_field(ref,Native.FIELD_BYTE26,int(bounded.life));binding.native.set_field(ref,Native.FIELD_SELECTOR,int(bounded.selector))
  cover_modes.erase(id);refresh(id)
 return ""
func aimed()->Dictionary:
 if binding==null:return {}
 var primitive:Dictionary=preload("res://scripts/lol2/generic_attached_primitives.gd").aimed(host,binding.mover_attached,Rules.REACH)
 var prop:Dictionary=preload("res://scripts/lol2/generic_prop_breakables.gd").aimed(host,prop_views,Combat.REACH_PROP)
 if not prop.is_empty() and (primitive.is_empty() or float(prop.distance)<float(primitive.distance)):primitive=prop
 var hit:=Combat.aim_ray(host,Rules.REACH,1|2)
 if not primitive.is_empty() and (hit.is_empty() or float(primitive.distance)<host.camera.global_position.distance_to(hit.position)):return primitive
 if hit.is_empty():return {}
 var collider:CollisionObject3D=hit.collider
 for id in binding.mover_bodies:
  if collider==binding.mover_bodies[id] and Catalog.movables(binding.area_id).has(id):
   # Convex standable-top support can extend below the published mesh (a
   # bottom slab is 0.5 units thick). It is collision, not usable object art:
   # an under-floor ray must not activate a door through that proxy face.
   var published:AABB=binding.mover_bounds[id]
   var local_hit:Vector3=binding.hinges[id].to_local(hit.position)
   if not published.grow(0.01).has_point(local_hit):return {"kind":"blocked","distance":host.camera.global_position.distance_to(hit.position),"collider":collider}
   return {"kind":"movable","id":id,"distance":host.camera.global_position.distance_to(hit.position)}
 for id in binding.mover_bodies:
  if not dedicated_movers.has(id) and collider==binding.mover_bodies[id] and binding.aimed()==int(id):return {"kind":"scripted","id":id,"distance":host.camera.global_position.distance_to(hit.position)}
 for id in cover_bodies:
  if collider==cover_bodies[id]:return {"kind":"cover","id":id,"distance":host.camera.global_position.distance_to(hit.position)}
 return {"kind":"blocked","distance":host.camera.global_position.distance_to(hit.position),"collider":collider,"position":hit.position}
func movable_use(id:int,distance:float)->Dictionary:
 var ref:String="movable:%d"%id;var state:Dictionary={}
 for field in Rules.FIELDS:state[field]=binding.native.field(ref,field,0)
 return Rules.use(state,binding.native.placements[ref],distance,0,binding.native.field(ref,"bit_0x15_0x80",0)==1)
func use_movable(id:int,distance:float)->bool:
 var ref:String="movable:%d"%id;var state:Dictionary={}
 for field in Rules.FIELDS:state[field]=binding.native.field(ref,field,0)
 var result:=Rules.use(state,binding.native.placements[ref],distance,0,binding.native.field(ref,"bit_0x15_0x80",0)==1)
 if not result.accepted:return false
 binding.write_generic_motion(id,result.state)
 for caller in result.callers:binding.fire(ref,6,{"caller_byte":caller,"context":ref})
 var source_use:Dictionary=Catalog.movables(binding.area_id)[id].get("use_event",{})
 if source_use.is_empty():binding.fire(ref,4,{"arg_c":0,"context":ref})
 else:binding.fire(ref,int(source_use.kind),source_use.input)
 return true
func strike(id:int)->bool:
 if not Combat.may_strike(host,false):return false
 var population:Node=host.get("act2_creatures")
 if population!=null and not Combat.cooldown_ready(population.strike_remaining):return false
 var ref:String=cover_ref(id)
 var old_cap:int=binding.native.field(ref,Native.FIELD_BYTE26,0)
 if old_cap<=0:return false
 var damage:int=Combat.damage(host,true)
 if damage<=0:return false
 if population!=null:population.strike_remaining=Combat.COOLDOWN
 var remaining:=maxi(0,old_cap-damage)
 binding.native.set_field(ref,Native.FIELD_BYTE26,remaining)
 var thresholds:Array=[]
 for record in binding.native.object_records(ref):
  if int(record.kind)==9 and (int(record.bytes[9])&7)==3:thresholds.append(int(record.bytes[8]))
 var previous:int=old_cap
 # Preserve the VM's first-success dispatch; present each crossed band as a
 # separate ordered event so one strong blow cannot skip a cover stage.
 for threshold in Rules.crossed_thresholds(old_cap,remaining,thresholds):
  binding.fire(ref,9,{"dword_22":previous,"dword_26":threshold,"dword_1e":damage,"word0":binding.CUT_WORD0,"word2":binding.CUT_WORD2,"context":ref})
  previous=threshold
 refresh(id)
 preload("res://scripts/lol2/combat_feedback.gd").landed(true)
 return true
func active()->bool:
 return binding!=null and host.player_form==0 and binding._interaction_active() and WorldInput.available() and (host.starting_magic==null or host.starting_magic.health()>0)
func mover_noun(id:int)->String:
 var row:Dictionary=Catalog.movables(binding.area_id)[id]
 return "chest lid" if row.kind=="chest" else ("door" if int(row.mode)==6 else ("pit lid" if id==52 else ("lid" if int(row.mode) in [0,1] else ("sliding panel" if int(row.mode) in [2,3] else "crypt top"))))
func _process(_delta:float):
 if hint==null:return
 hint.text=""
 if pause_hint!=null:pause_hint.text=""
 if not active():return
 for blocked_id in binding.generic_mover_blocked:
  if not binding.generic_mover_blocked[blocked_id] or not binding.hinges.has(blocked_id):continue
  var bounds:AABB=binding.mover_bounds[blocked_id]
  var hinge:Node3D=binding.hinges[blocked_id]
  var local:Vector3=hinge.to_local(host.player.global_position)
  var near:Vector3=hinge.to_global(local.clamp(bounds.position,bounds.end))
  if host.player.global_position.distance_to(near)<=Rules.REACH:
   pause_hint.text="The %s is paused. Step aside or hold C to crouch."%mover_noun(int(blocked_id))
   break
 var target:=aimed()
 if target.get("prop",false) and binding.native.field(cover_ref(int(target.id)),Native.FIELD_BYTE26,0)>0:hint.text="Left click — Strike"
 if target.get("kind")=="scripted":hint.text="E — Use"
 if target.get("kind")=="movable":
  var id:int=target.id
  var noun:String=mover_noun(id)
  var phase:int=binding.native.field("movable:%d"%id,Rules.PHASE,0)
  var verb:String="Open" if phase in [0,5] else ("Close" if phase==1 else "Stop")
  hint.text="E — %s %s"%[verb,noun]
  if target.get("primitive",false):hint.text="E — "+("Stop" if phase in [2,3] else "Use")
  if binding.generic_mover_blocked.get(id,false):hint.text="E — Stop %s · Step aside or hold C to crouch"%noun
func other_aimed()->Dictionary:
 var candidates:Array=[]
 var tombs:Node=host.get_node_or_null("L10Tombs")
 if tombs!=null:
  for id in tombs.aims:
   if tombs.opened(id) or not tombs.reachable(id):continue
   var delta:Vector3=tombs.aims[id]-host.camera.global_position
   if delta.length()>0.01 and (-host.camera.global_basis.z).dot(delta.normalized())>=0.97:candidates.append({"owner":tombs,"id":id,"distance":delta.length(),"accept_body":tombs.receptacles[id]})
 var chargers:Node=host.get_node_or_null("Act2Chargers")
 if chargers!=null:
  var id:String=chargers.target()
  if not id.is_empty():
   var delta:Vector3=chargers.globes[id].global_position-host.camera.global_position
   if delta.length()>0.01 and (-host.camera.global_basis.z).dot(delta.normalized())>=0.97:candidates.append({"owner":chargers,"distance":delta.length()})
 var items:Node=host.get_node_or_null("Act2WorldItems")
 if items!=null:
  var id:String=items.target()
  if not id.is_empty():candidates.append({"owner":items,"id":id,"distance":items.aim_point(id).distance_to(host.camera.global_position)})
 var shared:Node=host.get("area_world_items")
 if is_instance_valid(shared):
  var row:int=shared.target()
  if row>=0:candidates.append({"owner":shared,"id":row,"distance":shared.aim_point(row).distance_to(host.camera.global_position)})
 var emperor:Node=host.get_node_or_null("L10Emperor")
 if emperor!=null and emperor.active():
  var id:String=emperor.target()
  if not id.is_empty():
   var delta:Vector3=emperor.AIMS[id]-host.camera.global_position
   if delta.length()>0.01 and (-host.camera.global_basis.z).dot(delta.normalized())>=0.97:candidates.append({"owner":emperor,"distance":delta.length(),"accept_body":emperor.bodies.get(int(id)) if id.is_valid_int() else null})
 var priest:Node=host.get_node_or_null("L10Priest")
 if priest!=null and priest.available() and priest.reachable():
  var delta:Vector3=priest.AIM-host.camera.global_position
  if delta.length()>0.01 and (-host.camera.global_basis.z).dot(delta.normalized())>=0.97:candidates.append({"owner":priest,"distance":delta.length()})
 # The original owners retain reach, form, line-of-sight and story admission.
 # E stays with them; left click invokes exactly the same transaction.
 for owner_name in ["L14Trials","L14TrapRoute","L14FluteSlot","L16Greenhouse","L16SwChips","L19BelialHorn","L19DrainPath","L19DawnElevator","L19DawnCurse"]:
  var owner:Node=host.get_node_or_null(owner_name)
  if owner==null:continue
  var target:Dictionary=owner.generic_target()
  if target.is_empty():continue
  var delta:Vector3=target.point-host.camera.global_position
  if delta.length()>0.01 and (-host.camera.global_basis.z).dot(delta.normalized())>=0.97:
   candidates.append({"owner":owner,"distance":delta.length(),"owned_parts":true,"accept_body":target.get("accept_body"),"point":target.point})
 if candidates.is_empty():return {}
 candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distance<b.distance)
 var best:Dictionary=candidates[0]
 var hit:Dictionary=aimed()
 var collider:Variant=hit.get("collider")
 if hit.get("kind") in ["movable","scripted"]:collider=binding.mover_bodies.get(int(hit.id))
 elif hit.get("kind")=="cover":collider=cover_bodies.get(int(hit.id))
 var own_part:bool=best.get("owned_parts",false) and collider is Node and best.owner.is_ancestor_of(collider)
 # The City class walls (r19o9) made source walls solid, including the sides of a target's own block (the SW chip pedestals,
 # walls 0..49 around a point at 36): a height-boundary hit within 24 of the target point is the target, not a wall before it.
 if collider is Node and str((collider as Node).name)=="HeightBoundaryCollision" and hit.has("position") and best.has("point") and (hit.position as Vector3).distance_to(best.point)<24.0:own_part=true
 if not hit.is_empty() and float(hit.distance)+1.0<float(best.distance) and collider!=best.get("accept_body") and not own_part:return {}
 return best
func would_use()->bool:
 if not active():return false
 var target:Dictionary=aimed()
 return (target.get("kind")=="movable" and bool(movable_use(int(target.id),float(target.distance)).accepted)) or target.get("kind")=="scripted" or not other_aimed().is_empty()
func use_other_aimed()->bool:
 var best:Dictionary=other_aimed()
 if best.is_empty():return false
 var items:Node=host.get_node_or_null("Act2WorldItems")
 var tombs:Node=host.get_node_or_null("L10Tombs")
 if best.owner==items:
  items.take(best.id)
  return true # An eligible use attempt keeps priority even when the pack is full.
 var shared:Node=host.get("area_world_items")
 if is_instance_valid(shared) and best.owner==shared:return shared.collect()
 if best.owner==tombs:return tombs.try_use(best.id)
 return best.owner.try_use()
func _unhandled_input(event:InputEvent):
 if not active():return
 var press_e:bool=event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E
 var click:bool=event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT
 if not press_e and not click:return
 var target:=aimed()
 if target.get("kind")=="movable":
  if use_movable(int(target.id),float(target.distance)):get_viewport().set_input_as_handled()
  elif press_e:
   host.save_feedback("The panel does not respond.");get_viewport().set_input_as_handled()
 elif click and target.get("kind")=="scripted":
  binding.use(int(target.id));get_viewport().set_input_as_handled()
 elif click and target.get("kind")=="cover" and float(target.distance)<=Combat.REACH_PROP:
  if strike(int(target.id)):get_viewport().set_input_as_handled()
 elif click and use_other_aimed():get_viewport().set_input_as_handled()
