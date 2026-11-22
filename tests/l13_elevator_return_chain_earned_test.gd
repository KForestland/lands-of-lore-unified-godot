extends "res://tests/l13_elevator_return_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the prison-refusal save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_prison_refusal_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned prison refusal -> physical return walk -> actual Spark elevator rise -> mid-motion reload -> original upper landing"
