extends Node3D
const KEY="l14_trials"
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const DOORS={"90":Vector3(380,230,-2124),"89":Vector3(32,230,-2061),"88":Vector3(-305,230,-2132)}
const IDOL="act2:L14_HT:trial_idol371"
const PRIZE=Vector3(7620,328,-2095)
const PRIZES={"371":PRIZE,"372":Vector3(-38,228,3209),"384":Vector3(-1701,238,-3170)}
var host:Node3D
var parts:Dictionary={}
var hint:Label
static func initial()->Dictionary:return {"version":1,"doors":[],"idols":[]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("doors") is Array or not s.get("idols") is Array:return "Invalid Temple trials."
 if s.doors not in [[],["90"],["90","89"],["90","89","88"]] or s.idols not in [[],["371"],["371","372"],["371","372","384"]]:return "Invalid trial sequence."
 if not s.doors.is_empty() and quests.get("l14_spiral",{}).get("raised",0)!=4:return "Trials lack earned spiral."
 for id in PRIZES:
  if (id in s.idols)!=(("act2:L14_HT:trial_idol"+id) in quests.get("act2_items",{}).get("collected",[])):return "Trial idol receipt mismatch."
 if not s.idols.is_empty() and s.doors.is_empty():return "Trial idol lacks door."
 if "89" in s.doors and "371" not in s.idols:return "Middle door lacks first idol."
 if "372" in s.idols and ("89" not in s.doors or quests.get("l14_tilt",{}).get("settled",0)!=2):return "Middle idol lacks solved floor."
 if "88" in s.doors and "372" not in s.idols:return "Right door lacks second idol."
 if "384" in s.idols and ("88" not in s.doors or quests.get("l14_fire_paths",{}).get("lowered",0)!=4):return "Right idol lacks lowered bridge."
 return ""
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in [88,89,90]
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_trials.gd").new();n.host=map;n.name="L14Trials";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in DOORS:
  var n:=Node3D.new();n.name="OriginalNiceDoor"+id;add_child(n);parts[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if owns(f) and int(f.source_index)==int(id):faces.append(f)
  assert(not faces.is_empty(),"Missing original trial door "+id)
  host.get_node("L14Niche").build(n,faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable(point:Vector3)->bool:
 if host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=point-host.camera.global_position
 if d.length()<0.01 or d.length()>130 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
 var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(point)<20
func open_door(id:String)->Dictionary:
 if not DOORS.has(id) or not reachable(DOORS[id]):return Kit.refuse("Approach a trial door.")
 if host.quest_state.get("l14_spiral",{}).get("raised",0)!=4:return Kit.refuse("Raise the spiral first.")
 if id=="88" and "372" not in state().idols:return Kit.refuse("Bring back the middle statue first.")
 if id=="89" and "371" not in state().idols:return Kit.refuse("Bring back the left-hand statue first.")
 var s:=state().duplicate(true)
 if id in s.doors:return Kit.refuse("The door is already open.")
 s.doors.append(id);host.quest_state[KEY]=s;restore()
 return {"ok":true,"reason":"The left-hand door opens onto the ledge maze." if id=="90" else "The middle door opens." if id=="89" else "The right-hand door opens onto the fire paths."}
func take(capacity:int=64,prop:String="371")->Dictionary:
 if not PRIZES.has(prop) or not reachable(PRIZES[prop]):return Kit.refuse("Approach the trial statue.")
 if "90" not in state().doors:return Kit.refuse("Open the trial door first.")
 if prop=="372" and host.quest_state.get("l14_tilt",{}).get("settled",0)!=2:return Kit.refuse("Press all four high buttons first.")
 if prop=="384" and host.quest_state.get("l14_fire_paths",{}).get("lowered",0)!=4:return Kit.refuse("Lower both bridge halves first.")
 if prop in state().idols:return Kit.refuse("The statue has already been taken.")
 if host.carried_collected.size()>=capacity:return Kit.refuse("Inventory full.")
 var item:="act2:L14_HT:trial_idol"+prop
 var s:=state().duplicate(true);s.idols.append(prop)
 var packet:Dictionary=host.quest_state.get("act2_items",Items.initial()).duplicate(true);packet.collected.append(item)
 host.quest_state[KEY]=s;host.quest_state.act2_items=packet;host.carried_collected.append(item);Items.sync(host);restore()
 return {"ok":true,"reason":"You take the trial statue."}
func restore():
 for id in parts:parts[id].position.y=80 if id in state().doors else 0
 for prop in PRIZES:
  if host.prop_placements.has(int(prop)):
   var row:Array=host.prop_placements[int(prop)];row[0].set_instance_transform(row[1],Transform3D(Basis().scaled(Vector3.ZERO) if prop in state().idols else Basis(),row[2]))
func _process(_delta):
 restore();hint.text=""
 for prop in PRIZES:
  if reachable(PRIZES[prop]) and prop not in state().idols:hint.text="E — Take statue";return
 for id in DOORS:
  if reachable(DOORS[id]) and id not in state().doors:hint.text="E — Open trial door";return
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 for prop in PRIZES:
  if reachable(PRIZES[prop]) and prop not in state().idols:host.save_feedback(take(64,prop).reason);get_viewport().set_input_as_handled();return
 for id in DOORS:
  if reachable(DOORS[id]) and id not in state().doors:host.save_feedback(open_door(id).reason);get_viewport().set_input_as_handled();return
