extends "res://tests/l13_altar_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the Belial-combat save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_belial_combat_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: actual boss-death route -> premature stone refusal -> equipped sword Kit conversion -> Dreamstone -> equipped save/reload"
