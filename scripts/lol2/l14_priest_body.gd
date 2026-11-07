extends Node3D
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const KEY="l14_priest_body"
const BODY="world:L14_HT:prop274"
const TARGET="temple:slab816"
const START=Vector3(2493,0,-2856)
const SLAB=Vector3(2413,2,-3328)
var host:Node3D
var hint:Label
static func initial()->Dictionary:return {"version":1,"phase":"source","slots":{}}
static func recipe()->Dictionary:return {"target":TARGET,"accepts":[BODY],"output":"{item}","retrievable":false,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,_quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or s.get("phase") not in ["source","carried","placed"] or not s.get("slots") is Dictionary:return "Invalid Temple body state."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid body placement transaction."
 if s.phase!="placed":return "" if s.slots.is_empty() else "Unplaced body has slab receipt."
 if s.slots.size()!=1:return "Invalid slab receipts."
 var slot:=Kit.slot(s,TARGET)
 if slot.occupied!=BODY or not slot.committed or slot.receipts!=[TARGET]:return "Body placement receipt mismatch."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_priest_body.gd").new();n.host=map;n.name="L14PriestBody";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func available()->bool:return host.player_form==0 and not host.flying and host.starting_magic.world_active()
func reach(point:Vector3)->bool:
 if not available():return false
 var d:Vector3=point-host.camera.global_position
 return d.length()>0.01 and d.length()<150 and (-host.camera.global_basis.z).dot(d.normalized())>0.8
func interact(action:String)->Dictionary:
 var s:=state().duplicate(true)
 if action=="carry":
  if s.phase!="source" or not reach(START+Vector3.UP*7):return Kit.refuse("Approach the priest's body.")
  s.phase="carried"
 elif action=="place":
  if s.phase!="carried" or not reach(SLAB):return Kit.refuse("Carry the body to the stone rectangle.")
  # This snapshot represents the one carried world body, not a second player inventory.
  var snap:=Kit.empty_snapshot([BODY],1);snap.slots=s.slots
  var result:=Kit.offer(snap,recipe(),BODY,{"form":"human"})
  if not result.ok:return result
  result=Kit.occupy(snap,result.proposal)
  if not result.ok:return result
  result=Kit.commit(result.snapshot,recipe(),TARGET)
  if not result.ok:return result
  s.slots=result.snapshot.slots;s.phase="placed"
 else:return Kit.refuse("Unknown body action.")
 host.quest_state[KEY]=s;restore()
 return {"ok":true,"reason":"You carry the priest's body." if s.phase=="carried" else "You lay the body lengthwise on the stone rectangle."}
func restore():
 if not host.prop_placements.has(274):return
 var at:=START
 if state().phase=="placed":at=SLAB
 elif state().phase=="carried":
  var forward:Vector3=-host.player.global_basis.z;forward.y=0
  at=host.player.position+forward.normalized()*36-Vector3.UP*28
 var row:Array=host.prop_placements[274];row[0].set_instance_transform(row[1],Transform3D(Basis().scaled(Vector3.ZERO) if host.quest_state.get("l14_priest_ritual",{}).get("vanished",false) else Basis(),at))
func _process(_delta):
 restore();hint.text=""
 if state().phase=="source" and reach(START+Vector3.UP*7):hint.text="E — Carry priest's body"
 elif state().phase=="carried":hint.text="E — Place body on stone rectangle" if reach(SLAB) else "Carrying the priest's body"
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  var action:="carry" if state().phase=="source" and reach(START+Vector3.UP*7) else "place" if state().phase=="carried" and reach(SLAB) else ""
  if not action.is_empty():host.save_feedback(interact(action).reason);get_viewport().set_input_as_handled()
