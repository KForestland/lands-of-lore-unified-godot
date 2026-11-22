extends "res://tests/hive_locks_r139_input_test.gd"
## Owner slot, supplied floor/lock stands and one synthetic physical actor.
## Actual E/F5/F9; valid dropped-rock fixture; clipped old-load poses and three forms are
## explicit save/contact fixtures, not earned transformations or walking.
const Body=preload("res://scripts/lol2/player_form_body.gd")
func terrain_hash()->String:
 # RegionBlockers intentionally changes its edge expansion with body radius;
 # it is not the main terrain trimesh. Hash the actual terrain bytes only.
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
 for body in scene.get_children():
  if not body is StaticBody3D or body.name=="RegionBlockers":continue
  for collision in body.get_children():
   if collision is CollisionShape3D and collision.shape is ConcavePolygonShape3D:context.update(collision.shape.get_faces().to_byte_array())
 return context.finish().hex_encode()
func run():
 if not await boot_review():return
 var stand:Vector3=scene.player.position;var owner:Node=scene.get_node("HiveDecodedLocks")
 var terrain:String=terrain_hash()
 scene.player.position=Vector3(-3607,-979,-6985);scene.player.velocity=Vector3.ZERO
 # Act1 has no hand/right-throw binding. Use a valid existing dropped-rock
 # ownership fixture, not a false real-input throw claim.
 if not check(scene.item_effects.consume_item("jungle:item16:Rock"),"Fixture removes one carried, unprotected source rock"):return
 if not scene.item_effects.state().has("thrown_items"):scene.item_effects.state().thrown_items=[]
 scene.item_effects.state().thrown_items.append({"id":"jungle:item16:Rock","area":scene.scene_file_path,"position":[-3607,-1007,-7002]})
 var drops:Array=scene.item_effects.state().thrown_items
 scene.player.position=stand;scene.player.velocity=Vector3.ZERO;await ticks(2)
 for id in [116,116,114]:await press_lock(id)
 var actor:=CharacterBody3D.new();actor.collision_layer=2;actor.collision_mask=1
 var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=3;capsule.height=8;collision.shape=capsule;actor.add_child(collision);scene.add_child(actor)
 actor.global_position=Vector3(-3607,-1007,-7002);await ticks(2)
 await press_lock(115)
 scene.player.position=Vector3(-3607,-979,-7002);scene.player.velocity=Vector3.ZERO
 scene.set_physics_process(true);await ticks(8)
 if not check(owner.completed and owner.rise>0 and owner.rise<15 and scene.player.is_on_floor() and scene.player.position.y-32>=-1011+owner.rise-1,"Player inside the rising floor is supported instead of trapped"):return
 if not check(actor.position.y-4>=-1011+owner.rise-1,"Small physical actor is lifted from inside760"):return
 drops=scene.item_effects.state().thrown_items
 if not check(drops[0].position[1]>=-1011+owner.rise+3,"Saved dropped rock rises instead of being sealed under the floor"):return
 actor.queue_free();await key(KEY_F5);await ticks(2)
 var doc:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(doc.error.is_empty() and doc.state.area_save.quests.hive_decoded_locks.rise>0 and doc.state.area_save.quests.hive_decoded_locks.rise<15,"Real F5 writes the occupied mid-rise checkpoint"):return
 var saved:Dictionary=doc.state.duplicate(true)
 for form in [0,1,2]:
  # Reproduce an old save with feet still at the unraised floor. No events
  # are replayed to repair it; real F9 must project its already saved height.
  var clipped:Dictionary=saved.duplicate(true)
  clipped.area_save.player.position=[-3607,-979,-7002]
  clipped.area_save.inventory.player_form=form
  var file:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);file.store_string(JSON.stringify(clipped,"",true,true));file.close()
  var admission:Dictionary=Saves.read_document(Saves.slot_path(10))
  print("R139_CLIPPED form=",form," admission=",admission.error," canload=",scene.can_save()," lastslot=",Session.for_tree(self).last_slot)
  if not check(admission.error.is_empty(),"Clipped old-load fixture remains a valid whole-game document"):return
  if not await reload():
   print("R139_F9 HUD=",scene.interface_hud.hint.text," status=",scene.interface_hud.save_status.text)
   return
  owner=scene.get_node("HiveDecodedLocks");scene.set_physics_process(true);await ticks(8)
  if not check(scene.player_form==form and scene.player.is_on_floor() and scene.player.position.y-32>=-1011+owner.rise-1 and scene.resets==0,"Real F9 occupied mid-rise safely supports full form "+str(form)):return
  await ticks(60)
  if not check(owner.rise==15 and scene.player.position.y-32>=-996.2 and scene.resets==0,"Form stays above the completed solid floor "+str(form)):return
  print("R139_FINAL form=",form," rise=",owner.rise," drop=",scene.item_effects.state().thrown_items[0].position," terrain=",terrain_hash()," original=",terrain)
  if not check(scene.item_effects.state().thrown_items[0].position[1]>=-992.1,"Rock remains recoverable above the solid floor"):return
  if not check(terrain_hash()==terrain,"Original terrain triangles unchanged"):return
 await look(Vector3(-3607,-992,-7002));await frame("occupied_floor760_saved")
 print("PASS R139 valid dropped-rock fixture and actual E completion, occupied mid-rise F5/F9 in Human/Beast/Lizard, small physical actor lifted, solid fill/no underfloor pocket, unchanged main terrain; supplied stands/forms/old clipped-save fixtures disclosed")
 quit()
