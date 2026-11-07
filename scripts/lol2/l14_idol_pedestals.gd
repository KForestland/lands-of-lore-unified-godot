extends Node3D
const KEY="l14_idol_pedestals"
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const IDOLS=["act2:L14_HT:trial_idol371","act2:L14_HT:trial_idol372","act2:L14_HT:trial_idol384"]
const CASES={"85":Vector3(154,190,3556),"86":Vector3(19,190,3637),"87":Vector3(-119,190,3549)}
var host:Node3D
var bridge:Dictionary={}
var plan:Dictionary={}
var idols:Dictionary={}
var hint:Label
static func initial()->Dictionary:return {"version":1,"slots":{},"assembled":0.0}
static func complete(s:Dictionary)->bool:
 for id in CASES:
  if not Kit.slot(s,id).committed:return false
 return true
static func recipe(id:String)->Dictionary:return {"target":id,"accepts":IDOLS,"output":"{item}","retrievable":false,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("slots") is Dictionary:return "Invalid idol pedestals."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("assembled")) or not is_finite(s.assembled) or s.assembled<0 or s.assembled>4:return "Invalid idol stair motion."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid idol transaction."
 var seen:Array=[]
 for id in s.slots:
  if not CASES.has(id):return "Unknown idol pedestal."
  var slot:=Kit.slot(s,id)
  if slot.occupied not in IDOLS or slot.occupied in seen or not slot.committed or slot.receipts!=[id] or slot.occupied not in quests.get("act2_items",{}).get("collected",[]):return "Idol receipt mismatch."
  seen.append(slot.occupied)
 if s.assembled>0 and not complete(s):return "Stairs lack three unique idols."
 return ""
static func owns(f:Dictionary)->bool:
 return (f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in [85,86,87]) or (f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1))>=90 and int(f.get("source_index",-1))<=103)
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_idol_pedestals.gd").new();n.host=map;n.name="L14IdolPedestals";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 plan=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/l14_idol_bridge_plan.json"))
 for id in CASES:
  var n:=Node3D.new();n.name="OriginalIdolCase"+id;add_child(n);n.position.y=-250
  var faces:Array=[]
  for f in pack.faces:
   if f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==int(id):faces.append(f)
  assert(not faces.is_empty(),"Missing original idol case")
  host.get_node("L14Niche").build(n,faces)
  var statue:=Sprite3D.new();statue.texture=ImageTexture.create_from_image(Image.load_from_file(Items.row(IDOLS[0]).icon));statue.pixel_size=0.5;statue.position=CASES[id]+Vector3.UP*40;statue.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;statue.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(statue);idols[id]=statue
 for id in plan:
  var n:=Node3D.new();n.name="OriginalMovingStair"+id;add_child(n);bridge[id]=n
  var faces:Array=[];var origin:Array=plan[id]["from"]
  for f in pack.faces:
   if f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1))==int(id):
    var face:Dictionary=f.duplicate(true)
    for p in face.points:
     for j in 3:p[j]-=origin[j]
    faces.append(face)
  assert(not faces.is_empty(),"Missing original moving stair")
  host.get_node("L14Niche").build(n,faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable(id:String)->bool:
 if not CASES.has(id) or host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=CASES[id]-host.camera.global_position
 if d.length()<0.01 or d.length()>130 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,CASES[id],1,[host.player.get_rid()]);var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(CASES[id])<18
func offer(id:String,item:String,capacity:int=64)->Dictionary:
 if not reachable(id):return Kit.refuse("Approach the idol pedestal.")
 if host.carried_collected.size()>=capacity:return Kit.refuse("Make room before placing the idol.")
 var s:=state().duplicate(true);var snap:=Kit.empty_snapshot(host.carried_collected,capacity);snap.slots=s.slots
 var result:=Kit.offer(snap,recipe(id),item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe(id),id)
 if not result.ok:return result
 s.slots=result.snapshot.slots;host.quest_state[KEY]=s;host.carried_collected=result.snapshot.inventory
 if host.hand_item==item:host.hand_item=""
 Items.sync(host);restore();return {"ok":true,"reason":"The stairs form a crossing." if complete(s) else "The idol rests on its pedestal."}
func restore():
 var fraction:float=float(state().assembled)/4
 for id in idols:idols[id].visible=Kit.slot(state(),id).committed
 for id in bridge:
  var a:Array=plan[id]["from"];var b:Array=plan[id].to
  bridge[id].position=Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),fraction)
  bridge[id].rotation.y=deg_to_rad((fposmod(float(plan[id].heading_to)-float(plan[id].heading_from)+32768,65536)-32768)*360/65536)*fraction
func _physics_process(delta):
 if host.starting_magic.world_active() and complete(state()) and state().assembled<4:
  var s:=state().duplicate(true);s.assembled=minf(4,s.assembled+delta);host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 for id in CASES:
  if reachable(id) and not Kit.slot(state(),id).committed:hint.text="E — Place Jkar idol";return
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 for id in CASES:
  if reachable(id) and not Kit.slot(state(),id).committed:
   var item:String=host.hand_item
   if item.is_empty():
    for candidate in IDOLS:
     if candidate in host.carried_collected:item=candidate;break
   host.save_feedback(offer(id,item).reason);get_viewport().set_input_as_handled();return
