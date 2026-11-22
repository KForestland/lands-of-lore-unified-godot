extends RefCounted
## R126: only the two real alcove doors. No state injection, collision edits or relocation.
static func key(code:int,down:bool):
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
static func point(scene:Node,id:int)->Vector3:return scene.progression.hinges[id].global_transform*scene.progression.mover_bounds[id].get_center()
static func closed(scene:Node,id:int)->bool:return scene.progression.hinges.has(id) and int(scene.progression.native.field("movable:%d"%id,"travel_0x50",0))==0
static func look(tree:SceneTree,scene:Node,where:Vector3)->bool:
 # Older tests aim combat rays by rotating Camera directly. Restore the normal
 # player-yaw/camera-pitch split, then turn through actual mouse events.
 scene.camera.rotation=Vector3(scene.camera.rotation.x,0,0)
 for tick in 40:
  var d:Vector3=where-scene.camera.global_position
  if (-scene.camera.global_basis.z).dot(d.normalized())>0.999:return true
  var yaw:float=wrapf(atan2(-d.x,-d.z)-scene.player.global_rotation.y,-PI,PI)
  var pitch:float=atan2(d.y,Vector2(d.x,d.z).length())-scene.camera.rotation.x
  var event:=InputEventMouseMotion.new();event.relative=Vector2(-yaw/0.003,-pitch/0.003).clamp(Vector2(-300,-300),Vector2(300,300));Input.parse_input_event(event);Input.flush_buffered_events();await tree.process_frame
 return false
static func legacy(tree:SceneTree,scene:Node)->bool:
 if scene.area_id!="L9_DR":return true
 if not (closed(scene,102) or closed(scene,103)):return true
 if minf(scene.camera.global_position.distance_to(point(scene,102)),scene.camera.global_position.distance_to(point(scene,103)))>85:return true
 if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
  for down in [true,false]:
   var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down;click.position=Vector2(640,360);Input.parse_input_event(click);Input.flush_buffered_events();await tree.process_frame
 var world:Node=scene.get_node("GenericObjects")
 for id in [102,103]:
  if not closed(scene,id):continue
  if not await look(tree,scene,point(scene,id)):return false
  var aimed:Dictionary=world.aimed()
  if aimed.get("kind")!="movable" or int(aimed.get("id",-1))!=id:
   push_error("R126 Tower leaf%d is occluded: %s"%[id,aimed]);return false
  key(KEY_E,true);await tree.process_frame;key(KEY_E,false)
  for tick in 12:await tree.physics_frame
  if closed(scene,id):push_error("R126 actual E did not open Tower door%d"%id);return false
  print("R126 DOOR ",id," realE open; native travel=",scene.progression.native.field("movable:%d"%id,"travel_0x50",0))
 # The old route aimed through the north leaf's swing. Use the visible centre
 # of the double doorway after opening BOTH leaves, not the swung panel.
 var before:int=scene.get_node("L9Tower").transports.size()
 var was_processing:bool=scene.is_physics_processing();scene.set_physics_process(true)
 for x in [-2880.0,-2925.0]:
  var goal:=Vector3(x,scene.camera.global_position.y,-1136.5)
  for tick in 360:
   if scene.get_node("L9Tower").transports.size()>before:break
   var offset:Vector3=goal-scene.player.global_position;offset.y=0
   if offset.length()<3:break
   if not await look(tree,scene,goal):key(KEY_W,false);scene.set_physics_process(was_processing);return false
   key(KEY_W,true);await tree.physics_frame
   if scene.resets!=0:break
  key(KEY_W,false)
 scene.set_physics_process(was_processing)
 var crossed:bool=scene.get_node("L9Tower").transports.size()>before
 print("R126 PAIR realW crossed=",crossed," pos=",scene.player.position," resets=",scene.resets)
 return crossed and scene.resets==0
static func sitting(test:SceneTree)->bool:
 var scene:Node=test.scene
 var world:Node=scene.get_node("GenericObjects")
 for id in [102,103]:
  if not closed(scene,id):continue
  var center:Vector3=point(scene,id)
  if scene.camera.global_position.distance_to(center)>160:continue
  if not await test.look(center):return false
  var target:Dictionary=world.aimed()
  if target.get("kind")!="movable" or int(target.get("id",-1))!=id:continue
  await test.tap(KEY_E);await test.frames(4)
  if not test.require(not closed(scene,id),"Actual E opens the solid Tower door%d"%id):return false
  test.receipts.append({"event":"realE_tower_door","id":id,"health":test.hp(),"resets":scene.resets})
 return true
