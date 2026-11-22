extends SceneTree
const C=preload("res://scripts/lol2/item_catalog.gd")
const D=preload("res://scripts/lol2/item_definitions.gd")
const Fixed=preload("res://scripts/lol2/item_fixed_stats.gd")
const State=preload("res://scripts/lol2/player_item_state.gd")
class Host extends Node3D:
 var player_form:=0
 var carried_inventory:Variant=null
 var carried_collected:Array=[]
 var item_effect_checkpoint:Dictionary={}
 var item_effects:Node
 var interface_hud:Variant=null
 var quest_state:Dictionary={}
func _initialize():
 assert(D.ready())
 for index in D.COUNT:
  var value:Dictionary=Fixed.row(index)
  var byte:int=D.raw_byte(index,0x41)
  var signed:int=byte-256 if byte>=128 else byte
  assert(value.protection==signed,"Original signed protection byte per definition")
  var term:int=D.raw_byte(index,0x40)
  if term>=128:term-=256
  var expected:int=(term if term>0 else 8) if D.slot(index)=="weapon" or index==25 else term if D.slot(index)!="" else 0
  assert(value.damage==expected,"I03 original term used as fixed adapter, flat8 only where missing")
 assert(C.fixed_damage("museum:item11:Fine_Longsword")==12 and C.fixed_damage("jungle:weapon_shop:Long_Arm")==12 and C.fixed_damage("jungle:item16:Rock")==1)
 assert(C.fixed_damage("hive:prop214:Net_of_Exile")==8,"Existing modern Net weapon is preserved")
 assert(C.defense("act2:L14_HT:item71")==30 and C.slot("act2:L14_HT:item71")=="armor")
 assert(C.slot("act2:L20_BB:item0")=="accessory" and C.defense("act2:L20_BB:item0")==0)
 assert(Fixed.row(47).damage==15 and Fixed.row(81).damage==1 and Fixed.row(90).damage==10,"Three I03 nonweapon summing terms")
 assert(C.slot(C.generic_id(48))=="armor","Circlet excludes body armour by one slot")
 assert(not C.admitted(C.generic_id(43),"jungle"),"Generic prototypes remain ungrantable")
 var state:Dictionary=State.initial()
 assert(not state.has("accessories") and State.validate(state,[]).is_empty())
 var ring:String="act2:L10_DC:item33"
 state.accessories=[ring,""]
 assert(State.validate(state,[ring]).is_empty() and State.canonical(state).accessories==state.accessories)
 for bad in [[ring,ring],[ring],[ring,"",""] ,[5,""],["museum:item11:Fine_Longsword",""]]:
  state.accessories=bad;assert(not State.validate(state,[ring]).is_empty())
 state.accessories=[ring,""];assert(not State.validate(state,[]).is_empty())
 var host:=Host.new()
 host.carried_collected=[ring];host.item_effect_checkpoint=State.initial()
 host.item_effects=preload("res://scripts/lol2/player_item_controller.gd").new();host.add_child(host.item_effects);host.item_effects.host=host
 assert(host.item_effects.equip_accessory(ring))
 assert(preload("res://scripts/lol2/item_grants.gd").commit(host,[]).ok)
 assert(not host.item_effect_checkpoint.has("accessories"),"F08 removal retires newly worn accessory, never a dangling quest item")
 host.free()
 print("PASS all170 fixed original-term damage/protection, original byte pin, native equipment/Net/circlet, no generic grants, optional accessory old-state and malformed ownership guards")
 quit()
