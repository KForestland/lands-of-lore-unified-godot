extends "res://tests/l9_mirror_return_earned_test.gd"
func input_save()->String:return "res://tmp/l10_two_white_return_earned_save.json"
func combat_candidate(scene: Node,id: String)->bool:
 scene.camera.look_at(scene.act2_creatures.bodies[id].global_position+Vector3.UP*24,Vector3.UP)
 return scene.act2_creatures.aimed()==id
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual two-white return input"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_barrel_walk.json"))
 var tomb=scene.get_node("L10Tombs");var barrel=scene.get_node("L10Barrel")
 var path:=""
 if not barrel.state().switch:
  if not await walk(scene,route.white.points,"white switch tomb"):quit(1);return
  scene.camera.look_at(tomb.aims["109"],Vector3.UP)
  var before: Array=scene.carried_collected.duplicate()
  check(not tomb.offer("109","act2:L9_DR:item55").ok and before==scene.carried_collected,"wrong bracers refused without loss")
  if not check(tomb.offer("109","act2:L10_DC:item56:charged:white").ok,"Kit consumes earned white56 for source109/112"):quit(1);return
  if not await walk(scene,route.switch.points,"source switch61"):quit(1);return
  scene.camera.look_at(barrel.SWITCH,Vector3.UP)
  if not check(barrel.flip().ok,"production switch61 opens caretaker movable74"):quit(1);return
  check(not barrel.flip().ok,"switch duplicate refused")
  path="res://tmp/l10_white_switch_earned_save.json"
  check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual switch save/reload")
  barrel.restore()
 if not await walk(scene,[[-1480,-3081]],"side of original coffin237"):quit(1);return
 var extra:="act2:L10_DC:item45"
 scene.camera.look_at(scene.act2_items.aim_point(extra),Vector3.UP)
 if not check(extra in scene.carried_collected or scene.act2_items.take(extra),"original empty45 beside white tomb coffin"):quit(1);return
 if not await walk(scene,[[-1458,-3005]],"leave white tomb coffin"):quit(1);return
 if not await walk(scene,route.caretaker.points,"caretaker door"):quit(1);return
 if not await walk(scene,route.inside.points,"sidle past upright barrel"):quit(1);return
 if not await walk(scene,route.globe9.points,"replacement globe9"):quit(1);return
 var id:="act2:L10_DC:item9"
 scene.camera.look_at(scene.act2_items.aim_point(id),Vector3.UP)
 if not check(scene.act2_items.take(id),"original caretaker replacement empty9"):quit(1);return
 if not await walk(scene,route.behind.points,"behind barrel"):quit(1);return
 scene.camera.look_at(barrel.TOP,Vector3.UP)
 if not check(barrel.tip().ok,"Human tips barrel from inside room"):quit(1);return
 check(not barrel.tip().ok,"duplicate tip refused")
 path="res://tmp/l10_rolling_barrel_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual rolling save/reload")
 if not await walk(scene,route.oil.points,"follow barrel north"):quit(1);return
 for i in 3000:
  await physics_frame
  if not await fight_nearby(scene):quit(1);return
  if barrel.state().phase==2:break
 if not check(barrel.state().phase==2,"barrel reaches source endpoint and spills oil"):quit(1);return
 path="res://tmp/l10_oil_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual oil save/reload")
 check(id in scene.carried_collected and "act2:L10_DC:item8:charged:white" in scene.carried_collected,"replacement empty and second white retained")
 check(scene.progression.seeds_applied.is_empty(),"no arrival seed")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual two-white return -> Kit white109 -> switch61/movable74 -> Human inside barrel477 -> original empty9 -> rolling176 -> oil at source endpoint -> real save/reload")
 quit(0 if failures==0 else 1)
