extends SceneTree
## Owner F10 2026-11-03 17-16-20: the dragon lair is a point-and-click picture; clicking the dragon starts the flight.
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize():
 run.call_deferred()
func pixel_at(scene, uv: Vector2) -> Vector2:
 return scene.camera.unproject_position(Vector3(2946.0+uv.x*210.0,120.0-uv.y*140.0,-1247.5))
func run():
 var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
 scene.introduction_state = "complete"
 root.add_child(scene)
 current_scene = scene
 scene.carried_collected = [Save.SWORD,Save.MAIL,Save.STONES[0],Save.STONES[1],Save.CAVERN]
 scene.set_equipped_item(Save.SWORD)
 scene.set_equipped_armor(Save.MAIL)
 scene.set_physics_process(false)
 # Outside the lair the picture does nothing.
 scene.player.position = Vector3(3044,32,-1000)
 await process_frame
 assert(not scene.click_dragon(pixel_at(scene,Vector2(0.48,0.55))))
 scene.player.position = Vector3(3044,32,-1146)
 scene.player.rotation = Vector3.ZERO
 scene.camera.rotation = Vector3.ZERO
 for i in range(30):
  await physics_frame
  scene.player.velocity = Vector3(0,-80,0)
  scene.player.move_and_slide()
 assert(scene.dragon_lair_ready())
 scene.interface_hud.set_cursor(true)
 await process_frame
 # The chest, the torch and the cave wall are not the dragon.
 for uv in [Vector2(0.78,0.72),Vector2(0.88,0.45),Vector2(0.20,0.15)]:
  assert(not scene.dragon_picture_target(pixel_at(scene,uv)))
  assert(not scene.click_dragon(pixel_at(scene,uv)))
 assert(scene.dragon_flight == null)
 # The dragon's body, head and tail are.
 for uv in [Vector2(0.48,0.55),Vector2(0.50,0.40),Vector2(0.10,0.75)]:
  assert(scene.dragon_picture_target(pixel_at(scene,uv)))
 # A real left click on the dragon with the cursor shown starts the dragon journey.
 var click := InputEventMouseButton.new()
 click.button_index = MOUSE_BUTTON_LEFT
 click.pressed = true
 click.position = pixel_at(scene,Vector2(0.48,0.55))
 scene._unhandled_input(click)
 assert(scene.mirror_transition_pending)
 var overlay = scene.dragon_flight
 assert(is_instance_valid(overlay) and overlay.story_clips == [6,7,8])
 assert(not scene.click_dragon(pixel_at(scene,Vector2(0.48,0.55))))
 print("museum_dragon_picture_click_test PASS")
 quit(0)
