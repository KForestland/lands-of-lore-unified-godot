extends "res://tests/helpers/g15_spell_input.gd"
## Existing game-written three-idol approach, actual E/F5/F9; no quest bootstrap.
const INPUT:="res://tmp/l14_flute_approach_qualified_save.json"
const PIN:="d691b1ffa7f4de91c7fdc2cafa72771414573f9f179ac1d8f20c0850ed2fb22e"
func _initialize():main.call_deferred()
func main():
 if not await boot_legacy(INPUT,PIN,"lol2-restoration-map-L14_HT","res://scenes/lol2/maps/L14_HT.tscn"):return
 var slot:Node=scene.get_node("L14FluteSlot")
 if not await look(slot.POINT):quit(1);return
 await tap(KEY_E);await ticks(150)
 slot=scene.get_node("L14FluteSlot")
 if not require(slot.committed(slot.state()) and slot.state().covered==2 and not slot.state().flute.is_empty(),"RealE places an actually carried flute and moves both covers"):return
 var flute:String=slot.state().flute
 if not require(flute not in scene.carried_collected and slot.Kit.slot(slot.state(),slot.TARGET).occupied==flute,"Exact flute occupies saved slot, not pack"):return
 if not await disk_cycle("g04_flute_placed"):return
 slot=scene.get_node("L14FluteSlot")
 if not require(slot.Kit.slot(slot.state(),slot.TARGET).occupied==flute and flute not in scene.carried_collected and slot.state().covered==2,"F9 keeps placed item and completed cover motion"):return
 for id in [77,78]:
  if not require(slot.parts[id].position==Vector3(-195,-5,0) and slot.parts[id].get_node("Collision").collision_layer==1,"Actual restored oil-cover collision "+str(id)):return
 if not await look(slot.POINT):quit(1);return
 await tap(KEY_E)
 if not require(scene.carried_collected.count(flute)==1 and slot.Kit.slot(slot.state(),slot.TARGET).occupied.is_empty(),"RealE retrieves exact flute once"):return
 if not await disk_cycle("g04_flute_retrieved"):return
 slot=scene.get_node("L14FluteSlot")
 if not require(scene.carried_collected.count(flute)==1 and slot.state().covered==2 and slot.Kit.slot(slot.state(),slot.TARGET).occupied.is_empty(),"F9 retains retrieved item and cover state independently"):return
 print("PASS G04 L14 realE places/retrieves original carried flute, both realF5/F9 rounds retain exact slot/pack/cover collision; pinned existing approach, no new earned claim")
 quit()
