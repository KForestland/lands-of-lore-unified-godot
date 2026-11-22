extends "res://tests/l12_gulch_earned_test.gd"
## Resume the earned climb immediately before the cap that Task3c fitted beneath.
## The inherited walk and anchor remain unchanged; only a real save/reload is added.
func reached_waypoint(scene:Node,label:String,index:int)->void:
 super.reached_waypoint(scene,label,index)
 if label!="gulch climb" or index!=18:return
 var position:Vector3=scene.player.position
 var path:="res://tmp/l12_gulch_before_cap_save.json"
 check(scene._quicksave_unrecorded(path).is_empty(),"save earned climb before cap")
 check(scene._quickload_unrecorded(path).is_empty(),"reload earned climb before cap")
 check(scene.player.position.distance_to(position)<0.1 and scene.resets==0,"resume same earned climb without recovery")
 print("GULCH resumed before cap at ",scene.player.position)
