extends "res://tests/helpers/act1_owner_object_input.gd"
## Owner's 17Nov crate749 save/stand, genuine Blood identity granted as a disclosed
## test item. Real E/F/S/F5/F9, ordinary six-second fuse; actors held.
const BLOOD:="museum:item1:Dragon_Blood"
const Grants=preload("res://scripts/lol2/item_grants.gd")
func run():
 if not await owner("L7_DH","dh_crates17"):return
 # This unedited save already has exposed crystals; E names both actions.
 await look(scene.crates.center_of(749)+Vector3.UP*(scene.crates.half_of(749).y-1.0))
 await key(KEY_E);await ticks(3)
 if not check(scene.crates.state_of(749)==1,"Actual E identifies the owner's primed crate"):return
 if not check(Grants.grant(scene,BLOOD,{"cap":false,"duplicate":"allow"}).ok,"Disclosed real Blood item fixture enters via F08"):return
 scene.item_effects.put_on_belt(BLOOD,2);scene.item_effects.belt_state().active=2
 var before:int=scene.carried_collected.count(BLOOD)
 await key(KEY_F);await ticks(2)
 print("BLOOD after F bombs=",scene.item_effects.dragon_blood.bombs()," at=",scene.player.position," hint=",scene.interface_hud.hint.text)
 if not check(before==1 and BLOOD not in scene.carried_collected and scene.item_effects.dragon_blood.bombs().size()==1,"Actual belt F arms one saved Blood bomb in Dark Halls"):return
 await key(KEY_F5);await ticks(3)
 var saved:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(saved.error.is_empty(),"F5 admits the Dark Halls bomb during its fuse"):return
 if not await reload():return
 if not check(scene.item_effects.dragon_blood.bombs().size()==1,"F9 resumes one live Blood fuse"):return
 # The original aimed-backward line hits the west wall after39 units.
 # Turn by actual mouse input along the visible north/south corridor, then
 # use ordinary S to get beyond the existing200-unit crate blast.
 await look(scene.camera.global_position+Vector3(0,0,-256))
 scene.set_physics_process(true);await hold_key(KEY_S,180);scene.set_physics_process(false)
 if not check(scene.player.position.distance_to(scene.crates.center_of(749))>220 and scene.starting_magic.health()>0,"ActualS along the source corridor clears the blast before the fuse expires"):return
 await ticks(370)
 print("BLOOD after fuse crate=",scene.crates.state_of(749)," HP=",scene.starting_magic.health()," at=",scene.player.position)
 if not check(scene.crates.state_of(749)==2 and scene.item_effects.dragon_blood.bombs().is_empty() and scene.starting_magic.health()>0,"Ordinary six-second Blood fuse explodes only an exposed crate, player retreats alive"):return
 await key(KEY_F5);await ticks(3)
 saved=Saves.read_document(Saves.slot_path(10))
 if not check(saved.error.is_empty(),"F5 writes the spent bomb and exploded crate"):return
 if not await reload():return
 if not check(scene.crates.state_of(749)==2 and BLOOD not in scene.carried_collected and scene.item_effects.dragon_blood.bombs().is_empty(),"F9 never resurrects bomb/item/crate"):return
 print("PASS Dark Halls actualE/beltF/S six-secondBlood, midfuse F5F9 and spent F5F9; original17Nov owner stand, held actors/slot, one disclosed F08 Blood grant, no earned-chain claim")
 quit()
