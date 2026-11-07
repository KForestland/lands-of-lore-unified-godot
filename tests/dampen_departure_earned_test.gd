extends "res://tests/dampen_prerequisite_earned_test.gd"
func run() -> void:
 root.size=Vector2i(1280,720);Engine.time_scale=4;Engine.physics_ticks_per_second=240;AudioServer.playback_speed_scale=4
 scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
 await process_frame;await physics_frame
 var path:="res://tmp/dampen_knowledge_earned_save.json"
 var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tmp/dampen_knowledge_receipt.json"))
 if FileAccess.get_sha256(path)!=receipt.output_sha256 or not scene.quickload(path).is_empty():fail("Earned Dawn knowledge save/hash mismatch");return
 scene.starting_magic.interface_request=true
 const Speech=preload("res://scripts/lol2/monastery_conversation.gd")
 var inventory: Array=scene.carried_collected.duplicate()
 if scene.monastery.state().room=="MOFF":
  scene.monastery.leave_room()
  for i in 100000:
   await process_frame
   if not Speech.active(scene.monastery.state().conversation):break
 if scene.monastery.state().room!="MENT":fail("Actual office exit did not return to hall");return
 scene.monastery.leave_room();scene.set_physics_process(false)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/act_one_departure_route.json"))
 if not await walk_return(route,true):return
 for i in 100000:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/lol2/darker_jungle.tscn":break
 if not is_instance_valid(current_scene) or current_scene.scene_file_path!="res://scenes/lol2/darker_jungle.tscn":fail("Original departure did not reach L8");return
 scene=current_scene;scene.starting_magic.interface_request=true;scene.set_physics_process(false)
 for i in 30:
  await physics_frame
  scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
 if scene.carried_collected!=inventory or scene.resets!=0 or not scene.player.is_on_floor():fail("Departure changed inventory or recovered");return
 if Speech.DAMPEN not in inventory or "jungle:kityara:Empty_hand" not in inventory:fail("Dawn charm/Kityara blade missing");return
 var output:="res://tmp/dampen_darker_arrival_earned_save.json"
 if not scene.quicksave(output).is_empty() or not scene.quickload(output).is_empty():fail("Earned L8 save/reload failed");return
 FileAccess.open("res://tmp/dampen_departure_receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"input_sha256":receipt.output_sha256,"output_sha256":FileAccess.get_sha256(output),"scope":"Separate earned Dawn branch, actual office/hall exits and physical departure movie/L8 arrival; no inventory merge, no repair or Dark Halls claim."},"  ")+"\n")
 print("PASS earned Dawn branch -> physical departure -> actual L8 arrival with charm/blade -> save/reload")
 scene.queue_free();await process_frame;quit()
