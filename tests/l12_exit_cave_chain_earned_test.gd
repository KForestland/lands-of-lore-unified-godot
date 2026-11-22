extends "res://tests/l12_exit_cave_earned_test.gd"
## L12 return continuation. The parent still pins its qualified snapshot.
## This walk reads the L12 selector 2 save the citadel exit just wrote.
func input_path() -> String:
 return "res://tmp/l13_exit_lock_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS return chain: earned Citadel exit ->physical return ice cave/save-reload"
