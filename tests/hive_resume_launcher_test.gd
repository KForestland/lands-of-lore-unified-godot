extends SceneTree
const Save = preload("res://scripts/lol2/hive_save.gd")
func _initialize():
 run.call_deferred()
func run():
 var path := "user://tests/launcher_hive_%d.json" % Time.get_ticks_usec()
 var cfg := path + ".cfg"
 var state := {"format":Save.FORMAT,"version":1,"inventory":{"collected":[Save.Shared.Museum.SWORD,Save.Shared.Museum.MAIL],"equipped_item":Save.Shared.Museum.SWORD,"equipped_armor":Save.Shared.Museum.MAIL},"player":{"position":[848,24,-4447],"yaw":0.3,"pitch":-0.2}}
 var quests := Save.Shared.Quests.initial()
 quests.shared_flag_38 = 1
 quests.hive_room_entered = true
 quests.conversation = {"started":true,"completed":false,"section_cursor":0,"elapsed":1.25}
 quests.hive_encounter = Save.Shared.Quests.initial_encounter()
 quests.hive_encounter.enemies = [0,24]
 quests.hive_encounter.pillar_elapsed = 1.0
 state.quests = quests
 assert(Save.write_save(path,state).is_empty())
 var config := ConfigFile.new()
 config.set_value("original_game","exe_path","/home/bob/lol2_out/museum_capture_20260913/game/LOLG.EXE")
 assert(config.save(cfg) == OK)
 var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
 gate.settings_path = cfg
 gate.museum_save_path = path + ".absent"
 gate.jungle_save_path = path + ".absent"
 gate.hive_save_path = path
 root.add_child(gate)
 current_scene = gate
 await process_frame
 await process_frame
 assert(current_scene == gate) # A Hive save must prevent automatic cavern launch.
 gate.path_field.text = ""
 gate._verify_and_start(false,false,true)
 assert(not get_meta("original_game_verified") and not has_meta("lol2_hive_resume"))
 gate.path_field.text = "/home/bob/lol2_out/museum_capture_20260913/game/LOLG.EXE"
 var file := FileAccess.open(path,FileAccess.WRITE)
 file.store_string("{damaged")
 file.close()
 gate._verify_and_start(false,false,true)
 assert(current_scene == gate and not has_meta("lol2_hive_resume"))
 assert(gate.status.text.contains("damaged JSON"))
 assert(Save.write_save(path,state).is_empty())
 await process_frame
 var resume: Button
 for node in gate.find_children("*","Button",true,false):
  if node.text == "Resume Hive": resume = node
 assert(is_instance_valid(resume))
 resume.pressed.emit()
 await process_frame
 await process_frame
 assert(current_scene != null and current_scene.get_script().resource_path.ends_with("hive_review.gd"))
 assert(get_meta("original_game_verified") and not has_meta("lol2_hive_resume"))
 assert(current_scene.player.position.distance_to(Vector3(848,24,-4447)) < 1)
 assert(current_scene.equipped_item == Save.Shared.Museum.SWORD and current_scene.equipped_armor == Save.Shared.Museum.MAIL)
 assert(current_scene.interface_hud.weapon_icon.visible)
 assert(not current_scene.development_mode)
 var actor = current_scene.get_node("ConversationReview")
 assert(actor.started and not actor.completed and actor.frame >= 18)
 assert(actor.audio.playing and not current_scene.is_physics_processing())
 assert(current_scene.get_node("Warriors").enemies == [0,24])
 assert(current_scene.get_node("QuestPillar").opened)
 DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(cfg)
 current_scene.queue_free()
 await create_timer(0.1).timeout
 print("Hive launcher passed: verification required, corrupt save stays in launcher, resume button restores Hive pose and equipment")
 quit()
