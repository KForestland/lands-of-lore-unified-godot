extends "res://tests/helpers/act1_owner_object_input.gd"
## Original slot973 input; actual E/Healing/F/F5/F9. One F08 Blood grant and
## a sub-frame saved-fuse fixture, held actors/slot/belt; no pose/health edit.
const BLOOD:="museum:item1:Dragon_Blood"
const Grants=preload("res://scripts/lol2/item_grants.gd")
func cap_visible()->bool:
 for part in scene.crates.visuals[973].get_children():
  if part.has_meta("source_child_mask") and (int(part.get_meta("source_child_mask"))&2)==0 and part.visible:return true
 return false
func run():
 if not await owner("L7_DH","dh_slot"):return
 scene.set_physics_process(true);await ticks(15);scene.set_physics_process(false)
 var c:Node=scene.crates
 var expected:int=preload("res://scripts/lol2/dark_halls_blast_rules.gd").damage(c.center_of(973),scene.player.global_position,c._blast_source())
 if not check(c.state_of(973)==0 and cap_visible() and not c.crystal_on(973),"ActualF9 into state0 restores closed cap and hides crystals"):return
 await key(KEY_2);await key(KEY_Q);await ticks(35)
 if not check(scene.starting_magic.health()==30,"Ordinary Healing gives the owner room to survive the native26 blast"):return
 await look(c.center_of(973)+Vector3.UP*(c.half_of(973).y-1));await key(KEY_E)
 if not check(c.state_of(973)==1 and not cap_visible() and c.crystal_on(973),"ActualE exposes slot973"):return
 if not check((BLOOD in scene.carried_collected or Grants.grant(scene,BLOOD,{"cap":false,"duplicate":"skip"}).ok),"Genuine Blood fixture"):return
 scene.item_effects.put_on_belt(BLOOD,2);scene.item_effects.belt_state().active=2
 var used:String=preload("res://scripts/lol2/item_belt_state.gd").resolve(scene.item_effects.belt_state(),2,scene.carried_collected)
 await key(KEY_F);await ticks(2)
 print("R141_SLOT placement=",scene.item_effects.dragon_blood.bombs()," feedback=",scene.interface_hud.hint.text," camera=",scene.camera.global_position," center=",c.center_of(973))
 if not check(used not in scene.carried_collected and scene.item_effects.dragon_blood.bombs().size()==1,"ActualF places Blood through the visible original slot"):return
 await key(KEY_F5);await ticks(2)
 var read:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(read.error.is_empty(),"ActualF5 saves primed973 and live Blood"):return
 var doc:Dictionary=read.state
 if not check(doc.area_save.inventory.item_effects.get("dragon_blood",[]).size()==1,"F5 wrote this new live bomb, not an older slot"):return
 if not await reload():return
 if not check(scene.crates.state_of(973)==1 and not cap_visible() and scene.crates.crystal_on(973),"ActualF9 restores state1 masks during the fuse"):return
 # Test only the near-expiry restore ordering; no claim about a player's
 # ability to press F5 inside one frame. The original game-written document
 # changes only this saved timer, preserving all source receipts and clocks.
 doc.area_save.inventory.item_effects.dragon_blood[0].remaining=1.0/120.0
 var file:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);file.store_string(JSON.stringify(doc,"",true,true));file.close()
 if not await reload():return
 await ticks(3)
 if not check(scene.crates.state_of(973)==2 and scene.item_effects.dragon_blood.bombs().is_empty(),"Sub-frame F9 fuse waits for restored crate setup, then explodes973"):return
 if not check(scene.crates.last_damage==expected and scene.starting_magic.health()==30-expected,"Blood applies exactly the same one native26 crate blast as the Spark route, no extra20"):return
 await key(KEY_F5);await ticks(2)
 if not check(Saves.read_document(Saves.slot_path(10)).error.is_empty(),"Spent slot blast remains saveable"):return
 if not await reload():return
 if not check(scene.crates.state_of(973)==2 and scene.starting_magic.health()==30-expected and used not in scene.carried_collected,"F9 preserves exploded slot, spent vial and living4HP"):return
 await frame("r141_slot_blood_complete")
 print("PASS R141 original slot realE/Healing/F/F5F9, state0/1 masks, sub-frame saved-fuse fixture, one native26 blast/4HP, spentF5F9; F08/belt/actor/slot/timer aids disclosed")
 quit()
