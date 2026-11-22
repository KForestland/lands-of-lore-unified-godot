extends SceneTree
const Dawn=preload("res://scripts/lol2/jungle_dawn.gd")
class Host extends Node3D:
 var player_form:=1
 var hand_item:=""
 var carried_collected:Array=["hive:Wax_runes:0","hive:Wax_runes:1"]
 var quest_state:Dictionary={}
 var dawn:Node
 var flute_floor:Node
 var item_effects:Node
class Effects extends Node:
 var owner_host:Node
 func carried()->Array:return owner_host.carried_collected
class Floor extends Node:
 const FLUTE:="monastery:item94:Iron_Flute"
 func _active()->bool:return true
 func in_reach()->bool:return true
 func occupied()->bool:return false
 func offer_item(_id:String)->Dictionary:return {"ok":true,"reason":"Test floor"}
class Probe extends "res://scripts/lol2/jungle_dawn.gd":
 var test_context:Dictionary={"shared":{},"locals":{}}
 func can_use()->bool:return true # Isolate form/native-offer rules; not an aim/geometry claim.
 func context()->Dictionary:return test_context
 func belt_aimed()->bool:return true
 func held_item()->String:return host.hand_item
 func use()->bool:return true # Fault: claims success without consumption/state change.
func _initialize():run.call_deferred()
func run():
 var host:=Host.new();root.add_child(host)
 var effects:=Effects.new();effects.owner_host=host;host.item_effects=effects;host.add_child(effects)
 var dawn:=Probe.new();dawn.set_physics_process(false);dawn.set_process(false);dawn.host=host
 dawn.src=Dawn.State.source();dawn.state=Dawn.State.initial(dawn.src);dawn.state.present=true
 host.dawn=dawn
 host.add_child(dawn);dawn.set_physics_process(false);dawn.set_process(false)
 assert(dawn.belt_wax().is_empty(),"Nonhuman belt and hint share the Human admission")
 for form in [1,2]:
  host.player_form=form;host.hand_item=""
  assert(dawn.belt_wax().is_empty() and dawn.interaction_hint()=="Return to Human form to give Dawn the Wax runes.","Nonhuman empty hand has no smart give and a truthful instruction")
  host.hand_item="hive:Wax_runes:0"
  assert(dawn.belt_wax().is_empty() and dawn.interaction_hint()=="E — give the Wax runes to Dawn","Original held-item E remains truthful even without the smart belt")
 host.player_form=0;host.hand_item=""
 var builds_before:int=dawn.get("wax_preview_runs")
 var before:Dictionary=dawn.state.duplicate(true);var source:Dictionary=dawn.src.duplicate(true);var context:Dictionary=dawn.test_context.duplicate(true);var pack:Array=host.carried_collected.duplicate()
 for i in 100:
  assert(dawn.belt_wax()=="hive:Wax_runes:0" and dawn.interaction_hint()=="E — give the Wax runes to Dawn")
 assert(dawn.state==before and dawn.src==source and dawn.test_context==context and host.carried_collected==pack,"N previews cannot mutate source, context, encounter or pack")
 assert(dawn.get("wax_preview_runs")==builds_before+1,"Hint/find share one native preview per frame")
 assert(not Dawn.Runes.valid("jungle:item50:Wax") and not Dawn.Runes.valid("hive:Wax_runes:23") and not Dawn.Runes.valid("hive:Wax_runes:01"),"Only exact native copied-runes identities are eligible")
 var floor:=Floor.new();host.add_child(floor);host.flute_floor=floor
 assert(preload("res://scripts/lol2/item_belt_targets.gd").find(host).owner==floor,"An already aimed flute floor keeps priority even when Dawn could accept Wax")
 host.flute_floor=null;floor.queue_free()
 host.carried_collected.append("monastery:item94:Iron_Flute");host.hand_item="monastery:item94:Iron_Flute"
 var rejected:Dictionary=dawn.belt_offer_wax("hive:Wax_runes:0")
 assert(not rejected.ok and host.hand_item=="monastery:item94:Iron_Flute" and host.carried_collected.has("hive:Wax_runes:0") and host.carried_collected.has("hive:Wax_runes:1"),"A true use bool without delivered state cannot claim success; canonical held_call restores the owned Flute")
 var sentinel:=RefCounted.new();dawn.test_context.sentinel=sentinel
 await process_frame
 assert(dawn.belt_wax().is_empty(),"An Object context is refused before the native evaluator")
 dawn.test_context.erase("sentinel");dawn.src.sentinel=sentinel
 await process_frame
 assert(dawn.belt_wax().is_empty(),"An Object source is refused before the native evaluator")
 dawn.src.erase("sentinel");dawn.state.locals["17"]=1
 await process_frame
 assert(dawn.belt_wax().is_empty(),"Already given native29704 closes even with a spare copy")
 host.free()
 print("PASS R144 Human/native-only predicate, two exact copies,100 pure cached previews, Object source/context rejection and given-state closure; mocked can-use, no world aim claim")
 quit()
