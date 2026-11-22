extends RefCounted
## WO5 lead 2026-11-15: provisional OWNER-SET mapping, not a native school join.
const State=preload("res://scripts/lol2/player_item_state.gd")
const Grants=preload("res://scripts/lol2/item_grants.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const MAP:={99:{"school":"spark","charge":3},100:{"school":"prism","charge":3},101:{"school":"mists","charge":1}}
static func spell(id:String)->Dictionary:return MAP.get(Items.definition(id),{})
static func ready(controller:Node,id:String)->bool:
 if not MAP.has(Items.definition(id)) or not Items.valid(id) or Items.definition(Items.base_id(id))!=98:return false
 if controller.host.has_method("carried_items") or controller.carried().count(id)!=1 or Items.base_id(id) in controller.carried():return false
 return State.validate(controller.state(),controller.carried()).is_empty()
static func cast(controller:Node,id:String)->bool:
 if not ready(controller,id):return false
 var magic:Node=controller.host.get("starting_magic")
 if not is_instance_valid(magic):return false
 var next:Array=controller.carried().duplicate()
 next[next.find(id)]=Items.base_id(id)
 var admitted:Dictionary=Grants.check_commit(controller.host,next,{"sync":true})
 if not admitted.ok:return controller.refuse_item(admitted.reason)
 var charge:Dictionary=spell(id)
 if not magic.use_stored_charge_from_interface(charge.school,int(charge.charge)):return false
 # Spell receivers can award items; replace the charge in the CURRENT pack,
 # as before, rather than overwriting those synchronous gains with the preview.
 next=controller.carried().duplicate()
 var at:int=next.find(id)
 if at<0:return controller.refuse_item("The charged globe is no longer carried.")
 next[at]=Items.base_id(id)
 # No await between admission, dispatch and one-for-one pack replacement.
 var result:Dictionary=Grants.commit(controller.host,next,{"sync":true})
 if not result.ok:return controller.refuse_item(result.reason)
 if controller.host.get("hand_item")==id:controller.host.hand_item=""
 if controller.state().has("belt"):
  var belt:Dictionary=controller.state().belt
  var previous:int=belt.slots.find(Items.definition(id))
  if previous>=0 and not controller.carried().any(func(item):return Items.definition(item)==Items.definition(id)):
   belt.slots[previous]=98 if not 98 in belt.slots else -1
 controller.host.save_feedback("%s cast. The glass globe is empty."%controller.host.starting_magic.SpellBook.NAMES[charge.school])
 return true
