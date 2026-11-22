extends "res://tests/hive_decoded_locks_input_test.gd"
## Immutable owner F9; held creatures, isolated stands and actor obstruction
## are explicit component fixtures. Real E/click/mouse; ordinary 1/60.
var failures:Array[String]=[]
func probe(ok:bool,message:String):
 print("R139 ","GREEN " if ok else "RED ",message)
 if not ok:failures.append(message)
func boot_review()->bool:
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock"):return false
 var rows:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_locks_inputs_manifest.json"));var row:Dictionary=rows.files[0]
 if not check(FileAccess.get_sha256("res://"+row.path)==row.sha256,"Immutable owner bytes"):return false
 scene=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var f:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);f.store_buffer(FileAccess.get_file_as_bytes("res://"+row.path));f.close();Session.for_tree(self).last_slot=10
 if not await reload():return false
 return true
func run():
 if not await boot_review():return
 var owner:Node=scene.get_node("HiveDecodedLocks");var stand:Vector3=scene.player.position
 await press_lock(116);probe(owner.progress==1,"In-range real E reaches the left lock")
 await press_lock(116,true);probe(owner.progress==1,"Left click never changes the E-only lock, including mid-combat")
 owner.restore(owner.initial())
 # The actual creature layer2 must occlude E, even though terrain is layer1.
 await look(Vector3(-3471,-974,-7167));await ticks(2)
 var blocker:=StaticBody3D.new();blocker.collision_layer=2;blocker.collision_mask=0
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(16,40,16);shape.shape=box;blocker.add_child(shape);scene.add_child(blocker)
 blocker.global_position=scene.camera.global_position.lerp(Vector3(-3471,-974,-7167),0.5);await ticks(2)
 await key(KEY_E);probe(owner.progress==0,"A layer2 actor between eye and lock blocks real E")
 blocker.queue_free();await ticks(2)
 # Direct stand is a range fixture, never described as earned movement.
 var target:=Vector3(-3471,-974,-7167);var away:Vector3=(scene.camera.global_position-target).normalized()
 scene.player.position=target+away*121.0-(scene.camera.global_position-scene.player.global_position);await look(target);await ticks(2)
 await key(KEY_E);probe(owner.progress==0,"A 121-unit lock cannot be used beyond the Hive's 110-unit use reach")
 scene.player.position=stand;scene.player.velocity=Vector3.ZERO;await ticks(2)
 owner.restore(owner.initial())
 for id in [116,116,116]:await press_lock(id)
 probe(owner.progress==1 and scene.interface_hud.hint.text=="The lock clicks.","Third-left restarts a prefix with neutral, truthful feedback")
 for id in [116,114,115]:await press_lock(id)
 probe(owner.completed,"The restarted decoded prefix still completes")
 if not failures.is_empty():push_error("R139 input failures: "+str(failures));quit(1);return
 print("PASS R139 real E only, layer2 occlusion, standard reach, neutral third-left, exact decoded completion; owner/stand/held-actor fixtures disclosed")
 quit()
