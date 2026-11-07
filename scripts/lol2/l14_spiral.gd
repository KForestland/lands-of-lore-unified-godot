extends Node3D
const KEY="l14_spiral"
const TARGET="temple:dreamstone_slot72"
const POINT=Vector3(606,40,-3464)
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const TARGETS={1010:200,965:200,1011:200,963:200,1008:200,1007:200,1006:200,1009:190,1005:180,1004:170,1003:160,1002:150,1001:140,1000:130,999:120,998:110,997:100,996:90,995:80,994:70,993:60,992:50,991:40,990:30,989:20,988:10,987:0,986:-10,985:-20,984:-30,983:-40,982:-50,981:-60,980:-70,979:-80,978:-90,977:-100,976:-110,975:-120}
var host:Node3D
var parts:Dictionary={}
var hint:Label
static func initial()->Dictionary:return {"version":1,"slots":{},"stone":"","raised":0.0}
static func committed(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func recipe(item:String)->Dictionary:return {"target":TARGET,"accepts":[item],"output":"{item}","retrievable":true,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("stone") is String:return "Invalid Temple spiral."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("raised")) or not is_finite(s.raised) or s.raised<0 or s.raised>4:return "Invalid spiral motion."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid spiral transaction."
 if not committed(s):return "" if s==initial() else "Uncommitted spiral changed."
 var slot:=Kit.slot(s,TARGET)
 if s.slots.size()!=1 or slot.size()!=3 or slot.receipts!=[TARGET] or slot.occupied not in ["",s.stone] or Items.definition(s.stone)!=136 or s.stone not in quests.get("act2_items",{}).get("collected",[]):return "Invalid spiral Dreamstone receipt."
 if quests.get("l14_shard_bowls",{}).get("opened",0)!=2:return "Spiral lacks earned bowl passage."
 return ""
static func owns(f:Dictionary)->bool:return (f.get("kind")=="floor" and TARGETS.has(int(f.get("region",-1)))) or (f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==72)
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_spiral.gd").new();n.host=map;n.name="L14Spiral";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in TARGETS:
  var n:=Node3D.new();n.name="OriginalSpiralFloor"+str(id);add_child(n);parts[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if f.get("kind")=="floor" and int(f.get("region",-1))==id:faces.append(f)
  assert(not faces.is_empty(),"Missing original spiral floor "+str(id))
  host.get_node("L14Niche").build(n,faces)
 var slot:=Node3D.new();slot.name="OriginalDreamstoneSlot72";add_child(slot)
 var slot_faces:Array=[]
 for f in pack.faces:
  if f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==72:slot_faces.append(f)
 assert(not slot_faces.is_empty(),"Missing original Dreamstone slot")
 host.get_node("L14Niche").build(slot,slot_faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable()->bool:
 if host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=POINT-host.camera.global_position
 if d.length()<0.01 or d.length()>145 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,POINT,1,[host.player.get_rid()])
 var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(POINT)<18
func interact(action:String,item:String="",capacity:int=64)->Dictionary:
 if not reachable():return Kit.refuse("Approach the Dreamstone slot.")
 if host.quest_state.get("l14_shard_bowls",{}).get("opened",0)!=2:return Kit.refuse("Open the passage behind the bowls first.")
 var s:=state().duplicate(true);var snap:=Kit.empty_snapshot(host.carried_collected,capacity);snap.slots=s.slots
 var result:Dictionary
 if action=="insert":
  if committed(s):return Kit.refuse("The spiral is already unlocked.")
  if Items.definition(item)!=136:return Kit.refuse("The slot needs the Dreamstone.")
  if host.carried_collected.size()>=capacity:return Kit.refuse("Make room before using the slot.")
  result=Kit.offer(snap,recipe(item),item,{"form":"human"})
  if not result.ok:return result
  result=Kit.occupy(snap,result.proposal)
  if not result.ok:return result
  result=Kit.commit(result.snapshot,recipe(item),TARGET)
  if not result.ok:return result
  s.stone=item
 elif action=="retrieve":result=Kit.retrieve(snap,recipe(s.stone))
 else:return Kit.refuse("Unknown slot action.")
 if not result.ok:return result
 s.slots=result.snapshot.slots;host.quest_state[KEY]=s;host.carried_collected=result.snapshot.inventory
 if action=="insert" and host.hand_item==item:host.hand_item=""
 Items.sync(host);restore()
 return {"ok":true,"reason":"The spiral staircase rises. Take back the Dreamstone." if action=="insert" else "You take back the Dreamstone."}
func restore():
 for id in parts:parts[id].position.y=float(TARGETS[id])*float(state().raised)/4
func _physics_process(delta):
 if host.starting_magic.world_active() and committed(state()) and state().raised<4:
  var s:=state().duplicate(true);s.raised=minf(4,s.raised+delta);host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 if reachable():hint.text="E — Retrieve Dreamstone" if Kit.slot(state(),TARGET).occupied!="" else "E — Place Dreamstone" if not committed(state()) else "The spiral is open"
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E or not reachable():return
 var result:Dictionary
 if Kit.slot(state(),TARGET).occupied!="":result=interact("retrieve")
 else:
  var item:String=host.hand_item
  if item.is_empty():
   for id in host.carried_collected:
    if Items.definition(id)==136:item=id;break
  result=interact("insert",item)
 host.save_feedback(result.reason);get_viewport().set_input_as_handled()
