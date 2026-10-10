extends SceneTree
const Save = preload("res://scripts/lol2/jungle_save.gd")
func _initialize():
 run.call_deferred()
func run():
 var path := "user://tests/launcher_jungle_%d.json" % Time.get_ticks_usec()
 var cfg := path + ".cfg"
 var state := {"format":Save.FORMAT,"version":1,"inventory":{"collected":[Save.Museum.SWORD,Save.Museum.MAIL],"equipped_item":Save.Museum.SWORD,"equipped_armor":Save.Museum.MAIL},"player":{"position":[353,72,-4909],"yaw":0.3,"pitch":-0.2}}
 assert(Save.write_save(path,state).is_empty())
 var config := ConfigFile.new()
 config.set_value("original_game","exe_path","/home/bob/lol2_out/museum_capture_20260913/game/LOLG.EXE")
 assert(config.save(cfg) == OK)
 var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
 gate.settings_path = cfg
 gate.museum_save_path = path + ".absent"
 gate.jungle_save_path = path
 root.add_child(gate)
 current_scene = gate
 await process_frame
 await process_frame
 assert(current_scene == gate) # A jungle save must prevent automatic cavern launch.
 gate.path_field.text = ""
 gate._verify_and_start(false,true)
 assert(not get_meta("original_game_verified") and not has_meta("lol2_jungle_resume"))
 gate.path_field.text = "/home/bob/lol2_out/museum_capture_20260913/game/LOLG.EXE"
 var file := FileAccess.open(path,FileAccess.WRITE)
 file.store_string("{damaged")
 file.close()
 gate._verify_and_start(false,true)
 assert(current_scene == gate and not has_meta("lol2_jungle_resume"))
 assert(gate.status.text.contains("damaged JSON"))
 assert(Save.write_save(path,state).is_empty())
 await process_frame
 var resume: Button
 for node in gate.find_children("*","Button",true,false):
  if node.text == "Resume jungle": resume = node
 assert(is_instance_valid(resume))
 for pressed in [true,false]:
  var click := InputEventMouseButton.new()
  click.position = resume.get_global_rect().get_center()
  click.button_index = MOUSE_BUTTON_LEFT
  click.pressed = pressed
  Input.parse_input_event(click)
  Input.flush_buffered_events()
 await process_frame
 await process_frame
 assert(current_scene != null and current_scene.get_script().resource_path.ends_with("jungle_walkthrough.gd"))
 assert(get_meta("original_game_verified") and not has_meta("lol2_jungle_resume"))
 assert(current_scene.player.position.distance_to(Vector3(353,72,-4909)) < 1)
 assert(current_scene.equipped_item == Save.Museum.SWORD and current_scene.equipped_armor == Save.Museum.MAIL)
 assert(current_scene.interface_hud.weapon_icon.visible)
 DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(cfg)
 print("Jungle launcher passed: verification required, corrupt save stays in launcher, GUI resume restores jungle pose and equipment")
 quit()
