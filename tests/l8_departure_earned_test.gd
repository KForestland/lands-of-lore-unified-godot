extends "res://tests/l8_temple_earned_test.gd"
func continue_village(scene: Node) -> void:
 var journey = scene.get_node("L8Journey")
 var original: Array = scene.carried_collected.duplicate()
 check(not journey.interact("show_guard","wrong").ok and scene.carried_collected==original,"wrong guard offer preserves inventory")
 var path := "res://tmp/l8_departure_earned_save.json"
 for action in ["show_guard","offer_daniel","visit_shaman"]:
  if not check(journey.interact(action,State.BLADE).ok,"village action " + action): return
  if not check(scene._quicksave_unrecorded(path).is_empty(),"village save " + action): return
  if not check(scene._quickload_unrecorded(path).is_empty(),"village reload " + action): return
  if action=="show_guard": check(State.BLADE in scene.carried_collected,"guard shows blade without consuming it")
 check(State.BLADE not in scene.carried_collected,"final Daniel delivery consumes blade")
 check(scene.carried_collected.count(State.KEY)==1,"shaman key earned once")
 check(not journey.interact("visit_shaman").ok,"duplicate key refused")
 var route = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_first_departure_walk.json"))
 scene.progression.change_scene_enabled = false
 if not await walk(scene,route.departure,"departure"): return
 check(not scene.progression.level_changes.is_empty(),"walking crosses native departure trigger")
 if not scene.progression.level_changes.is_empty():
  var change: Dictionary = scene.progression.level_changes.back()
  check(change.level==10 and change.selector==1,"native exit requests L10 selector1")
 if failures==0: print("PASS earned L8 guard/Daniel/shaman saves and physical native L10 exit; special-scene optional pickups and rendered presentation pending")
