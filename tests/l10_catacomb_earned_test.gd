extends "res://tests/l10_tomb_earned_test.gd"
func pickup_route(route: Dictionary)->Array:
 var points: Array=route.pickup.duplicate(true)
 # Small walking detour off the source portal centre to face Bone Brazier235.
 points.insert(47,[1768,-2992])
 return points
func reached_waypoint(scene: Node,label: String,_index: int)->void:
 if label!="pickup":return
 var braziers=scene.get_node("L10Braziers")
 for id in ["235","234"]:
  if braziers.lit(id):continue
  scene.camera.look_at(braziers.aims[id],Vector3.UP)
  if not braziers.reachable(id):continue
  var before: Array=scene.carried_collected.duplicate()
  check(braziers.ignite(id).ok,"source Bone Brazier ignition "+id)
  check(not braziers.ignite(id).ok and before==scene.carried_collected,"repeat light refused without inventory effect")
func after_pickup(scene: Node)->bool:
 var braziers=scene.get_node("L10Braziers")
 check(braziers.lit("235") and braziers.lit("234"),"both lower-floor braziers reached on foot and lit")
 check("act2:L10_DC:item44" in scene.carried_collected,"loose source globe collected")
 var path:="res://tmp/l10_catacomb_earned_save.json"
 var error: String=scene._quicksave_unrecorded(path)
 check(error.is_empty(),"catacomb checkpoint: "+error)
 error=scene._quickload_unrecorded(path)
 check(error.is_empty(),"catacomb reload: "+error)
 braziers.restore()
 check(braziers.flames["235"].visible and braziers.flames["234"].visible,"lit original art restored")
 check("act2:L10_DC:item44" in scene.carried_collected and not scene.act2_items.take("act2:L10_DC:item44"),"earned globe persists without duplicate pickup")
 if failures==0:print("PASS STORY-008: earned gate -> physical catacomb stairs -> two source Bone Braziers -> loose globe -> actual save/reload; no seeding")
 return false
