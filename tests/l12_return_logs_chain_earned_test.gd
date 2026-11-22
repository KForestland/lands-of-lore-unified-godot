extends "res://tests/l12_return_logs_earned_test.gd"
## L12 return continuation. The parent still pins its qualified snapshot.
## This walk reads the log-approach save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l12_logs_approach_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS return chain: earned return ->ordinary jumps on original glacier logs ->upper floor/save-reload"
