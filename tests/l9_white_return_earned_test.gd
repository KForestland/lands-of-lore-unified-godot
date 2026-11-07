extends "res://tests/l9_mirror_return_earned_test.gd"
func input_save()->String:return "res://tmp/l9_two_white_earned_save.json"
func output_save()->String:return "res://tmp/l10_two_white_return_earned_save.json"
func verify_return(scene: Node):
 for id in ["act2:L10_DC:item56:charged:white","act2:L10_DC:item8:charged:white","act2:L9_DR:item55"]:
  check(id in scene.carried_collected,"two-white return retains "+id)
 print("Earned two-white and bracers branch returned to Cemetery for STORY-015")
func tower_exit_points(route: Dictionary)->Array:
 var tower: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_tower_walk.json"))
 var points: Array=tower.white.points.duplicate();points.reverse()
 var ground: Array=tower.ground.points.duplicate();ground.reverse()
 points.append_array(ground)
 points.append_array(route.tower_exit.points.slice(-3))
 return points
