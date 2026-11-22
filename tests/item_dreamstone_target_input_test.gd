extends "res://tests/item_world_targets_input_test.gd"
const INPUT:="res://tmp/l13_dawn_release_qualified_save.json"
const PIN:="6ace2f6b19e8821944137b8225e154d6b5b1925e071f639330daa6f7209b1c4c"
const STONE:="act2:L13_RC:dreamstone"
const WRONG:="museum:control87:Sk_key"
func missing_stone_refusal()->bool:
 # Independent valid initial component, not deletion from an earned save.
 if not await boot_map("L13_RC"):return false
 scene.act2_creatures.set_physics_process(false)
 if not require(STONE not in scene.carried_collected,"Fresh Citadel has no carried Dreamstone"):return false
 if not await grant_scrolls([WRONG]):return false
 if not await stand_at(Vector3(-3260,32,6600)):return false
 if not await select_target(WRONG):return false
 var owner:Node=scene.get_node("L13ExitLock")
 if not await look(owner.SLOT):return false
 var before:Dictionary=owner.state().duplicate(true)
 var pack:Array=scene.carried_collected.duplicate()
 await tap(KEY_E)
 if not require(scene.interface_hud.hint.text=="The slot needs the Dreamstone." and owner.state()==before and scene.carried_collected==pack,"Real E with only the wrong key gives one plain refusal and changes neither slot nor pack"):return false
 await picture("dreamstone_wrong_key_refusal")
 if not await disk_cycle("dreamstone_missing_wrong_key"):return false
 if not require(not scene.get_node("L13ExitLock").State.unlocked(scene.get_node("L13ExitLock").state()) and scene.carried_collected.count(WRONG)==1,"Missing-stone refusal remains closed and keeps the wrong key through F5/F9"):return false
 scene.queue_free();await frames(3)
 return true
func main():
 if not await missing_stone_refusal():return
 if not await boot_legacy(INPUT,PIN,"lol2-restoration-map-L13_RC","res://scenes/lol2/maps/L13_RC.tscn"):return
 scene.act2_creatures.set_physics_process(false)
 if not await stand_at(Vector3(-3260,32,6600)):return
 if not await grant_scrolls([WRONG]):return
 if not await select_target(WRONG):return
 var owner:Node=scene.get_node("L13ExitLock")
 if not await look(owner.SLOT):return
 if not require(not owner.State.unlocked(owner.state()) and STONE in scene.carried_collected,"Original checkpoint still requires the genuinely carried Dreamstone"):return
 await tap(KEY_E)
 if not require(owner.State.unlocked(owner.state()) and STONE not in scene.carried_collected and WRONG in scene.carried_collected and owner.State.Kit.slot(owner.state(),owner.State.TARGET).occupied==STONE,"Real E uses the carried story-earned Dreamstone despite the unrelated held key, which is retained"):return
 if not await disk_cycle("dreamstone_target_occupied"):return
 owner=scene.get_node("L13ExitLock")
 if not await look(owner.SLOT):return
 await tap(KEY_E)
 if not require(scene.carried_collected.count(STONE)==1 and owner.can_leave(),"Actual E retrieves same stone before departure"):return
 if not await disk_cycle("dreamstone_target_retrieved"):return
 if not require(scene.carried_collected.count(STONE)==1 and scene.carried_collected.count(WRONG)==1,"F9 retains counts and target state"):return
 print("PASS real wrong-key/no-stone E plain atomic refusal/F5F9, then unrelated-held-key E uses carried earned Dreamstone, wrong key retained, place/retrieve/twoF5F9; valid fresh and pinned native-story components, disclosed stands/NPC holds/key grant, not earned walk")
 quit()
