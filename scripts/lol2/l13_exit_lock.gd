extends Node3D
const State=preload("res://scripts/lol2/l13_exit_lock_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const SLOT=Vector3(-3391,70,6670)
var host:Node3D
var gate:Node3D
var hint:Label
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1))==105
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_exit_lock.gd").new();n.host=map;n.name="L13ExitLock";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func _ready():
 gate=Node3D.new();gate.name="OriginalFrontDoor105";add_child(gate)
 var faces:Array=[]
 for f in JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file)).faces:
  if owns(f):faces.append(f)
 host.get_node("L13Eggs").build(gate,faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
 restore()
func restore():
 if not is_instance_valid(gate):return
 var opened:=State.unlocked(state())
 gate.visible=not opened;gate.get_node("Collision").collision_layer=0 if opened else 1
 if host.preview_assemblies.solid_bodies.has(105):host.preview_assemblies.solid_bodies[105].collision_layer=0
 host.get_node("RegionBlockers").set_region_blocked(489,not opened)
func reachable()->bool:
 if host.player_form!=0 or not host.starting_magic.world_active():return false
 var d:Vector3=SLOT-host.camera.global_position
 return d.length()<170 and d.length()>0.01 and (-host.camera.global_basis.z).dot(d.normalized())>0.85
func can_leave()->bool:return State.unlocked(state()) and State.Kit.slot(state(),State.TARGET).occupied=="" and state().stone in host.carried_collected
func interact(action:String,item:String="")->Dictionary:
 if not reachable():return State.Kit.refuse("Approach the wall slot.")
 var result:Dictionary=State.insert(state(),host.carried_collected,item) if action=="insert" else State.retrieve(state(),host.carried_collected) if action=="retrieve" else State.Kit.refuse("Unknown slot action.")
 if not result.ok:return result
 host.quest_state[State.KEY]=result.state;host.carried_collected=result.inventory
 if action=="insert" and host.hand_item==item:host.hand_item=""
 Items.sync(host);restore()
 return {"ok":true,"reason":"The entrance opens. Take the Dreamstone back." if action=="insert" else "You take back the Dreamstone."}
func _process(_delta):
 hint.text=""
 if reachable():hint.text="E — Retrieve Dreamstone" if State.Kit.slot(state(),State.TARGET).occupied!="" else "E — Place Dreamstone" if not State.unlocked(state()) else "The way out is open"
func _unhandled_key_input(event:InputEvent):
 if not reachable():return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  var result:Dictionary
  if State.Kit.slot(state(),State.TARGET).occupied!="":result=interact("retrieve")
  else:
   var item:String=host.hand_item
   if item.is_empty():
    for id in host.carried_collected:
     if Items.definition(id)==136:item=id;break
   result=interact("insert",item)
  host.save_feedback(result.reason);get_viewport().set_input_as_handled()
