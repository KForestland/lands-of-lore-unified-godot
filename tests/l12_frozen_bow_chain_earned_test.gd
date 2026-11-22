extends "res://tests/l12_frozen_bow_earned_test.gd"
## L12 return continuation. The parent still pins its qualified snapshot.
## This walk reads the crevasse save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l12_crevasse_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS return chain: earned Lizard grotto ->actual ice Spark ->missed window/retry ->timed bow catch/save-reload"
