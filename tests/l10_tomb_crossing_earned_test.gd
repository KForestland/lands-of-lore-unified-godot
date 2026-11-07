extends "res://tests/l10_tomb_earned_test.gd"
func combat_spark()->bool:return false
func heal_threshold()->int:return 25
func reached_waypoint(scene: Node,label: String,index: int)->void:
 if index%10==0:
  check(scene._quicksave_unrecorded("res://tmp/l10_supply_progress_earned_save.json").is_empty(),"earned supplies progress save")
  var file=FileAccess.open("res://tmp/l10_supply_progress_cursor.json",FileAccess.WRITE)
  file.store_string(JSON.stringify({"leg":label,"index":index}))
func run():
 var input:=Save.read_save("res://tmp/l10_open_tomb_supply_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned gold load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 scene.set_equipped_armor("cave:captain:Burnt_Chain")
 var tomb=scene.get_node("L10Tombs");tomb.restore()
 if not check(tomb.opened("87"),"actual earned opened tomb checkpoint"):quit(1);return
 var route: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_supply_walk.json"))
 check(tomb.bodies["87"].collision_layer==0 and tomb.bodies["91"].collision_layer!=0,"only earned door collider is open")
 if not await walk(scene,route[0].route.points.slice(0,5),"opened tomb crossing"):quit(1);return
 check(scene.player.position.x>1150,"physically crossed original door88")
 check(scene._quicksave_unrecorded("res://tmp/l10_tomb_inside_earned_save.json").is_empty(),"actual inside tomb save")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned open tomb87 -> actual door88 crossing; closed tomb91 collision remains")
 quit(0 if failures==0 else 1)
