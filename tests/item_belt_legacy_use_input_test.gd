extends "res://tests/helpers/g15_stored_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L10_DC"):return
 const FLUTE:="monastery:item94:Iron_Flute"
 if not await grant_scrolls([FLUTE]):return
 scene.item_effects.put_on_belt(FLUTE,int(scene.item_effects.belt_state().active));await frames(12)
 await tap(KEY_F)
 if not require(FLUTE in scene.carried_collected and scene.quest_state.get("hive_elevator",{}).get("flute_signal")==1 and scene.interface_hud.hint.text=="You play the flute.","Actual F retains the canonical flute's original play hook"):return
 scene.queue_free();await frames(3)
 if not await boot_legacy("res://tests/fixtures/item_belt_native_inputs/l8_larkhon_active_earned_save.json","80a4dea2c9563e3ab2bb4934d5f1bae98077eb91c4063ec223c0d784ece4f7f3","lol2-restoration-darker-jungle","res://scenes/lol2/darker_jungle.tscn"):return
 scene.act2_creatures.set_physics_process(false)
 var guardian:Node=scene.get_node("L8Larkhon")
 # Component precondition: keep the actual recipe/source receipts and pack,
 # but start before its activation. The pinned input itself is untouched.
 var prepared:Dictionary=guardian.state().duplicate(true);prepared.active=false
 scene.quest_state[guardian.State.KEY]=prepared
 var potion:String=guardian.State.VAPORS
 scene.item_effects.put_on_belt(potion,int(scene.item_effects.belt_state().active));await frames(12)
 var before:Array=scene.carried_collected.duplicate()
 await tap(KEY_F)
 if not require(guardian.state().active and scene.carried_collected==before,"Actual F activates the existing mixed potion without consuming it"):return
 var point:Vector3=scene.act2_creatures.bodies["115"].global_position-Vector3(130,0,0)
 var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*200,point+Vector3.DOWN*300,1,[scene.player.get_rid()])
 var floor_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
 if not require(not floor_hit.is_empty(),"Component stand has original physical ground"):return
 if not await stand_at(floor_hit.position+Vector3.UP*32):return
 if not await look(guardian.aim()):return
 await frames(12)
 if not require(scene.item_effects.smart_item==potion and guardian.reachable(),"Facing upper chest rolls to the carried active vapors"):return
 await tap(KEY_E);await frames(4)
 if not require(guardian.State.used(guardian.state()) and guardian.asleep() and potion not in scene.carried_collected and scene.resets==0,"Actual E offers through the original dose/sleep transaction"):return
 if not await disk_cycle("belt_larkhon_use"):return
 if not require(scene.get_node("L8Larkhon").asleep() and potion not in scene.carried_collected,"F5/F9 retains consumed vapors and sleep"):return
 print("PASS actual F canonical flute/play, prepared original recipe F activation -> real aim/auto-roll/E chest dose/F5F9; explicit recipe/stand/NPC/grant/legacy input component aids, no earned-chain claim")
 quit()
