extends "res://tests/generic_l10_persistence_test.gd"
var hold_new:=false
func hold(node:Node):node.set_physics_process(false)
func arrived(node:Node):
 if hold_new and node.get_script()!=null and node.get_script().resource_path=="res://scripts/lol2/act2_progression.gd":node.ready.connect(hold.bind(node),CONNECT_ONE_SHOT)
func run():
 node_added.connect(arrived)
 scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();root.add_child(scene);current_scene=scene
 for tick in 1800:
  await process_frame
  if scene.ready_for_review:break
 var incoming:=AreaSave.read_save("res://assets/lol2/generated/playtest_starts/c15_l10_dc.json","lol2-restoration-map-L10_DC")
 if not check(incoming.error.is_empty() and scene.apply_save(incoming.state).is_empty(),"Genuine starting packet applies"):return
 scene.set_physics_process(false);scene.act2_creatures.set_physics_process(false)
 if not await pose(Vector3(1120,32.05,-1296),Vector3(1029,40,-1296)):return
 var doc:=Slots.make_document(scene,1)
 print("ADMISSION can=",scene.can_save()," doc=",Slots.validate(doc)," world=",preload("res://scripts/lol2/act2_world_checkpoint.gd").error(doc.native_bank.L10_DC.world,"L10_DC"))
 var world:Dictionary=doc.native_bank.L10_DC.world
 var limits:Dictionary=preload("res://scripts/lol2/act2_world_checkpoint.gd").mover_limits("L10_DC")
 for k in world.movers:
  var reason:String=preload("res://scripts/lol2/act2_world_checkpoint.gd").mover_error(world.movers[k],limits[k])
  if not reason.is_empty():print("BAD MOVER ",k," ",reason," pose=",world.movers[k]," limit=",limits[k])
 print("FLOORS ",world.floors)
 if not check(Slots.validate(doc).is_empty(),"Every real L10 starting-packet pose admits save"):return
 await key(KEY_F5)
 var saved:=slot_packet()
 if not check(saved.quests.has("generic_objects"),"ActualF5 replaced slot with current GenericObjects"):return
 hold_new=true
 if not await load_slot():return
 for id in [70,71,72,73]:
  var expected:Transform3D=preload("res://scripts/lol2/act2_world_checkpoint.gd").decode(doc.native_bank.L10_DC.world.movers[str(id)])
  if not check(scene.progression.hinges[id].transform.is_equal_approx(expected),"ActualF9 keeps exact sigil-gate moving half "+str(id)):return
 print("PASS genuine L10 starting-packet save admission and realF5 current object packet")
 quit()
