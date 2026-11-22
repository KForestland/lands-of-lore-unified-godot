extends "res://tests/helpers/owner_gaps_input.gd"
## Unedited owner14-29-09 first pose of the14-30-50 recorded dirt fall.
## ActualF9/W/F5/F9, no pose/HP/pack edits; enemy/route holds and slot10.
func settled():
 for i in 1800:
  await process_frame
  if scene.get("ready_for_review")==true and is_instance_valid(scene.get("starting_magic")):break
 scene.set_physics_process(false)
 for name in ["DarkHallsCreatures","DarkHallsRix","DarkHallsRoute"]:
  var node:=scene.get_node_or_null(name)
  if is_instance_valid(node):node.set_physics_process(false);node.set_process(false)
 scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;await ticks(3)
var bed_polygons:Array=[]
var bed_triangles:=PackedVector3Array()
func terrain_hash()->String:
 var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
 for body in scene.get_children():
  if not body is StaticBody3D or body.name=="RegionBlockers":continue
  for collision in body.get_children():
   if collision is CollisionShape3D and collision.shape is ConcavePolygonShape3D:digest.update(collision.shape.get_faces().to_byte_array())
 return digest.finish().hex_encode()
func cache_bed():
 bed_polygons.clear();bed_triangles.clear()
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
 for face:Dictionary in pack.faces:
  if face.kind!="floor" or int(face.get("region",-1)) not in scene.GARDEN_BED_REGIONS:continue
  var polygon:=PackedVector2Array()
  for v:Array in face.points:polygon.append(Vector2(v[0],v[2]))
  bed_polygons.append(polygon)
  for index in [0,1,2,0,2,3]:
   var v:Array=face.points[index];bed_triangles.append(Vector3(v[0],v[1],v[2]))
func bed_under()->bool:
 var p:=Vector2(scene.player.position.x,scene.player.position.z)
 return bed_polygons.any(func(polygon):return Geometry2D.is_point_in_polygon(p,polygon))
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock"):return
 var pins:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dark_halls_ground_inputs_manifest.json"))
 var row:Dictionary=pins.files[0];var path:String="res://"+row.path
 if not check(FileAccess.get_sha256(path)==row.sha256,"Unedited owner pre-fall save pin"):return
 scene=load("res://scenes/lol2/dark_halls.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var file:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(path));file.close();Session.for_tree(self).last_slot=10
 if not await reload():return
 cache_bed()
 var terrain:String=terrain_hash();print("DH_GARDEN_MAIN_TERRAIN ",terrain)
 var original:Vector3=scene.player.position
 if not check(original.distance_to(Vector3(1861.85,432.04,-3367.88))<1.0,"Owner's real grounded approach, not a supplied soil stand"):return
 scene.set_physics_process(true)
 set_key(KEY_W,true)
 var crossed:=false
 for i in 90:
  await physics_frame
  crossed=crossed or bed_under()
  if not check(scene.player.position.y-32>=379.0 and scene.resets==0,"RealW across the native brown bed never falls through its source floor"):return
 set_key(KEY_W,false);await ticks(20)
 if not check(crossed and bed_under() and scene.player.is_on_floor() and absf(scene.player.position.y-32-380)<1,"PlainW reaches and stands on the source soil at380"):return
 await frame("dh_garden_walk_on_soil")
 var body:=scene.get_node_or_null("DarkHallsAtrium/GardenBedFloorCollision")
 if not check(body is StaticBody3D and body.get_child(0).shape.get_faces().size()==24*6,"Exactly24 source floor quads on a separate collision body"):return
 if not check(body.get_child(0).shape.get_faces().to_byte_array()==bed_triangles.to_byte_array(),"Separate collider uses the exact native source quad vertices"):return
 await key(KEY_F5);await ticks(3)
 var saved:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(saved.error.is_empty(),"ActualF5 writes the live soil stand"):return
 if not await reload():return
 scene.set_physics_process(true);await ticks(60)
 if not check(scene.player.is_on_floor() and scene.resets==0 and absf(scene.player.position.y-32-380)<1,"ActualF9 keeps supported contact on the garden floor"):return
 if not check(terrain_hash()==terrain,"F5F9 keeps the main terrain trimesh byte-identical"):return
 print("PASS unedited owner pre-fall approach viaF9, plainW onto24native soil quads, separate collider and F5F9 contact; held actors/route/slot, no pose/HP/pack edit")
 quit()
