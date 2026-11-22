extends "res://tests/helpers/act1_owner_object_input.gd"
## Untouched17Nov chest save, actual mouse/E/F/W/F5F9 at1/60.
## Held actors/slot, one F08 vial and belt-selection fixtures; no pose/HP edit.
const BLOOD="museum:item1:Dragon_Blood"
const Grants=preload("res://scripts/lol2/item_grants.gd")
const SLOT_LINE="The blast reaches you here. Dragon's Blood through the slot gives you time to get clear; Spark from here costs about 26 health."
func run():
 if not await owner("L7_DH","dh_chest17"):return
 var c:Node=scene.crates
 var target:Vector3=c.center_of(973)+Vector3.UP*(c.half_of(973).y-1)
 await look(target);await ticks(8)
 if not check(c.state_of(973)==1 and scene.starting_magic.health()==30,"Original owner primed973/30HP stand"):return
 if not check(c.hint.text==SLOT_LINE,"Owner973 slot hint gives measured cost and delayed Blood way out"):return
 if not check(c.hint.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and c.hint.get_global_rect().end.x<=root.get_visible_rect().size.x and c.hint.get_global_rect().end.y<=root.get_visible_rect().size.y,"Whole slot warning wraps inside rendered viewport"):return
 await frame("dh973_slot_warning")
 await key(KEY_E);await ticks(2)
 if not check(scene.interface_hud.hint.text==SLOT_LINE,"RealE at973 repeats exact screen sentence"):return
 if not check(Grants.grant(scene,BLOOD,{"cap":false,"duplicate":"skip"}).ok,"Disclosed one-vial F08 fixture, no source save edit"):return
 scene.item_effects.put_on_belt(BLOOD,2);scene.item_effects.belt_state().active=2
 await key(KEY_F);await ticks(2)
 if not check(BLOOD not in scene.carried_collected and scene.item_effects.dragon_blood.bombs().size()==1,"ActualF places one vial through owner slot"):return
 var started:int=Engine.get_physics_frames()
 await look(scene.camera.global_position+Vector3(0,0,-256))
 scene.set_physics_process(true)
 set_key(KEY_W,true)
 var distance:=0.0
 for i in 240:
  await physics_frame
  distance=Vector2(scene.player.position.x-c.center_of(973).x,scene.player.position.z-c.center_of(973).z).length()
  if distance>=205:break
 set_key(KEY_W,false)
 var escape_steps:int=Engine.get_physics_frames()-started
 print("CHEST973_BLOOD_ESCAPE steps=",escape_steps," seconds=",escape_steps/60.0," distance=",distance," position=",scene.player.position," state=",c.state_of(973)," health=",scene.starting_magic.health())
 if not check(distance>=205 and escape_steps<330 and c.state_of(973)==1 and scene.player.is_on_floor() and scene.resets==0,"PlainW north along slot wall gets clear before ordinary six-second fuse"):return
 await ticks(380)
 scene.set_physics_process(false)
 if not check(c.state_of(973)==2 and scene.starting_magic.health()==30 and scene.resets==0 and scene.item_effects.dragon_blood.bombs().is_empty(),"One delayed crate blast opens973 after escape, zeroHP lost/recovery"):return
 var old_hash:String=FileAccess.get_sha256(Saves.slot_path(10))
 await key(KEY_F5);await ticks(3)
 if not check(Saves.read_document(Saves.slot_path(10)).error.is_empty() and FileAccess.get_sha256(Saves.slot_path(10))!=old_hash,"ActualF5 writes escaped chest result"):return
 if not await reload():return
 if not check(scene.crates.state_of(973)==2 and scene.starting_magic.health()==30 and BLOOD not in scene.carried_collected,"ActualF9 keeps opened973/30HP/spentvial"):return
 print("PASS exact owner973 realE/F/plainW/F5F9, measured cost26 and truthful Blood escape; one F08 vial/belt/actor/slot fixtures, no pose/HP edit")
 quit()
