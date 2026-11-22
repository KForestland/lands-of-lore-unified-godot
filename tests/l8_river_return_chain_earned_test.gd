extends "res://tests/l8_river_return_earned_test.gd"
## L12 return continuation. The parent still pins its qualified snapshot.
## This walk reads the L8 gulch-return save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l12_gulch_return_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS return chain: earned gulch return -> reverse rise -> physical uphill river jump -> original corridor/save-reload"
