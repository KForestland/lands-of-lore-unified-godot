extends "res://tests/helpers/act1_owner_object_input.gd"
## Untouched owner inputs, genuine F08 Blood fixture, actual mouse/E/F/S.
## No pose/health edit; actors/slot/belt selection are component aids.
const BLOOD:="museum:item1:Dragon_Blood"
const Grants=preload("res://scripts/lol2/item_grants.gd")
func fresh(slug:String)->bool:
 if is_instance_valid(scene):scene.queue_free();await process_frame;await process_frame
 return await owner("L7_DH",slug)
func supply()->bool:
 if not check((BLOOD in scene.carried_collected or Grants.grant(scene,BLOOD,{"cap":false,"duplicate":"skip"}).ok),"Genuine Blood fixture"):return false
 scene.item_effects.put_on_belt(BLOOD,2);scene.item_effects.belt_state().active=2
 return true
func kept(wanted:String)->bool:
 var pack:Array=scene.carried_collected.duplicate();var spent:Array=scene.item_effects.state().spent.duplicate()
 await key(KEY_F);await ticks(2)
 return check(scene.carried_collected==pack and scene.item_effects.state().spent==spent and scene.item_effects.dragon_blood.bombs().is_empty() and wanted in scene.interface_hud.hint.text,"Refused Blood keeps vial/spent/world and gives its named reason: "+wanted)
func run():
 if not await fresh("dh_slot") or not await supply():return
 var c:Node=scene.crates
 await look(c.center_of(973)+Vector3.UP*(c.half_of(973).y-1))
 if not await kept("Expose"):return
 if not await fresh("dh_crates17") or not await supply():return
 await look(scene.camera.global_position+Vector3(0,0,-256))
 scene.set_physics_process(true);await hold_key(KEY_S,180);scene.set_physics_process(false)
 if not check(scene.player.position.distance_to(scene.crates.center_of(749))>220,"RealS leaves the source crate cluster"):return
 if not await kept("No exposed"):return
 if not await fresh("dh_slot") or not await supply():return
 c=scene.crates
 await look(c.center_of(973)+Vector3.UP*(c.half_of(973).y-1));await key(KEY_E)
 await look(scene.player.global_position+Vector3(8,-30,0))
 if not await kept("No exposed"):return
 print("PASS R141 actualF refuses closed/far/occluded crystal targets, named lines, vial/spent/world unchanged; realS, original owner stands, disclosed F08/belt/actor/slot fixtures")
 quit()
