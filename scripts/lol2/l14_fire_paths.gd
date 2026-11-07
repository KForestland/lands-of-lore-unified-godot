extends Node3D
const KEY="l14_fire_paths"
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const BUTTONS={"60":Vector3(-3808,185,-709),"61":Vector3(-3023,185,323),"62":Vector3(-2039,185,710)}
const STEPS={4010:200,4005:200,4006:190,4004:180,3988:170,3993:160}
const FAR_LANDING=[Vector2(-1623,-2439),Vector2(-1792,-2439),Vector2(-1793,-2622),Vector2(-1623,-2622)]
var steps:Dictionary={}
var gate:Node3D
var host:Node3D
var parts:Array=[]
var hint:Label
static func initial()->Dictionary:return {"version":1,"buttons":[],"lowered":0.0,"steps":0.0,"gate":0.0}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=5 or s.get("version")!=1 or not s.get("buttons") is Array:return "Invalid fire-path state."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("lowered")) or not is_finite(s.lowered) or s.lowered<0 or s.lowered>4:return "Invalid trial bridge motion."
 for key in ["steps","gate"]:
  if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get(key)) or not is_finite(s[key]) or s[key]<0 or s[key]>2:return "Invalid path mechanism motion."
 if s.steps>0 and "61" not in s.buttons:return "Near steps lack button61."
 if s.gate>0 and (s.lowered!=4 or s.buttons.size()!=3):return "Far gate lacks completed bridge."
 var seen:Array=[]
 for id in s.buttons:
  if not id is String or not BUTTONS.has(id) or id in seen:return "Invalid fire-path button receipt."
  seen.append(id)
 if not s.buttons.is_empty() and "88" not in quests.get("l14_trials",{}).get("doors",[]):return "Fire paths lack right door."
 if s.lowered>0 and s.buttons.size()!=3:return "Bridge lacks three buttons."
 return ""
static func owns(f:Dictionary)->bool:return (f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in [55,56,57]) or (f.get("kind")=="floor" and STEPS.has(int(f.get("region",-1))))
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_fire_paths.gd").new();n.host=map;n.name="L14FirePaths";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in [56,57]:
  var n:=Node3D.new();n.name="OriginalBridgePart"+str(id);add_child(n);parts.append(n)
  var faces:Array=[]
  for f in pack.faces:
   if f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==id:faces.append(f)
  assert(not faces.is_empty(),"Missing original trial bridge part")
  host.get_node("L14Niche").build(n,faces)
 gate=Node3D.new();gate.name="OriginalBigGate55";add_child(gate)
 var gate_faces:Array=[]
 for f in pack.faces:
  if f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==55:gate_faces.append(f)
 assert(not gate_faces.is_empty(),"Missing original far gate55")
 host.get_node("L14Niche").build(gate,gate_faces)
 for id in STEPS:
  var n:=Node3D.new();n.name="OriginalNearStep"+str(id);add_child(n);steps[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if f.get("kind")=="floor" and int(f.get("region",-1))==id:faces.append(f)
  assert(not faces.is_empty(),"Missing original near bridge step")
  host.get_node("L14Niche").build(n,faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable(id:String)->bool:
 if not BUTTONS.has(id) or host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var point:Vector3=BUTTONS[id];var d:Vector3=point-host.camera.global_position
 if d.length()<0.01 or d.length()>130 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()]);var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(point)<18
func press(id:String)->Dictionary:
 if not reachable(id) or "88" not in host.quest_state.get("l14_trials",{}).get("doors",[]):return Kit.refuse("Follow the path to its button.")
 var s:=state().duplicate(true)
 if id in s.buttons:return Kit.refuse("That button is already pressed.")
 s.buttons.append(id);host.quest_state[KEY]=s;restore()
 return {"ok":true,"reason":"Both bridge halves descend." if s.buttons.size()==3 else "A path button clicks into place."}
func restore():
 for part in parts:part.position.y=-132*float(state().lowered)/4
 for id in steps:steps[id].position.y=(float(STEPS[id])-160)*float(state().steps)/2
 if is_instance_valid(gate):gate.position.y=120*float(state().gate)/2
func _physics_process(delta):
 if host.starting_magic.world_active():
  var s:=state().duplicate(true)
  if "61" in s.buttons:s.steps=minf(2,s.steps+delta)
  if s.buttons.size()==3:s.lowered=minf(4,s.lowered+delta)
  var p:Vector3=host.player.position
  var landed:bool=p.y-32>=206 and p.y-32<=214 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),PackedVector2Array(FAR_LANDING))
  if s.lowered==4 and (s.gate>0 or landed):s.gate=minf(2,s.gate+delta)
  if not s.buttons.is_empty():host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 for id in BUTTONS:
  if reachable(id) and id not in state().buttons:hint.text="E — Press path button";return
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 for id in BUTTONS:
  if reachable(id) and id not in state().buttons:host.save_feedback(press(id).reason);get_viewport().set_input_as_handled();return
