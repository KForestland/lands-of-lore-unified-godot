extends "res://tests/g04_floor_input_test.gd"
## Original owner stand/pack/health, actual input. Held world/enemies disclosed.
func settled():
 for i in 1800:
  await process_frame
  if scene.get("ready_for_review")==true and is_instance_valid(scene.get("starting_magic")):break
 scene.set_physics_process(false)
 for name in ["Warriors","ConversationReview","ReturnPopulation","AmbushPopulation","ExecutionerLive","RunePopulation","Boulders","HiveDawn20"]:
  var node:Node=scene.get_node_or_null(name)
  if is_instance_valid(node):node.set_physics_process(false);node.set_process(false)
 scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;await ticks(3)
func press_lock(id:int,left:bool=false):
 var positions:={114:Vector3(-3437,-974,-7131),115:Vector3(-3454,-944,-7148),116:Vector3(-3471,-974,-7167)}
 await look(positions[id]);await ticks(2)
 if left:
  for down in [true,false]:
   var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
   Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
 else:await key(KEY_E)
func terrain_hash()->String:
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
 for child in scene.get_children():
  if not child is StaticBody3D:continue
  for collider in child.get_children():
   if collider is CollisionShape3D and collider.shape is ConcavePolygonShape3D:context.update(collider.shape.get_faces().to_byte_array())
 return context.finish().hex_encode()
func frame(tag:String):
 await RenderingServer.frame_post_draw
 var path:="user://tests/hive_locks/";DirAccess.make_dir_recursive_absolute(path)
 root.get_texture().get_image().save_png(path+tag+".png")
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock"):return
 var rows:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_locks_inputs_manifest.json"))
 var row:Dictionary=rows.files[0]
 if not check(FileAccess.get_sha256("res://"+row.path)==row.sha256,"Immutable original owner input"):return
 scene=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var f:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);f.store_buffer(FileAccess.get_file_as_bytes("res://"+row.path));f.close()
 Session.for_tree(self).last_slot=10
 if not await reload():return
 var pack:Dictionary=scene.carried_inventory.duplicate(true);var health:int=scene.starting_magic.health();var stand:Vector3=scene.player.position;var terrain:String=terrain_hash()
 await frame("owner_before")
 await press_lock(116)
 var owner:Node=scene.get_node_or_null("HiveDecodedLocks")
 if not check(owner!=null and owner.progress==1,"Real E on owner's left lock must respond instead of staying silent"):return
 await press_lock(115)
 if not check(owner.progress==0 and not owner.completed and scene.interface_hud.hint.text=="The lock clicks.","Wrong order resets, neutral click, no rise"):return
 for id in [114,114,116,115]:await press_lock(id)
 if not check(owner.progress==0 and not owner.completed and owner.rise==0,"Owner's mirrored order is not an alternative"):return
 await press_lock(116);await press_lock(116);await key(KEY_F5);await ticks(3)
 var doc:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(doc.error.is_empty() and doc.state.area_save.quests.hive_decoded_locks.progress==2,"F5 writes partial sequence"):return
 if not await reload():return
 owner=scene.get_node("HiveDecodedLocks")
 if not check(owner.progress==2,"F9 restores partial native sequence without event replay"):return
 await press_lock(114);await press_lock(115);await key(KEY_F5);await ticks(2)
 doc=Saves.read_document(Saves.slot_path(10))
 if not check(doc.error.is_empty() and doc.state.area_save.quests.hive_decoded_locks.completed and doc.state.area_save.quests.hive_decoded_locks.rise<15,"F5 captures real mid-rise"):return
 var rise:float=doc.state.area_save.quests.hive_decoded_locks.rise
 if not await reload():return
 owner=scene.get_node("HiveDecodedLocks")
 if not check(owner.completed and owner.rise>=rise and owner.rise<15 and owner.sound_log.is_empty(),"F9 resumes physical floor, does not replay group or sounds"):return
 await ticks(90)
 if not check(owner.rise==15 and owner.floor_body.position.y==15,"Only floor760 reaches original-996 at20/s"):return
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3607,-950,-7002),Vector3(-3607,-1050,-7002),1))
 if not check(hit.get("collider")==owner.floor_body and absf(hit.position.y+996)<0.1 and terrain_hash()==terrain,"Raised original footprint collides at-996; main terrain triangles unchanged"):return
 await look(Vector3(-3607,-996,-7002));await frame("native_floor_raised")
 var native_before:Dictionary=owner.native.snapshot()
 await press_lock(115);await ticks(4)
 if not check(owner.native.snapshot()==native_before,"Completed puzzle cannot repeat success/reward"):return
 if not check(scene.player.position.distance_to(stand)<0.1 and scene.carried_inventory==pack and scene.starting_magic.health()==health and scene.resets==0,"Owner stand/HP/pack unchanged; no invented loot or fall recovery"):return
 await key(KEY_F5);await ticks(2)
 if not await reload():return
 owner=scene.get_node("HiveDecodedLocks")
 if not check(owner.completed and owner.rise==15,"Completed physical floor survives F5/F9"):return
 print("PASS owner's exact116,116,114,115 actual E, wrong order, partial+midrise+completedF5F9; native760 only, no rewards")
 quit()
