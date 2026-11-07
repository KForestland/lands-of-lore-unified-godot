extends SceneTree
const Save = preload("res://scripts/lol2/jungle_save.gd")
func _initialize():
 run.call_deferred()
func run():
 var path := "user://tests/jungle_save_%d.json" % Time.get_ticks_usec()
 var transfer := {"collected":[Save.Museum.SWORD,Save.Museum.MAIL,Save.Museum.STONES[0]],"equipped_item":Save.Museum.SWORD,"equipped_armor":Save.Museum.MAIL}
 set_meta("lol2_jungle_handoff",transfer)
 var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
 root.add_child(scene)
 scene.set_physics_process(false)
 assert(not has_meta("lol2_jungle_handoff"))
 assert(scene.equipped_item == Save.Museum.SWORD and scene.equipped_armor == Save.Museum.MAIL)
 assert(scene.interface_hud.weapon_icon.visible)
 transfer.collected.clear()
 assert(scene.carried_collected.size() == 3)
 scene.player.position = Vector3(353,72,-4909)
 scene.player.rotation.y = 0.7
 scene.camera.rotation.x = -0.3
 assert(scene.quicksave(path).is_empty())
 scene.interface_hud.save_path = path
 scene.interface_hud.run_save_action(false)
 assert(scene.interface_hud.hint.text == "Jungle saved.")
 var saved := Save.read_save(path)
 assert(saved.error.is_empty())
 var original := FileAccess.get_file_as_bytes(path)
 for bad in [null,{},[],{"collected":[],"equipped_item":Save.Museum.SWORD,"equipped_armor":""}, {"collected":[Save.Museum.SWORD,Save.Museum.SWORD],"equipped_item":"","equipped_armor":""}]:
  assert(not scene.apply_inventory_handoff(bad).is_empty())
  assert(scene.carried_collected.size() == 3)
 for bad in [true,NAN,INF,40000,"bad"]:
  var state: Dictionary = saved.state.duplicate(true)
  state.player.position[0] = bad
  assert(not Save.write_save(path,state).is_empty())
  assert(FileAccess.get_file_as_bytes(path) == original)
  assert(not scene.apply_save(state).is_empty())
  assert(scene.player.position == Vector3(353,72,-4909))
 scene.carried_collected.clear()
 scene.equipped_item = ""
 scene.player.position = Vector3.ZERO
 assert(scene.quickload(path).is_empty())
 assert(scene.player.position == Vector3(353,72,-4909))
 assert(scene.equipped_armor == Save.Museum.MAIL and scene.carried_collected.size() == 3)
 scene.free()
 set_meta("lol2_jungle_resume",saved.state)
 scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
 root.add_child(scene)
 scene.set_physics_process(false)
 assert(not has_meta("lol2_jungle_resume"))
 assert(scene.player.position == Vector3(353,72,-4909))
 assert(is_equal_approx(scene.player.rotation.y,0.7) and is_equal_approx(scene.camera.rotation.x,-0.3))
 assert(scene.equipped_item == Save.Museum.SWORD and scene.interface_hud.weapon_icon.visible)
 scene.free()
 DirAccess.remove_absolute(path)
 print("Jungle save passed: validated handoff, disk round-trip, rejected writes preserve save, scene resume, equipment and pose")
 quit()
