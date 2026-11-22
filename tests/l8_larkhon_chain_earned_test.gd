extends "res://tests/l8_larkhon_earned_test.gd"
## Darker-start continuation. The parent still pins the qualified clubhouse snapshot.
## This walk reads the save the initiation/shaman/clubhouse chain just wrote.
func clubhouse_path() -> String:
 return "res://tmp/l8_clubhouse_earned_save.json"
func clubhouse_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS darker-start clubhouse -> physical east river Human jump -> inventory Kit recipe/activation -> original115 chest dose/sleep/reload -> native L12/1"
