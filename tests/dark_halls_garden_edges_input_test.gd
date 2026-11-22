extends "res://tests/dark_halls_garden_ground_input_test.gd"
## Same untouched owner approach. Continuous plain W/mouse only over both
## sides of the five bed regions in the owner's actual fall trace. Actors
## held as in the component parent; no supplied position or body override.
var source_faces:Dictionary={}
func walk(point:Vector3)->bool:
 await look(Vector3(point.x,scene.camera.global_position.y,point.z))
 set_key(KEY_W,true)
 for i in 600:
  if i%6==0:await look(Vector3(point.x,scene.camera.global_position.y,point.z))
  await physics_frame
  if not check(scene.resets==0 and scene.player.position.y-32>=379,"PlainW stays on original ground/bed, no recovery"):set_key(KEY_W,false);return false
  if Vector2(scene.player.position.x-point.x,scene.player.position.z-point.z).length()<8:
   set_key(KEY_W,false)
   for settle in 120:
    await physics_frame
    if not check(scene.resets==0 and scene.player.position.y-32>=379,"Step-down settles without a fall"):return false
    if scene.player.is_on_floor():return true
   return check(false,"Grounded at side/edge after ordinary step-down: "+str(scene.player.position))
 set_key(KEY_W,false);return check(false,"PlainW stalled before "+str(point)+" at "+str(scene.player.position))
func sides(face:Dictionary)->Array:
 var points:Array=face.points
 var z:=0.0
 for p in points:z+=float(p[2])/points.size()
 var xs:Array=[]
 for i in points.size():
  var a:Array=points[i];var b:Array=points[(i+1)%points.size()]
  if (float(a[2])<=z and z<float(b[2])) or (float(b[2])<=z and z<float(a[2])):xs.append(lerpf(a[0],b[0],(z-a[2])/(b[2]-a[2])))
 xs.sort();return [Vector3(xs[0]-32,0,z),Vector3(xs[0]+24,0,z),Vector3(xs[-1]-24,0,z),Vector3(xs[-1]+32,0,z)]
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered normal clock"):return
 var pin:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dark_halls_ground_inputs_manifest.json")).files[0]
 var path:String="res://"+pin.path
 if not check(FileAccess.get_sha256(path)==pin.sha256,"Original owner approach pin"):return
 scene=load("res://scenes/lol2/dark_halls.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var file:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(path));file.close();Session.for_tree(self).last_slot=10
 if not await reload():return
 var terrain:String=terrain_hash()
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
 for face in pack.faces:
  if face.kind=="floor" and int(face.get("region",-1)) in [1435,1439,1442,1445,1469]:source_faces[int(face.region)]=face
 if not check(source_faces.size()==5,"Exactly five trace regions"):return
 scene.set_physics_process(true)
 for region in [1435,1439,1442,1445,1469]:
  var route:Array=sides(source_faces[region])
  for p in [route[0],route[1],route[2],route[3],route[2]]:
   if not await walk(p):return
  print("R142_BOTH_SIDES region=",region," at=",scene.player.position," resets=",scene.resets)
 # Keep the edge fixture actual: stop 24 units inside the source boundary.
 await key(KEY_F5);await ticks(5)
 var saved:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(saved.error.is_empty(),"Actual edge F5"):return
 if not await reload():return
 scene.set_physics_process(true);await ticks(60)
 if not check(scene.player.is_on_floor() and scene.resets==0 and terrain_hash()==terrain,"Edge F9 supported and terrain unchanged"):return
 await frame("r142_both_sides_edge_reload")
 var rock:="jungle:item51:Th_Dagger"
 if not check(rock in scene.carried_collected,"Owner's carried throwing dagger, with its original pickup history"):return
 scene.hand_item=rock # Hand selection fixture; world throw remains real input.
 await look(scene.player.global_position+Vector3(-36,-22,0))
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
 await ticks(30)
 var drops:Array=scene.item_effects.thrown_items.rows().filter(func(row):return row.id==rock)
 if not check(drops.size()==1 and absf(float(drops[0].position[1])-384)<1,"Actual right drops recoverable item onto original bed height380"):return
 await key(KEY_F5);await ticks(5)
 if not await reload():return
 drops=scene.item_effects.thrown_items.rows().filter(func(row):return row.id==rock)
 if not check(drops.size()==1 and absf(float(drops[0].position[1])-384)<1,"F9 keeps item on bed"):return
 print("PASS R142 continuous owner approach, five trace bed regions from both sides with plainW/mouse; edge F5F9, real dropped carried item/F5F9, terrain unchanged; actor/route/slot holds plus hand-selection fixture disclosed, no pose edit")
 quit()
