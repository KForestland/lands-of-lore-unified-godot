extends "res://tests/helpers/act1_owner_object_input.gd"
## Original owner slot stand and save; real E, Spark1/3, one Healing cast, F5/F9. Held actors.
## The close explosion deals26: owner26HP heals to30 via ordinary Q before it.
func run():
 if not await owner("L7_DH","dh_slot"):return
 scene.set_physics_process(true);await ticks(15);scene.set_physics_process(false)
 var crates:Node=scene.crates
 await look(crates.center_of(973));await key(KEY_E)
 if not check(crates.state_of(973)==0,"Opaque window lip still blocks the centre ray; no through-wall E"):return
 await look(crates.center_of(973)+Vector3.UP*(crates.half_of(973).y-1));await ticks(3);await frame("dh_slot_before")
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(scene.camera.global_position,crates.center_of(973),257,[scene.player.get_rid()]))
 print("SLOT stand=",scene.player.position," center=",crates.center_of(973)," hit=",hit.get("collider")," aim=",crates._aimed()," path=",hit.get("collider").get_path() if hit.has("collider") else "none"," hit=",hit.get("position")," normal=",hit.get("normal")," meta=",hit.get("collider").get_meta_list() if hit.has("collider") else [])
 var visible:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.camera.global_position-scene.camera.global_basis.z*120,257,[scene.player.get_rid()]))
 print("SLOT actual crosshair=",visible.get("collider")," wanted=",crates.bodies[973]," hit=",visible.get("position"))
 await key(KEY_E);await ticks(3)
 print("SLOT afterE state=",crates.state_of(973)," hint=",scene.interface_hud.hint.text)
 if not check(crates.state_of(973)==1,"Owner can prime source crate973 through the slot with actual E"):return
 await key(KEY_1)
 var mana_before:int=scene.starting_magic.magic_state().player.mana
 await key(KEY_Q)
 if not check(int(scene.starting_magic.magic_state().player.mana)==mana_before-1,"Weak Spark retains its ordinary one-mana cast cost before the receiver refusal"):return
 await ticks(4)
 if not check(crates.state_of(973)==1,"Weak Spark preserves the primed slot crate"):return
 await ticks(35);await key(KEY_2);await key(KEY_Q);await ticks(35);await key(KEY_1)
 await modified_q();await ticks(4)
 print("SLOT afterSpark state=",crates.state_of(973)," HP=",scene.starting_magic.health()," blast=",crates.last_damage," stand=",scene.player.position," notice=",scene.starting_magic.notice)
 if not check(crates.state_of(973)==2 and scene.starting_magic.health()>0,"Real Spark3 explodes source slot crate973, no pose/HP aid"):return
 await key(KEY_F5);await ticks(3)
 var saved:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(saved.error.is_empty() and saved.state.area_save.quests.get("dark_halls_crates",{}).get("crates",{}).get("973",{}).get("s")==2,"Actual F5 writes exploded973"):return
 if not await reload():return
 if not check(scene.crates.state_of(973)==2,"F9 preserves slot crate explosion"):return
 print("PASS owner actual E/Spark through slot973/F5/F9, original stand/HP/pack, held actors, no pose edit")
 quit()
