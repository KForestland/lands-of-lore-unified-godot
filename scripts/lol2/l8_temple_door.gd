extends CanvasLayer
const State=preload("res://scripts/lol2/l8_temple_door_state.gd")
const POINT=Vector3(758,32,2046)
var host:Node3D
var hint:Label
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l8_temple_door.gd").new();n.host=map;n.name="L8TempleDoor";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func _ready():
 layer=34;hint=Label.new();hint.position=Vector2(24,455);add_child(hint)
func reachable()->bool:
 if host.player_form!=0 or not host.starting_magic.world_active():return false
 var d:Vector3=POINT-host.camera.global_position
 return d.length()<170 and d.length()>0.01 and (-host.camera.global_basis.z).dot(d.normalized())>0.85
func can_leave()->bool:return State.unlocked(state()) and State.Kit.slot(state(),State.TARGET).occupied=="" and state().stone in host.carried_collected
func interact(action:String,item:String="")->Dictionary:
 if not reachable():return State.Kit.refuse("Approach the Temple entrance.")
 if action=="enter":
  if not can_leave():return State.Kit.refuse("Use the Dreamstone and take it back first.")
  host.progression.use_exit("prop:1198")
  return {"ok":true,"reason":"You enter the Temple."}
 var result:Dictionary=State.insert(state(),host.carried_collected,item) if action=="insert" else State.retrieve(state(),host.carried_collected) if action=="retrieve" else State.Kit.refuse("Unknown slot action.")
 if not result.ok:return result
 host.quest_state[State.KEY]=result.state;host.carried_collected=result.inventory
 if action=="insert" and host.hand_item==item:host.hand_item=""
 State.Items.sync(host)
 return {"ok":true,"reason":"The entrance opens. Take back the Dreamstone." if action=="insert" else "You take back the Dreamstone."}
func _process(_delta):
 hint.text=""
 if reachable():hint.text="E — Retrieve Dreamstone" if State.Kit.slot(state(),State.TARGET).occupied!="" else "E — Enter Temple" if can_leave() else "E — Place Dreamstone"
func _unhandled_key_input(event:InputEvent):
 if not reachable():return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  var result:Dictionary
  if State.Kit.slot(state(),State.TARGET).occupied!="":result=interact("retrieve")
  elif can_leave():result=interact("enter")
  else:
   var item:String=host.hand_item
   if item.is_empty():
    for id in host.carried_collected:
     if State.Items.definition(id)==136:item=id;break
   result=interact("insert",item)
  host.save_feedback(result.reason);get_viewport().set_input_as_handled()
