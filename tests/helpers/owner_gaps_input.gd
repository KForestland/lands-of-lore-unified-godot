extends "res://tests/g04_floor_input_test.gd"
## Owner's unchanged F10 whole saves, real F9 to enter, actual input after load.
## Local stands/held creatures in the tiger-switch case are disclosed separately.
func boot_owner(area:String,slug:String)->bool:
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock"):return false
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/owner_gaps_inputs/manifest.json"))
 var rows:Array=manifest.inputs.filter(func(row):return row.file==slug+".json")
 if not check(rows.size()==1,"Exactly one immutable owner input"):return false
 var path:="res://tests/fixtures/owner_gaps_inputs/"+slug+".json"
 if not check(FileAccess.get_sha256(path)==rows[0].sha256,"Owner input pin"):return false
 scene=load(preload("res://scripts/lol2/game_areas.gd").ROWS[area].scene).instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var file:=FileAccess.open(Saves.slot_path(1),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(path));file.close()
 Session.for_tree(self).last_slot=1 # Slot selection fixture; untouched owner bytes enter via actual F9.
 return await reload()
func hold_key(code:Key,n:int):
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events()
  if down:await ticks(n)
func frame(tag:String):
 var folder:="user://tests/owner_gaps/";DirAccess.make_dir_recursive_absolute(folder)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+tag+".png")

func set_key(code:Key,down:bool):
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
 Input.parse_input_event(event);Input.flush_buffered_events()
