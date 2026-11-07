extends Node3D
const KEY="l14_flute_slot"
const TARGET="temple:flute_slot76"
const POINT=Vector3(-114,190,-1516)
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
var host:Node3D
var parts:Dictionary={}
var hint:Label
static func initial()->Dictionary:return {"version":1,"slots":{},"flute":"","covered":0.0}
static func committed(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func recipe(item:String)->Dictionary:return {"target":TARGET,"accepts":[item],"output":"{item}","retrievable":true,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("flute") is String:return "Invalid Temple oil covers."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("covered")) or not is_finite(s.covered) or s.covered<0 or s.covered>2:return "Invalid oil covers motion."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid oil covers transaction."
 if not committed(s):return "" if s==initial() else "Uncommitted oil covers changed."
 var slot:=Kit.slot(s,TARGET)
 if s.slots.size()!=1 or slot.size()!=3 or slot.receipts!=[TARGET] or slot.occupied not in ["",s.flute] or not accepts(s.flute) or (s.flute!="monastery:item94:Iron_Flute" and s.flute not in quests.get("act2_items",{}).get("collected",[])):return "Invalid oil covers flute receipt."
 if quests.get("l14_trials",{}).get("idols",[]).size()!=3:return "Flute slot lacks three earned idols."
 return ""
static func accepts(item:String)->bool:return item=="monastery:item94:Iron_Flute" or Items.definition(item)==96
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in [76,77,78]
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_flute_slot.gd").new();n.host=map;n.name="L14FluteSlot";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in [76,77,78]:
  var n:=Node3D.new();n.name="OriginalFluteMechanism"+str(id);add_child(n);parts[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==id:faces.append(f)
  assert(not faces.is_empty(),"Missing original flute mechanism")
  host.get_node("L14Niche").build(n,faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable()->bool:
 if host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=POINT-host.camera.global_position
 if d.length()<0.01 or d.length()>145 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,POINT,1,[host.player.get_rid()])
 var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(POINT)<18
func interact(action:String,item:String="",capacity:int=64)->Dictionary:
 if not reachable():return Kit.refuse("Approach the flute slot.")
 if host.quest_state.get("l14_trials",{}).get("idols",[]).size()!=3:return Kit.refuse("Bring back all three idols first.")
 var s:=state().duplicate(true);var snap:=Kit.empty_snapshot(host.carried_collected,capacity);snap.slots=s.slots
 var result:Dictionary
 if action=="insert":
  if committed(s):return Kit.refuse("The oil covers is already unlocked.")
  if not accepts(item):return Kit.refuse("The slot needs the flute.")
  if host.carried_collected.size()>=capacity:return Kit.refuse("Make room before using the slot.")
  result=Kit.offer(snap,recipe(item),item,{"form":"human"})
  if not result.ok:return result
  result=Kit.occupy(snap,result.proposal)
  if not result.ok:return result
  result=Kit.commit(result.snapshot,recipe(item),TARGET)
  if not result.ok:return result
  s.flute=item
 elif action=="retrieve":result=Kit.retrieve(snap,recipe(s.flute))
 else:return Kit.refuse("Unknown slot action.")
 if not result.ok:return result
 s.slots=result.snapshot.slots;host.quest_state[KEY]=s;host.carried_collected=result.snapshot.inventory
 if action=="insert" and host.hand_item==item:host.hand_item=""
 Items.sync(host);restore()
 return {"ok":true,"reason":"The oil covers close. Take back the flute." if action=="insert" else "You take back the flute."}
func restore():
 for id in [77,78]:
  parts[id].position=Vector3(-195,-5,0)*float(state().covered)/2
func _physics_process(delta):
 if host.starting_magic.world_active() and committed(state()) and state().covered<2:
  var s:=state().duplicate(true);s.covered=minf(2,s.covered+delta);host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 if reachable():hint.text="E — Retrieve flute" if Kit.slot(state(),TARGET).occupied!="" else "E — Place flute" if not committed(state()) else "The oil covers is open"
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E or not reachable():return
 var result:Dictionary
 if Kit.slot(state(),TARGET).occupied!="":result=interact("retrieve")
 else:
  var item:String=host.hand_item
  if item.is_empty():
   for id in host.carried_collected:
    if accepts(id):item=id;break
  result=interact("insert",item)
 host.save_feedback(result.reason);get_viewport().set_input_as_handled()
