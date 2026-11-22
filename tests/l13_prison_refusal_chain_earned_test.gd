extends "res://tests/l13_prison_refusal_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the elevator save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_elevator_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned lower route/combat -> Human jump into original plate52 -> original maiden refusal while Ruloi live -> actual visit save/reload"
