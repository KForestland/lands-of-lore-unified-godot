extends SceneTree
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize():
 run.call_deferred()
func run():
 var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
 scene.introduction_state = "complete"
 root.add_child(scene)
 current_scene = scene
 scene.carried_collected = [Save.SWORD,Save.MAIL,Save.STONES[0],Save.STONES[1],Save.CAVERN]
 scene.set_equipped_item(Save.SWORD)
 scene.set_equipped_armor(Save.MAIL)
 assert(not scene.enter_dragon())
 scene.player.position = Vector3(3040,32,-1216)
 scene.player.rotation = Vector3.ZERO
 scene.camera.rotation = Vector3.ZERO
 scene.interface_hud.set_cursor(true)
 assert(not scene.enter_dragon())
 scene.interface_hud.set_cursor(false)
 scene.flying = true
 assert(not scene.enter_dragon())
 scene.flying = false
 scene.set_physics_process(false)
 # Walked arrival settles near centerY15 on the descending source floor.
 for i in range(60):
  await physics_frame
  scene.player.velocity = Vector3(0,-80,0)
  scene.player.move_and_slide()
 assert(scene.player.is_on_floor() and scene.player.position.y < 16)
 assert(scene.can_enter_dragon())
 var grounded_y: float = scene.player.position.y
 scene.player.position.y = 7
 assert(not scene.can_enter_dragon())
 scene.player.position.y = 57
 assert(not scene.can_enter_dragon())
 scene.player.position.y = grounded_y
 var event := InputEventKey.new()
 event.keycode = KEY_E
 event.pressed = true
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 assert(paused and not scene.enter_dragon())
 var overlay = scene.dragon_flight
 assert(overlay.review.video.is_playing())
 assert(overlay.review.selected == 6)
 if "--full-dragon" in OS.get_cmdline_user_args():
  create_timer(65,true).timeout.connect(func(): push_error("Dragon playback timed out"); quit(1))
  var reason: String = await overlay.ended
  assert(reason == "finished")
 else:
  # Completion signals exercise clip ordering quickly; full mode waits for decoding.
  overlay.review.video.finished.emit()
  assert(overlay.review.selected == 7)
  overlay.review.video.finished.emit()
  assert(overlay.review.selected == 8)
  overlay.close()
 for i in range(4): await process_frame
 assert(not paused and current_scene.get_script().resource_path.ends_with("jungle_walkthrough.gd"))
 assert(current_scene.carried_collected.size() == 5 and current_scene.equipped_item == Save.SWORD and current_scene.equipped_armor == Save.MAIL)
 for i in range(90): await physics_frame
 assert(current_scene.player.is_on_floor() and current_scene.resets == 0)
 print("Dragon route passed: approach guards, ordered original clips, modal pause, completion/skip transfers once, inventory/equipment and grounded jungle arrival")
 quit()
