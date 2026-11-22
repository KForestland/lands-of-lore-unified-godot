extends "res://tests/item_consumables_input_test.gd"
const ROCK:="jungle:item16:Rock"
const DAGGER:="jungle:item51:Th_Dagger"
const AXE:="jungle:weapon_shop:Long_Arm"
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 if not await grant_scrolls([ROCK,DAGGER,AXE]):return
 scene.quest_state.jungle_world_items={"version":1,"collected":[16]}
 if not await use_food(AXE):return
 if not await look(scene.player.global_position-Vector3(0,28,-40)):return
 await button(MOUSE_BUTTON_RIGHT,Vector2(640,360))
 if not require(scene.item_effects.thrown_items.cooldown>0,"Real right actually launched Long Arm before return"):return
 await frames(32)
 if not require(scene.carried_collected.count(AXE)==1 and AXE not in scene.item_effects.state().spent,"Real right Long Arm returns and is never duplicated/consumed"):return
 for id:String in [ROCK,DAGGER]:
  if not await use_food(id):return
  if not await look(scene.player.global_position-Vector3(0,28,-40)):return
  await button(MOUSE_BUTTON_RIGHT,Vector2(640,360));await frames(32)
  print("THROW_DIAGNOSTIC ",id," hand=",scene.hand_item," carried=",id in scene.carried_collected," spent=",scene.item_effects.state().spent," rows=",scene.item_effects.thrown_items.rows()," available=",scene.starting_magic.available()," cooldown=",scene.item_effects.thrown_items.cooldown," hint=",scene.interface_hud.hint.text)
  if not require(id not in scene.carried_collected and id in scene.item_effects.state().spent and scene.item_effects.thrown_items.rows().size()==1,"Real throw moves one exact identity into saved recoverable world record"):return
  if not await disk_cycle("thrown_world_record"):
   print("THROW_SAVE_DIAGNOSTIC ",scene.interface_hud.hint.text," reason=",scene.can_save()," snapshot=",preload("res://scripts/lol2/act2_save.gd").validate(scene.area_snapshot(),scene.area_save_format));return
  var owner:Node=scene.item_effects.thrown_items
  var record:Dictionary=owner.rows()[0]
  if not require(record.id==id and is_instance_valid(owner.sprites[id]) and owner.sprites[id].visible,"F5/F9 restores the same dropped identity and visible room-bound source art"):return
  if not await look(Vector3(record.position[0],record.position[1],record.position[2])):return
  await tap(KEY_E);await frames(3)
  if not require(scene.carried_collected.count(id)==1 and id not in scene.item_effects.state().spent and scene.item_effects.thrown_items.rows().is_empty(),"Real E recovers exactly once and clears drop/spent state"):return
  await tap(KEY_E)
  if not require(scene.carried_collected.count(id)==1,"Repeated E cannot duplicate a recovered item"):return
 if not await disk_cycle("throw_recovered"):return
 if not require(scene.carried_collected.count(ROCK)==1 and scene.carried_collected.count(DAGGER)==1 and scene.item_effects.thrown_items.rows().is_empty(),"Final F9 preserves all recovered items"):return
 print("PASS actual I/right arms and world right throws LongArm/rock/dagger; returned axe, saved physical drops, realE recovery and duplicate negative, F5/F9; no teleport, grant/history/NPC fixtures")
 quit()
