extends SceneTree
const Rule = preload("res://scripts/lol2/museum_mirror_route.gd")
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize():
 run.call_deferred()
func run():
 assert(Rule.in_approach(Vector3(-4058,12,-1381),Vector3.FORWARD))
 for pos in [Vector3(-4058,12,-1350),Vector3(-4200,12,-1381),Vector3(-4058,100,-1381)]:
  assert(not Rule.in_approach(pos,Vector3.FORWARD))
 assert(not Rule.in_approach(Vector3(-4058,12,-1381),Vector3.BACK))
 var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
 scene.introduction_state = "complete"
 root.add_child(scene)
 current_scene = scene
 scene.carried_collected = [Save.SWORD,Save.MAIL,Save.STONES[0],Save.STONES[1],Save.CAVERN]
 assert(scene.set_equipped_item(Save.SWORD) and scene.set_equipped_armor(Save.MAIL))
 assert(not scene.enter_mirror())
 scene.player.position = Vector3(-4058,12,-1381)
 scene.player.rotation = Vector3.ZERO
 scene.camera.rotation = Vector3.ZERO
 scene.flying = true
 assert(not scene.enter_mirror())
 scene.flying = false
 scene.interface_hud.set_cursor(true)
 assert(not scene.enter_mirror())
 scene.interface_hud.set_cursor(false)
 assert(scene.can_enter_mirror())
 if "--capture-mirror" in OS.get_cmdline_user_args():
  scene.set_physics_process(false)
  scene.interaction_label.text = "E — Enter Shining Path"
  scene.interaction_label.show()
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_progression_20260914/godot_mirror.png")
 var event := InputEventKey.new()
 event.keycode = KEY_E
 event.pressed = true
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 assert(scene.mirror_transition_pending)
 assert(not scene.enter_mirror())
 await process_frame
 await process_frame
 assert(current_scene.get_script().resource_path.ends_with("jungle_walkthrough.gd"))
 assert(not has_meta("lol2_jungle_handoff"))
 assert(current_scene.carried_collected.size() == 5)
 assert(current_scene.equipped_item == Save.SWORD and current_scene.equipped_armor == Save.MAIL)
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Isolate settling from desktop keyboard input.
 for i in range(90): await physics_frame
 assert(current_scene.player.is_on_floor() and current_scene.resets == 0)
 print("Jungle settled position: ",current_scene.player.position)
 assert(Vector2(current_scene.player.position.x,current_scene.player.position.z).distance_to(Vector2(353,-4909)) < 0.1)
 print("Mirror route passed: bounded approach/facing, blocked UI/fly, E transition once, five items/equipment carried, jungle entry settled")
 quit()
