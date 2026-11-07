extends Node3D
## Prima101 ordering with original switch61/movable74 and barrel477/177/176.
## Timed tipping/rolling and oil presentation are modern adapters, not opcode18 replay.
const KEY:="l10_barrel"
const SWITCH:=Vector3(-1515,43,-2984)
const TOP:=Vector3(-1458,82,-1952)
const START:=Vector3(-1440,50,-1950)
const END:=Vector3(-1435,0,-3376)
const SPEED:=160.0
var host: Node3D
var presented: String=""
var hint: Label
var barrel: StaticBody3D
const PUDDLES:=[165,166,167,168,169,170,171,172,173]
static func initial()->Dictionary:return {"version":1,"switch":false,"phase":0,"distance":0.0}
static func validate(s: Variant)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("switch") is bool:return "Invalid Cemetery barrel state."
 var phase=s.get("phase")
 if not (phase is int or phase is float) or phase!=floor(phase) or phase<0 or phase>2:return "Invalid Cemetery barrel phase."
 var d=s.get("distance")
 if not (d is int or d is float) or not is_finite(d) or d<0 or d>1426:return "Invalid Cemetery barrel distance."
 if (s.phase==0 and d!=0) or (s.phase==1 and (not s.switch or d>=1426)) or (s.phase==2 and (not s.switch or d!=1426)):return "Inconsistent Cemetery barrel progress."
 return ""
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_barrel.gd").new();node.host=map;node.name="L10Barrel";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 for id in [61,62,176,177]:host.preview_assemblies.stateful_meshes[id]=[]
 barrel=StaticBody3D.new();barrel.name="UprightBarrel477";barrel.collision_layer=1;barrel.collision_mask=0
 var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=12;cylinder.height=30;shape.shape=cylinder
 barrel.add_child(shape);barrel.position=Vector3(-1458,65,-1952);add_child(barrel)
 for id in PUDDLES:
  host.preview_assemblies.stateful_meshes[id]=[]
  host.preview_assemblies.presence[id]=false
  host.preview_assemblies.set_mode(id,0)
  host.preview_assemblies.set_offset(id,Vector3.UP*0.2)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,450);canvas.add_child(hint)
 restore()
func visible_prop(id: int,show: bool):
 if not host.prop_placements.has(id):return
 var row: Array=host.prop_placements[id]
 row[0].set_instance_transform(row[1],Transform3D(Basis() if show else Basis().scaled(Vector3.ZERO),row[2]))
func restore():
 var s:=state();var burned: bool=host.quest_state.get("l10_oil",{}).get("burned",false)
 var signature:=str(s.switch)+":"+str(s.phase)+":"+str(burned)
 if presented!=signature:
  presented=signature
  host.preview_assemblies.set_mode(61,1 if s.switch else 0)
  for mesh in host.preview_assemblies.stateful_meshes[61]:mesh.visible=not burned
  host.preview_assemblies.set_mode(62,0)
  host.preview_assemblies.set_mode(176,2 if s.phase==1 else 0)
  host.preview_assemblies.set_mode(177,0)
  visible_prop(477,s.phase==0)
  for id in [327,328]:visible_prop(id,s.phase==2 and not burned)
  barrel.collision_layer=1 if s.phase==0 else 0
  for id in PUDDLES:host.preview_assemblies.set_present(id,s.phase==2 and not burned)
  host.progression.travel[74]=int(host.progression.native.attributes["movable:74"].angle_word) if s.switch else 0
  host.progression._pose(74)
  # Native travel100 is known; the original hinge axis is not. Withdraw the source panel upward.
  var origin: Vector3=host.progression.hinge_origin[74]
  if s.switch:origin.y+=host.progression.mover_bounds[74].size.y+8
  host.progression.mover_targets[74]=Transform3D(Basis(),origin)
 if s.phase==1:
  var point:=START.lerp(END,float(s.distance)/1426.0)
  # Follow the source floor under the barrel instead of interpolating through stairs.
  var region: int=host.progression.region_at(point)
  if region>=0:point.y=float(host.progression.regions[region][1])
  host.preview_assemblies.set_offset(176,point-START)
func reachable(point: Vector3,own: Object=null)->bool:
 var delta: Vector3=point-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
 var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.collider==own
func active()->bool:return not get_tree().paused and not host.flying and host.starting_magic.world_active()
func flip()->Dictionary:
 if not active() or not reachable(SWITCH):return {"ok":false,"reason":"Approach and face the switch."}
 if not host.get_node("L10Tombs").opened("109"):return {"ok":false,"reason":"The white tomb is sealed."}
 if state().switch:return {"ok":false,"reason":"The switch is already set."}
 var s:=state().duplicate();s.switch=true;host.quest_state[KEY]=s;restore();return {"ok":true}
func tip()->Dictionary:
 if not active() or not reachable(TOP,barrel):return {"ok":false,"reason":"Face the top of the barrel."}
 if host.player_form!=0:return {"ok":false,"reason":"You need human hands."}
 if not state().switch or state().phase!=0:return {"ok":false,"reason":"The barrel cannot be tipped now."}
 if host.player.position.z<=-1952:return {"ok":false,"reason":"Get behind the barrel to push it toward the north tomb."}
 var s:=state().duplicate();s.phase=1;host.quest_state[KEY]=s;restore();return {"ok":true}
func _physics_process(delta: float):
 if not active() or state().phase!=1:return
 var s:=state().duplicate();var point:=START.lerp(END,float(s.distance)/1426.0)
 # Live bodies can stop the barrel; killing/moving the obstruction resumes it.
 for id in host.act2_creatures.state.actors:
  var actor: Dictionary=host.act2_creatures.state.actors[id]
  if actor.health<=0 or not actor.present:continue
  var p: Variant=actor.get("position",[])
  if p is Array and p.size()==3 and Vector2(p[0]-point.x,p[2]-point.z).length()<40 and absf(p[1]-point.y)<80:return
 s.distance=minf(1426,float(s.distance)+delta*SPEED)
 if s.distance==1426:s.phase=2;host.save_feedback("The barrel breaks open and oil spreads across the north tomb.")
 host.quest_state[KEY]=s;restore()
func _process(_delta):
 restore();hint.text=""
 if not active():return
 if not state().switch and reachable(SWITCH):hint.text="E — Flip switch"
 elif state().phase==0 and reachable(TOP,barrel):hint.text="E — Tip barrel toward the north tomb"
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if not active() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var result: Dictionary
 if reachable(SWITCH):result=flip()
 elif reachable(TOP,barrel):result=tip()
 else:return
 host.save_feedback("The caretaker's door opens." if result.ok and state().phase==0 else ("The barrel rolls away." if result.ok else result.reason))
 get_viewport().set_input_as_handled()
