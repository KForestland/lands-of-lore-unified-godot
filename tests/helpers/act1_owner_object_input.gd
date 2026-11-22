extends "res://tests/helpers/owner_gaps_input.gd"
## Untouched owner whole-save via F9. Local component stands/actor holds are
## declared by each case; no earned campaign claim and no inventory/health aid.
func settled():
 for i in 1800:
  await process_frame
  if scene.get("ready_for_review")==true and is_instance_valid(scene.get("starting_magic")):break
 scene.set_physics_process(false)
 for name in ["DarkHallsCreatures","DarkHallsRix","DarkHallsRoute","Warriors","ConversationReview","ReturnPopulation","AmbushPopulation","ExecutionerLive","RunePopulation","Boulders","BoulderAudio","HiveDawn20"]:
  var node:=scene.get_node_or_null(name)
  if is_instance_valid(node):node.set_physics_process(false);node.set_process(false)
 if is_instance_valid(scene.get("act2_creatures")):scene.act2_creatures.set_physics_process(false)
 scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;await ticks(3)
func owner(area:String,slug:String)->bool:
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock"):return false
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/act1_owner_objects_manifest.json"))
 var rows:Array=manifest.inputs.filter(func(row):return row.slug==slug)
 if not check(rows.size()==1 and FileAccess.get_sha256(rows[0].path)==rows[0].sha256,"Immutable original owner input "+slug):return false
 scene=load(preload("res://scripts/lol2/game_areas.gd").ROWS[area].scene).instantiate()
 root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var file:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(rows[0].path));file.close()
 Session.for_tree(self).last_slot=10
 return await reload()
func modified_q():
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_Q;event.physical_keycode=KEY_Q;event.ctrl_pressed=true;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
