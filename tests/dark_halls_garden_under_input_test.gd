extends "res://tests/dark_halls_garden_ground_input_test.gd"
## Under-bed load fixture: copy the pinned owner document and change only its
## player position to feet375 (five below soil380). Real F9/ordinary physics.
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock"):return
 var pin:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dark_halls_ground_inputs_manifest.json")).files[0]
 var path:String="res://"+pin.path
 if not check(FileAccess.get_sha256(path)==pin.sha256,"Original input before disclosed pose fixture"):return
 var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 doc.area_save.player.position=[1780,407,-3300]
 scene=load("res://scenes/lol2/dark_halls.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var file:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);file.store_string(JSON.stringify(doc,"",true,true));file.close();Session.for_tree(self).last_slot=10
 if not await reload():return
 scene.set_physics_process(true)
 var resolved:=false
 for i in 600:
  await physics_frame
  if not check(is_finite(scene.player.position.y) and scene.starting_magic.health()>0 and scene.resets<=1,"Under-bed load remains finite/alive without a reset loop"):return
  if scene.player.is_on_floor() and scene.player.position.y-32>=379:
   resolved=true;break
 if not check(resolved,"Five-under-bed load resolves to ground/recovery within ten seconds, never trapped under a hidden ceiling"):return
 print("R142_UNDER at=",scene.player.position," resets=",scene.resets)
 await frame("r142_under_bed_resolved")
 print("PASS R142 actualF9/physics from disclosed five-under-bed pose fixture terminates on ground alive; held actors/route/slot, no earned-route claim")
 quit()
