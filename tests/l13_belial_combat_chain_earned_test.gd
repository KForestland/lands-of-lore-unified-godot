extends "res://tests/l13_belial_combat_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the arena-entry save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_belial_entry_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned movie/cure -> actual arena approach/combat -> first Belial dead/save-reload"
