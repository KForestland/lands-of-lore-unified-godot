extends "res://tests/helpers/act1_owner_object_input.gd"
## Three unedited 17 Nov owner saves. Real mouse/E/Spark/F5/F9.
## Enemies and host movement held as in the original owner-component helper;
## no pose/health/pack edit. All three source boxes are ALREADY primed.
func view(id:int):
 await look(scene.crates.center_of(id)+Vector3.UP*(scene.crates.half_of(id).y-1.0))
 await ticks(3)
func closed_cap_visible(id:int)->bool:
 for part in scene.crates.visuals[id].get_children():
  if not part is MeshInstance3D or part==scene.crates.crystals[id] or not part.visible:continue
  # The old renderer mixed every source mask into visible meshes. Treat an
  # unclassified source mesh as a closed cap, rather than falsely passing
  # merely because the missing metadata cannot be queried.
  if (int(part.get_meta("source_child_mask",1))&2)==0:return true
 return false
func fresh(slug:String)->bool:
 if is_instance_valid(scene):
  scene.queue_free();await process_frame;await process_frame
 return await owner("L7_DH",slug)
func run():
 for c in [["dh_chest17",973],["dh_crates17",749],["dh_door17",56]]:
  if not await fresh(c[0]):return
  var id:int=c[1]
  if not check(scene.crates.state_of(id)==1,"Original owner save is already primed "+str(id)):return
  if not check(not closed_cap_visible(id) and scene.crates.crystal_on(id),"Primed owner box exposes crystals rather than its closed source cap "+str(id)):return
  await view(id);await key(KEY_E);await ticks(2)
  var has_vial:bool=scene.carried_collected.any(func(item):return item in preload("res://scripts/lol2/dragon_blood_state.gd").ITEMS)
  if not check("Spark" in scene.interface_hud.hint.text and ("Dragon" in scene.interface_hud.hint.text)==has_vial,"E names Spark and Blood only when a usable vial is carried "+str(id)):return
  await frame("dh17_primed_"+str(id))
  await key(KEY_1);await key(KEY_Q);await ticks(4)
  if not check(scene.crates.state_of(id)==1 and "stronger" in scene.interface_hud.hint.text,"Actual weak Spark refuses visibly without changing the crate "+str(id)):return
  if id==56:
   # His later unedited save already pushed448 to the steel door. From his
   # actual reported stand it is visible within SparkIII reach, beyond the
   #200-unit blast radius: no health/position or resource fixture required.
   await ticks(35);await view(448);await modified_q();await ticks(4)
   if not check(scene.crates.state_of(448)==2 and not scene.crates.door_blocking() and scene.starting_magic.health()>0,"Owner17Nov actualControlQ at the exposed moved448 opens the steel door from his stand"):return
  await key(KEY_F5);await ticks(3)
  var saved:Dictionary=Saves.read_document(Saves.slot_path(10))
  if not check(saved.error.is_empty(),"Actual F5 writes the owner's primed state "+str(id)):return
  if not await reload():return
  if not check(scene.crates.state_of(id)==1 and not closed_cap_visible(id),"F9 restores visible priming "+str(id)):return
  if id==56 and not check(scene.crates.state_of(448)==2 and not scene.crates.door_blocking(),"F9 keeps the owner17Nov steel door open"):return
 print("PASS three original17Nov owner chest/crate saves realE/weakSpark/F5F9, visible priming and owned-vial blast choices; held actors/movement/slot, no pose/HP/pack edit")
 quit()
