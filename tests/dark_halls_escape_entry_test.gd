extends "res://tests/dark_halls_puzzles_entry_test.gd"
func run() -> void:
	OS.set_environment("LOL2_DH_PUZZLE", "escape")
	escape_driver = preload("res://tests/dark_halls_escape_input.gd").new()
	await super.run()
