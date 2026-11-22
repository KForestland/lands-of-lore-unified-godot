extends "res://tests/helpers/g15_stored_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 var tombs:Node=scene.get_node("L10Tombs")
 var priest:Node=scene.get_node("L10Priest")
 var blue:="act2:L10_DC:item44:charged:blue"
 if not await grant_scrolls([blue,"act2:L9_DR:item55"]):return
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_priest_walk.json"))
 var last:Array=route.door.points.back()
 if not await stand_at(Vector3(last[0],32,last[1])):return
 if not await look(tombs.aims["154"]):return
 await frames(12);await tap(KEY_E);await frames(4)
 if not require(tombs.opened("154") and blue not in scene.carried_collected,"Actual E uses blue as its original tomb key, not a spell"):return
 if not await walk(route.priest.points,"opened priest tomb on foot"):return
 if not await look(priest.AIM):return
 await frames(12);await tap(KEY_E);await frames(4)
 if not require(priest.state().urn_given and "act2:L10_DC:priest_urn" in scene.carried_collected,"First real E still speaks and gives the errand, never blocked by item targeting"):return
 const FULL:="act2:L9_DR:item0"
 if not await grant_scrolls([FULL]):return # Disclosed upstream full-urn fixture, not an earned chapel claim.
 await frames(12)
 if not require(scene.item_effects.smart_item==FULL and scene.item_effects.Catalog.definition(FULL)==168,"Smart priest requirement is exact Fullurn168, never the empty Caretaker urn78"):return
 await tap(KEY_E);await frames(4)
 if not require(FULL not in scene.carried_collected and scene.carried_collected.count("act2:L10_DC:priest_ankh")==1,"Actual E exchanges full ashes urn for exactly one ankh"):return
 await tap(KEY_E)
 if not require(scene.carried_collected.count("act2:L10_DC:priest_ankh")==1 and scene.resets==0,"Repeated real E never duplicates reward or recovers a fall"):return
 await picture("belt_priest_ankh")
 print("PASS real E blue tomb key, W into priest, first E errand still works, exact Fullurn168 smart selection/real E ankh once; disclosed source grants/stand/NPC aid, no earned chapel claim")
 quit()
