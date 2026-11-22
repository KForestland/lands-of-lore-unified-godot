extends "res://tests/l9_flood_escape_earned_test.gd"
## Darker-start continuation. The parent still reads the qualified statue-fight snapshot.
## This walk reads the fight save the bowl/follow chain just wrote. Dampen is not in that save.
func input_save()->String:return "res://tmp/l9_statue_fight_earned_save.json"
func pass_line()->String:return "PASS darker-start statue fight -> rising water -> low roof -> ordinary table jump -> saved lift ride -> ordinary tunnel jump -> physical raft -> native L8/5 exit; inventory unchanged"
