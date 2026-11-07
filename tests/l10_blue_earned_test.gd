extends "res://tests/l10_barrel_earned_test.gd"
func jump_fence(scene: Node,id: int)->bool:
 var fences=scene.get_node("L10Fences");var row: Dictionary=fences.rows[id]
 var before: int=fences.passes
 if not check((scene.player.position-row.center).dot(row.normal)>25,"earned high-side approach "+str(id)):return false
 if not check(scene.request_jump(),"real jump request "+str(id)):return false
 await physics_frame
 scene.move_grounded(-row.normal,scene.player.get_physics_process_delta_time(),true)
 if not check(not scene.player.is_on_floor(),"actual airborne before crouch "+str(id)):return false
 var key:=InputEventKey.new();key.keycode=KEY_CTRL;key.physical_keycode=KEY_CTRL;key.ctrl_pressed=true;key.pressed=true
 Input.parse_input_event(key);Input.flush_buffered_events()
 var crossed:=false
 for tick in 240:
  await physics_frame
  scene.move_grounded(-row.normal,scene.player.get_physics_process_delta_time(),true)
  if (scene.player.position-row.center).dot(row.normal)<-80 and scene.player.is_on_floor():crossed=true;break
 key.pressed=false;key.ctrl_pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
 print("FENCE ",id," landed ",scene.player.position," passes ",fences.passes)
 return check(crossed and fences.passes>before,"physical high-to-low running jump with midair Ctrl "+str(id))
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l10_north_catacomb_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual collapsed tomb landing input"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_blue_walk.json"))
 if not await walk(scene,route.blue.points,"northern blue charger"):quit(1);return
 var charger=scene.get_node("Act2Chargers")
 scene.camera.look_at(charger.globes["L10:blue"].global_position,Vector3.UP)
 var before: Array=scene.carried_collected.duplicate()
 check(not charger.interact("L10:blue","insert","act2:L10_DC:item8:charged:white").ok and before==scene.carried_collected,"already white globe refused without loss")
 for id in ["act2:L10_DC:item45","act2:L10_DC:item9"]:
  scene.camera.look_at(charger.globes["L10:blue"].global_position,Vector3.UP)
  if not check(charger.interact("L10:blue","insert",id).ok,"Kit inserts original empty "+id):quit(1);return
  var occupied: String="res://tmp/l10_blue_"+id.get_slice(":",2)+"_occupied_earned_save.json"
  check(scene._quicksave_unrecorded(occupied).is_empty() and scene._quickload_unrecorded(occupied).is_empty(),"occupied blue charger actual save/reload")
  charger.restore();scene.camera.look_at(charger.globes["L10:blue"].global_position,Vector3.UP)
  if not check(charger.interact("L10:blue","retrieve").ok,"Kit retrieves original blue "+id):quit(1);return
  check(not charger.interact("L10:blue","retrieve").ok,"duplicate blue retrieval refused")
 var path:="res://tmp/l10_two_blue_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual two-blue checkpoint")
 if not await walk(scene,route.stairs.points,"return northern charger stairs"):quit(1);return
 if not await walk(scene,route.fence74.points,"fence74 high side"):quit(1);return
 if not await jump_fence(scene,74):quit(1);return
 if not await walk(scene,route.fence174.points,"fence174 high side"):quit(1);return
 if not await jump_fence(scene,174):quit(1);return
 if not await walk(scene,route.exit_stairs.points,"original catacomb entrance stairs"):quit(1);return
 check(scene.player.position.y>25,"physically returned above ground")
 path="res://tmp/l10_blue_return_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual above-ground blue return save/reload")
 for id in ["act2:L10_DC:item45:charged:blue","act2:L10_DC:item9:charged:blue","act2:L10_DC:item8:charged:white","act2:L9_DR:item55"]:check(id in scene.carried_collected,"earned return retains "+id)
 for row in scene.get_node("L10Fences").rows.values():check(not row.passing,"transient fence passage cleared by reload")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual collapsed-tomb landing -> north charger Kit two blues -> same stairs -> two high-side running jumps/midairCtrl -> original entry-stair ascent -> real save/reload")
 quit(0 if failures==0 else 1)
