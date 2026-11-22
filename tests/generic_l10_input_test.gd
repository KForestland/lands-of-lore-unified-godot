extends SceneTree
## B local rendered proof. One disclosed owner-report vantage; not an earned route.
var scene: Node3D
var folder := "user://tests/generic_l10"
func _initialize(): run.call_deferred()
func key(code: Key):
 for down in [true,false]:
  var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down
  Input.parse_input_event(event); Input.flush_buffered_events(); await physics_frame
func shot(tag: String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+tag+".png")
func run():
 assert(DisplayServer.get_name() != "headless", "Rendered generic object proof")
 DirAccess.make_dir_recursive_absolute(folder)
 scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();root.add_child(scene);current_scene=scene
 for tick in 1800:
  await process_frame
  if scene.ready_for_review and scene.progression!=null:break
 assert(scene.ready_for_review and scene.progression!=null, "Staged production map")
 scene.set_physics_process(false)
 scene.progression.change_scene_enabled=false
 if scene.act2_creatures!=null:scene.act2_creatures.set_physics_process(false)
 scene.player.position=Vector3(1041.1764,32.0475,-1359.0178);scene.player.velocity=Vector3.ZERO
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 var target:=Vector3(1029,40,-1296)
 var offset:Vector3=target-scene.camera.global_position
 var yaw:=atan2(-offset.x,-offset.z);var pitch:=atan2(offset.y,Vector2(offset.x,offset.z).length())
 var mouse:=InputEventMouseMotion.new();mouse.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003)
 Input.parse_input_event(mouse);Input.flush_buffered_events()
 for tick in 3:await physics_frame
 await shot("before")
 var before:Transform3D=scene.progression.hinges[86].transform if scene.progression.hinges.has(86) else Transform3D.IDENTITY
 print("BEFORE realE movable86 hosted=",scene.progression.hinges.has(86)," position=",scene.player.position)
 await key(KEY_E)
 for tick in 60:await physics_frame
 await shot("after_E")
 var changed:bool=scene.progression.hinges.has(86) and scene.progression.hinges[86].transform.origin.distance_to(before.origin)>1.0
 print("AFTER realE movable86 hosted=",scene.progression.hinges.has(86)," moved=",changed," resets=",scene.resets)
 if not changed:push_error("B generic: realE must move the originally shut crypt top86");quit(1);return
 print("PASS B local rendered realE moves crypt top86; one supplied vantage, no earned-route claim")
 quit()
