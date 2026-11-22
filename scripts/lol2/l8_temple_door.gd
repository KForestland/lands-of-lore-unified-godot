extends CanvasLayer
const Grants=preload("res://scripts/lol2/item_grants.gd")
const WalkAway=preload("res://scripts/lol2/dreamstone_walk_away.gd")
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
 if action!="walk_away" and not reachable():return State.Kit.refuse("Approach the Temple entrance.")
 if action=="enter":
  if not can_leave():return State.Kit.refuse("Use the Dreamstone and take it back first.")
  host.progression.use_exit("prop:1198")
  return {"ok":true,"reason":"You enter the Temple."}
 var result:Dictionary=State.insert(state(),host.carried_collected,item) if action=="insert" else State.retrieve(state(),host.carried_collected) if action in ["retrieve","walk_away"] else State.Kit.refuse("Unknown slot action.")
 if not result.ok:return result
 var admission:=Grants.transition(host,result.inventory,{State.KEY:result.state})
 if not admission.ok:return admission
 if action=="insert" and host.hand_item==item:host.hand_item=""
 State.Items.sync(host)
 return {"ok":true,"reason":"The entrance opens. Take back the Dreamstone." if action=="insert" else WalkAway.LINE if action=="walk_away" else "You take back the Dreamstone."}
## Owner r18 2026-11-08 read the shut door as "closed because the priest died". Without a Dreamstone the hint says the
## door is sealed and what opens it (presentation only; gating unchanged, Kimi K47).
const SEALED:="The Temple entrance is sealed. Only the Dreamstone opens it."
## LONGPLAY g_00005-g_00014: the doors stay shut and the next place is the village. The Dreamstone sentence stays.
const NEXT_DANIEL:=" Meet Daniel at the entry and take his blade back. The guard at the great tree wants that blade."
const NEXT_GUARD:=" Show Daniel's blade to the guard at the great tree."
func sealed_hint()->String:
 var journey:Dictionary=host.quest_state.get("l8_journey",{})
 if bool(journey.get("admitted",false)) or not bool(journey.get("temple_visited",false)):return SEALED
 if str(journey.get("gift",""))=="recovered":return SEALED+NEXT_GUARD
 return SEALED+NEXT_DANIEL
func has_stone()->bool:
 for id in host.carried_collected:
  if State.Items.definition(id)==136:return true
 return false
func _physics_process(_delta):
 if WalkAway.due(host,State.unlocked(state()),State.Kit.slot(state(),State.TARGET).get("occupied",""),POINT):host.save_feedback(interact("walk_away").reason)
func _process(_delta):
 hint.text=""
 if reachable():hint.text="E — Retrieve Dreamstone" if State.Kit.slot(state(),State.TARGET).occupied!="" else "E — Enter Temple" if can_leave() else "E — Place Dreamstone" if has_stone() else sealed_hint()
func _unhandled_key_input(event:InputEvent):
 if not reachable():return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  var result:Dictionary
  if State.Kit.slot(state(),State.TARGET).occupied!="":result=interact("retrieve")
  elif can_leave():result=interact("enter")
  else:
   var item:String=host.hand_item
   if State.Items.definition(item)!=136 or item not in host.carried_collected:
    item=""
    for id in host.carried_collected:
     if State.Items.definition(id)==136:item=id;break
   result=interact("insert",item) if not item.is_empty() else State.Kit.refuse(sealed_hint())
  host.save_feedback(result.reason);get_viewport().set_input_as_handled()
