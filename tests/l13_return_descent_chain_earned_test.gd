extends "res://tests/l13_return_descent_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the return-pad save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_return_pad_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned altar return ->physical upper call ->real elevator rise/descent ->lower exit/save-reload"
