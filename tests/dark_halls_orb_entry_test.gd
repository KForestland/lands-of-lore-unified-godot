extends "res://tests/dark_halls_puzzles_entry_test.gd"
func run() -> void:
	OS.set_environment("LOL2_DH_PUZZLE", "orb")
	await super.run()
