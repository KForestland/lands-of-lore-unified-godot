extends "res://tests/helpers/g15_stored_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 const KEY:="l8:shaman:Dracoid_sigil"
 if not await grant_scrolls([KEY]):return
 var gate:Node=scene.get_node("L10MainGate")
 if not await stand_at(Vector3(-125,32,-900)):return
 if not await look(gate.AIM):return
 await frames(12)
 if not require(scene.item_effects.smart_item==KEY and not gate.opened(),"Sigil goes to belt/aim hint without opening the gate"):return
 await tap(KEY_E);await frames(4)
 if not require(gate.opened() and KEY in scene.carried_collected,"Actual E uses real sigil; original non-consumption retained"):return
 scene.queue_free();await frames(3)
 if not await boot_legacy("res://tmp/l14_hopper_platform_qualified_save.json","f594ccfa6a5c7526b4be0d2a74ab6d1e125f8ea0288dcb2494d23e3f91e670d6","lol2-restoration-map-L14_HT","res://scenes/lol2/maps/L14_HT.tscn"):return
 if not await walk([[25,5920]],"grounded weighted-platform approach"):return
 var entry:Node=scene.get_node("L14Belial")
 if not require(entry.can_enter(),"Actual old earned weighted floor admits the original descent"):return
 # Source44 is already committed in tomb91 in this immutable checkpoint.
 # Use an untouched source for this explicitly granted component charge.
 const EMPTY:="act2:L10_DC:item58"
 if not require(EMPTY not in scene.quest_state.act2_items.collected,"Disclosed globe fixture uses an untouched source, not a tomb's occupied globe"):return
 var yellow:=EMPTY+":charged:yellow"
 if not await grant_scrolls([yellow]):return
 if not assert_item_action_saveable("nonduplicated globe component fixture"):return
 scene.item_effects.put_on_belt(yellow,int(scene.item_effects.belt_state().active));await frames(12)
 await tap(KEY_F)
 if not require(not entry.state().entered and EMPTY in scene.carried_collected,"F on platform casts belt globe and does not steal world travel"):return
 if not await disk_cycle("belt_self_before_world_descent"):return
 entry=scene.get_node("L14Belial")
 await tap(KEY_E);await frames(10)
 if not require(entry.state().entered and hp()>0 and scene.resets==0,"Actual E performs original descent; no new requirement or recovery"):return
 await picture("belt_e_world_f_self")
 print("PASS actual sigil aim/E no consumption, original earned Temple platform actual W -> F item/self -> E descent; grants/stand/legacy-load component fixtures")
 quit()
